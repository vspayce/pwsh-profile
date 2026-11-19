# local.ps1 - settings for THIS machine only. It is gitignored, so nothing here
# is ever pushed to GitHub. Open it any time with:  ep -Local
# It runs last, after everything else in the profile has loaded.

# --- Profile settings -------------------------------------------------------
# $PwshProfileConfig.ShowGitBranch       = $false
# $PwshProfileConfig.DurationThresholdMs = 5000
# $PwshProfileConfig.PromptChar          = '$'
# $PwshProfileConfig.WeatherLocation     = 'Seattle'
# $PwshProfileConfig.CopilotTenantId     = 'contoso.onmicrosoft.com'   # for 'ask'

# --- Work defaults -------------------------------------------------------------
# Point every AD cmdlet at one domain controller:
# $PSDefaultParameterValues['*-AD*:Server'] = 'dc01.contoso.local'

# --- Start somewhere useful --------------------------------------------------
# Set-Location C:\Scripts

# --- Extras ---------------------------------------------------------------------
# joke                                                # a dad joke on every new shell
# oh-my-posh init pwsh | Invoke-Expression            # replace the built-in prompt
# Import-Module Terminal-Icons -ErrorAction SilentlyContinue

# Functions only for this machine go in Functions\Local\  (also gitignored).
# Create one with:  newfn Connect-MyLab -Local
