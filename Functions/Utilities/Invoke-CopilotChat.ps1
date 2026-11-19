# Alias: ask
function Invoke-CopilotChat {
    <#
    .SYNOPSIS
        Ask Microsoft 365 Copilot a question from the terminal, grounded in your mail, Teams, files and the web.
    .DESCRIPTION
        Uses the Microsoft 365 Copilot Chat API (Microsoft Graph, beta) through the
        Microsoft Graph PowerShell sign-in, so you do not need your own app registration.

        Requirements:
          * A work/school account with a Microsoft 365 Copilot license
          * Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
          * Consent for the delegated permissions below. If your tenant has not approved
            them for "Microsoft Graph Command Line Tools", the first sign-in shows a
            "needs admin approval" screen - send that to your Entra admin.
              Sites.Read.All, Mail.Read, People.Read.All, OnlineMeetingTranscript.Read.All,
              Chat.Read, ChannelMessage.Read.All, ExternalItem.Read.All

        Follow-up questions continue the same conversation until you use -New.
        Pipe text in to give Copilot extra context (logs, error messages, a script).
    .EXAMPLE
        ask what meetings do I have tomorrow
    .EXAMPLE
        ask -New summarize unread email from my manager this week
    .EXAMPLE
        Get-Content .\error.log -Tail 50 | ask what is causing these errors
    .EXAMPLE
        ask -File 'https://contoso.sharepoint.com/sites/IT/Shared Documents/Runbook.docx' what are the failover steps
    .EXAMPLE
        ask -NoWeb what did we decide about the VPN migration    # company data only
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, ValueFromRemainingArguments)]
        [string[]]$Prompt,

        # Text piped in is sent as extra context
        [Parameter(ValueFromPipeline)]
        [string]$InputObject,

        # Start a new conversation instead of continuing the last one
        [switch]$New,

        # Ground only in Microsoft 365 data for this message (no web search)
        [switch]$NoWeb,

        # OneDrive / SharePoint file URLs to use as context
        [string[]]$File,

        # Return the raw API response instead of printing the answer
        [switch]$Raw,

        # Sign in to a specific tenant (or set $PwshProfileConfig.CopilotTenantId in local.ps1)
        [string]$TenantId = $global:PwshProfileConfig.CopilotTenantId,

        # Sign out of the Graph session used by this command
        [switch]$SignOut
    )
    begin {
        $piped = [System.Collections.Generic.List[string]]::new()
    }
    process {
        if ($PSCmdlet.MyInvocation.ExpectingInput -and $null -ne $InputObject) { $piped.Add($InputObject) }
    }
    end {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            throw "Needs the Microsoft Graph sign-in module. Install it once with:`n  Install-Module Microsoft.Graph.Authentication -Scope CurrentUser"
        }
        if ($SignOut) {
            $null = Disconnect-MgGraph -ErrorAction SilentlyContinue
            $global:PwshCopilotConversationId = $null
            Write-Host 'Signed out of Microsoft Graph.' -ForegroundColor Green
            return
        }

        $text = ($Prompt -join ' ').Trim()
        if (-not $text) { throw 'Ask a question, e.g.  ask what is on my calendar today' }

        # --- sign in (once per session) -------------------------------------------
        $scopes = 'Sites.Read.All', 'Mail.Read', 'People.Read.All', 'OnlineMeetingTranscript.Read.All',
                  'Chat.Read', 'ChannelMessage.Read.All', 'ExternalItem.Read.All'
        $ctx = Get-MgContext
        $missing = if ($ctx) { $scopes | Where-Object { $ctx.Scopes -notcontains $_ } } else { $scopes }
        if ($missing) {
            $connect = @{ Scopes = $scopes; NoWelcome = $true; ErrorAction = 'Stop' }
            if ($TenantId) { $connect.TenantId = $TenantId }
            try { Connect-MgGraph @connect }
            catch { throw "Sign-in failed: $($_.Exception.Message)`nIf you saw 'Need admin approval', your Entra admin must consent to the permissions listed in: Get-Help Invoke-CopilotChat" }
        }

        $base = 'https://graph.microsoft.com/beta/copilot/conversations'

        # --- conversation ---------------------------------------------------------------
        if ($New -or -not $global:PwshCopilotConversationId) {
            $conv = Invoke-MgGraphRequest -Method POST -Uri $base -Body '{}' -ContentType 'application/json' -ErrorAction Stop
            $global:PwshCopilotConversationId = $conv.id
        }

        # Copilot wants an IANA time zone (America/Los_Angeles); Windows reports "Pacific Standard Time"
        $tz = [TimeZoneInfo]::Local.Id
        $ianaId = $null
        if ($tz -notmatch '/' -and [TimeZoneInfo].GetMethod('TryConvertWindowsIdToIanaId', [type[]]@([string], [string].MakeByRefType()))) {
            if ([TimeZoneInfo]::TryConvertWindowsIdToIanaId($tz, [ref]$ianaId)) { $tz = $ianaId }
        }

        $body = @{
            message      = @{ text = $text }
            locationHint = @{ timeZone = $tz }
        }
        if ($piped.Count -and ($piped -join '').Trim()) {
            $ctxText = ($piped -join "`n")
            if ($ctxText.Length -gt 30000) { $ctxText = $ctxText.Substring($ctxText.Length - 30000); Write-Warning 'Piped text was long; sent only the last 30,000 characters.' }
            $body.additionalContext = @(@{ text = $ctxText })
        }
        $resources = @{}
        if ($File)  { $resources.files = @($File | ForEach-Object { @{ uri = $_ } }) }
        if ($NoWeb) { $resources.webContext = @{ isWebEnabled = $false } }
        if ($resources.Count) { $body.contextualResources = $resources }

        $json = $body | ConvertTo-Json -Depth 6
        try {
            $resp = Invoke-MgGraphRequest -Method POST -Uri "$base/$($global:PwshCopilotConversationId)/chat" `
                -Body $json -ContentType 'application/json' -ErrorAction Stop
        } catch {
            $msg = $_.Exception.Message
            if ($msg -match '403|Forbidden') { throw "Copilot refused the request (403). Check you have a Microsoft 365 Copilot license and the permissions were consented.`n$msg" }
            if ($msg -match '404') { $global:PwshCopilotConversationId = $null; throw "Conversation expired - run the question again (or use -New).`n$msg" }
            if ($msg -match '504|timeout') { throw "Copilot timed out (long questions sometimes do). Try a narrower question.`n$msg" }
            throw
        }
        if ($Raw) { return $resp }

        # --- show the answer ---------------------------------------------------------
        $answer = @($resp.messages)[-1]
        $out = [string]$answer.text
        $out = $out -replace '</?(Event|Person|File|Email|Meeting|Chat)>', '**'   # entity tags -> bold
        $out = $out -replace '\[\^(\d+)\^\]', '[$1]'                             # [^1^] -> [1]

        if ((Get-Command Show-Markdown -ErrorAction SilentlyContinue) -and -not [Console]::IsOutputRedirected) {
            $out | Show-Markdown
        } else {
            $out
        }

        $cites = @($answer.attributions | Where-Object { $_.attributionType -eq 'citation' -and $_.seeMoreWebUrl })
        if ($cites.Count) {
            Write-Host 'Sources:' -ForegroundColor DarkGray
            $i = 0
            foreach ($c in $cites) {
                $i++
                $name = if ($c.providerDisplayName) { $c.providerDisplayName } else { 'link' }
                Write-Host ("  [{0}] {1}  {2}" -f $i, $name, $c.seeMoreWebUrl) -ForegroundColor DarkGray
            }
        }
    }
}
