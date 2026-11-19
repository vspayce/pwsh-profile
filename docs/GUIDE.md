# The pwsh-profile guide

Everything you need to install, use, customize and maintain this profile. For the list of every function, see **[FUNCTIONS.md](FUNCTIONS.md)**.

**Contents**

1. [What this is](#1-what-this-is)
2. [Install](#2-install)
3. [Your first five minutes](#3-your-first-five-minutes)
4. [The prompt](#4-the-prompt)
5. [Keyboard shortcuts](#5-keyboard-shortcuts)
6. [Directory history: `dh` and `j`](#6-directory-history-dh-and-j)
7. [Finding things: `pf`, `which`, `Get-Help`](#7-finding-things)
8. [Cookbook: everyday sysadmin tasks](#8-cookbook-everyday-sysadmin-tasks)
9. [Customizing for one machine: `local.ps1`](#9-customizing-for-one-machine-localps1)
10. [Adding your own functions](#10-adding-your-own-functions)
11. [Functions from jonlabelle/pwsh-profile](#11-functions-from-jonlabellepwsh-profile)
12. [Keeping machines in sync](#12-keeping-machines-in-sync)
13. [Using functions on remote servers](#13-using-functions-on-remote-servers)
14. [How the lazy loading works](#14-how-the-lazy-loading-works)
15. [Performance](#15-performance)
16. [Troubleshooting](#16-troubleshooting)
17. [Repo layout, tests and CI](#17-repo-layout-tests-and-ci)
18. [Uninstall](#18-uninstall)

---

## 1. What this is

A PowerShell profile is a script that runs every time you open a shell. This one gives you:

- **~100 ready-made functions**, including `ask` for Microsoft 365 Copilot for networking, DNS, certificates, Active Directory, system health, files and more
- **a better prompt** (admin badge, git branch, command timing, red `>` on failure)
- **better history and tab completion** (type a few letters and press Up; Tab shows a menu)
- **session directory history** (`dh` lists where you've been, `j` jumps back)
- **one install on every machine** (Windows, macOS, Linux; PowerShell 7 and Windows PowerShell 5.1), updated with one command

Every function is its own file, and none of them load until you use them. Opening a shell stays fast even with a hundred functions.

---

## 2. Install

### Windows, macOS or Linux (PowerShell 7)

```powershell
irm https://raw.githubusercontent.com/vspayce/pwsh-profile/main/install.ps1 | iex
```

### Windows PowerShell 5.1 (the blue built-in one)

Older Windows builds may need TLS 1.2 switched on first:

```powershell
[Net.ServicePointManager]::SecurityProtocol = 'Tls12'
irm https://raw.githubusercontent.com/vspayce/pwsh-profile/main/install.ps1 | iex
```

On Windows, one install covers **both** PowerShell 7 and 5.1. You don't need to run it twice.

### What the installer does

1. Clones the repo to `~/.pwsh-profile`. If git isn't installed, it downloads a zip instead.
2. Adds this block to your profile file (backing the file up first if it exists):
   ```powershell
   # >>> pwsh-profile >>>
   if (Test-Path 'C:\Users\you\.pwsh-profile\profile.ps1') { . 'C:\Users\you\.pwsh-profile\profile.ps1' }
   # <<< pwsh-profile <<<
   ```
   | Platform | Profile file(s) |
   |---|---|
   | Windows | `Documents\PowerShell\profile.ps1` and `Documents\WindowsPowerShell\profile.ps1` (OneDrive-redirected Documents works) |
   | macOS / Linux | `~/.config/powershell/profile.ps1` |
3. On Windows, if the execution policy would block the profile, sets it to `RemoteSigned` for your user only.
4. Creates your `local.ps1` from the template.

Anything already in your profile stays where it is. The installer only adds or updates its own marked block, so it's safe to run again.

### Prefer to look before you run?

```powershell
irm https://raw.githubusercontent.com/vspayce/pwsh-profile/main/install.ps1 -OutFile install.ps1
notepad install.ps1          # read it
./install.ps1                # options: -InstallPath, -Branch, -Uninstall
```

### Recommended extras (optional)

- **A Nerd Font** if you add oh-my-posh later. The built-in prompt doesn't need one.
- **PSReadLine 2.2+** in Windows PowerShell 5.1, for history predictions: `Install-Module PSReadLine -Scope CurrentUser -Force`
- **RSAT Active Directory tools** for the AD functions: `Get-WindowsCapability -Online -Name Rsat.ActiveDirectory* | Add-WindowsCapability -Online`

---

## 3. Your first five minutes

Open a new terminal, then try these:

```powershell
pf                         # every function, alias and one-line description
pf dns                     # search that list
tp google.com 80,443       # Test-Port: is it open?
myip                       # local + public IP
uptime                     # last boot (Windows; on Mac/Linux use Show-Uptime)
netdiag google.com         # full network diagnostic with latency graph
certexp github.com         # when does the certificate expire?
genpass -Copy              # strong password, copied to clipboard
dh                         # folders you've visited this session
ep -Local                  # edit settings for this machine only
```

Every function has full help with examples: `Get-Help Test-Port -Examples`.

---

## 4. The prompt

```
 ADMIN  ~/src/pwsh-profile (main) 3.4s
>
```

| Part | Meaning |
|---|---|
| red ` ADMIN ` | the shell is elevated (Administrator, or root) |
| `user@host` | shown only over SSH or a PowerShell remote session |
| `~/src/...` | current folder, with your home folder shortened to `~` |
| `(main)` | git branch, read directly from `.git/HEAD`, so it adds no delay |
| `3.4s` | how long the last command took (only shown if over 2 s) |
| `>` | green normally, **red if the last command failed**; `>>` in nested prompts |

It also:

- sets the window/tab title to the current folder (`[Admin] folder` when elevated)
- tells **Windows Terminal** your current folder, so *Duplicate Tab* and *Split Pane* open in the same place
- records your location for `dh` / `j`

Change it in `local.ps1`:

```powershell
$PwshProfileConfig.ShowGitBranch       = $false
$PwshProfileConfig.ShowDuration        = $false
$PwshProfileConfig.DurationThresholdMs = 5000
$PwshProfileConfig.PromptChar          = '$'
```

Prefer oh-my-posh or Starship? Add their init line to `local.ps1`; it runs last and replaces this prompt. (You'll lose automatic `dh` recording unless you call `prompt` logic yourself, so the built-in prompt is recommended.)

---

## 5. Keyboard shortcuts

Set up by `Core/10-PSReadLine.ps1`:

| Key | What it does |
|---|---|
| **Up / Down** | Search history for commands that start with what you've typed. Type `Get-AD` then press Up. |
| **Tab** | Show a menu of every completion; arrow through it |
| **F1** | Same menu (handy for parameters: type `-` then F1) |
| **F2** | Toggle predictions between inline and a list (PSReadLine 2.2+) |
| **Right arrow / End** | Accept the whole grey suggestion |
| **Ctrl+F** | Accept just the next word of the suggestion |
| **Ctrl+D** | Exit the shell (when the line is empty) |
| **Ctrl+R** | Reverse search through history (built in) |

**Privacy:** lines containing `password`, `passwd`, `secret`, `token`, `apikey`, `-AsPlainText` or `ConvertTo-SecureString` are never written to your history file.

Tab completion is also set up for `winget` and `dotnet`. If `gh` (GitHub CLI) and `zoxide` are installed, they're set up right after the first prompt appears, so they don't slow down startup.

---

## 6. Directory history: `dh` and `j`

Every folder you visit is remembered for the session, whether you got there with `cd`, `pushd`, `cd -`, `j`, or a script.

```powershell
dh                 # numbered list, most recent first
[ 0] C:\Users\jason\src\pwsh-profile
[ 1] C:\Windows\System32\drivers\etc
[ 2] \\fileserver\it\scripts
[ 3] C:\temp

j                  # back to the previous folder ([1])
j 3                # jump to [3]
j scripts          # most recent folder whose name contains "scripts"
dh etc             # filter the list
```

Also: `..`, `...` and `....` go up one, two or three levels, and `mkcd C:\temp\new\folder` creates a folder and moves into it.

The list keeps the last 50 folders (`$PwshProfileConfig.DirHistoryMax`). It's per session and isn't saved to disk.

---

## 7. Finding things

| Command | Use it to |
|---|---|
| `pf` | list every profile function with alias and description |
| `pf cert` | search names, aliases and descriptions |
| `pf -Category Network` | list one category |
| `Get-Help Test-Port -Examples` | see examples (works before the function is loaded) |
| `which tp` | where a command comes from: exe path, alias target or profile file (`Get-CommandPath` on macOS/Linux) |
| `ep Test-Port` / `ep tp` | open that function's file in your editor |
| [FUNCTIONS.md](FUNCTIONS.md) | the full reference on GitHub |

---

## 8. Cookbook: everyday sysadmin tasks

### "The app can't reach the server"

```powershell
tp app01 443, 1433, 5985            # which ports answer?
Test-DnsNameResolution app01        # does the name resolve?
Get-DnsRecord app01.contoso.com -Type A
Get-ReverseDns 10.20.30.40          # what name does that IP have?
Invoke-Ping app01 -Count 10         # latency and loss
Trace-Route app01                   # where does it stop?
netdiag app01                       # all of the above, with a latency graph
Test-HttpResponse https://app01/health
flushdns                            # after you fix DNS
```

Checking a list someone pasted into a ticket:

```powershell
# copy the list of hostnames, then:
cliplist | tp -Port 3389 | Where-Object { -not $_.Open }
```

### Certificates and TLS

```powershell
certexp mail.contoso.com, vpn.contoso.com | Sort-Object DaysLeft
Get-CertificateInfo https://intranet.contoso.com
Test-TlsProtocol intranet.contoso.com     # which TLS versions are enabled?
Get-TlsSecurityProtocol                    # what this session allows
decode-jwt $token                          # read a JWT (ConvertFrom-JwtToken)
```

### Active Directory

```powershell
locked                              # who's locked out right now?
ustat jsmith                        # enabled? locked? when does the password expire?
ustat jsmith -Unlock                # ...and offer to unlock
seu smith                           # find users by name/email/description
seg vpn -MemberCount                # find groups
copygroups bsmith jdoe -WhatIf      # preview "make jdoe like bsmith"
copygroups bsmith jdoe -Filter 'APP-*'
Test-ADCredential                   # check a username/password works
Invoke-GroupPolicyUpdate            # gpupdate /force, elevated
```

Always hit the same domain controller: add `$PSDefaultParameterValues['*-AD*:Server'] = 'dc01.contoso.local'` to `local.ps1`.

### Server health

```powershell
uptime -ComputerName srv01, srv02   # last boot, remote
errs                                # last 15 Critical/Error events
errs -Hours 2 -ComputerName srv01
Test-PendingReboot                  # is a reboot pending?
Get-SystemInfo                      # OS, CPU, memory, disks, network in one view
Show-SystemResourceMonitor          # live CPU/memory/disk dashboard
topp -By CPU                        # top processes
df                                  # disk space (Get-DiskUsage)
du C:\Users -Top 10                 # what's using the space? (Get-FolderSize)
Show-FileStorageMetrics C:\Shares   # deeper storage breakdown
Get-NetworkProcess                  # which process has which connection
```

### Files

```powershell
ff *.log -Path C:\inetpub           # find files (Find-File)
search 'ConnectionString' -Path .   # search inside files (Search-FileContent)
sarep 'oldserver' 'newserver' -Path .\configs -WhatIf   # find & replace (Replace-StringInFile)
Remove-OldFile C:\Logs -OlderThan 30 -WhatIf
Sync-Directory \\src\share D:\backup
extract .\archive.tar.gz            # Extract-Archive
Get-FileEncoding .\file.txt ; Convert-LineEnding .\script.sh -LineEnding LF
hash .\installer.msi -Expected 3F2A...   # MATCH / MISMATCH
ubd                                 # unblock everything in Downloads
encrypt .\secrets.zip               # AES-256 with a password (Protect-PathWithPassword)
```

### Passwords for users

```powershell
dp                                  # easy to read over the phone: "silly-dino47"
dp -Strong                          # DinoPass's stronger style
genpass -Length 20 -Copy            # proper random password (never leaves your PC)
```

DinoPass is meant to be fun and easy to remember, not strong, so use it for temporary passwords that must be changed at first sign-in. If dinopass.com can't be reached, `dp` gives you a local password instead.

### Elevation

```powershell
admin                               # new elevated tab in Windows Terminal (or a window)
admin Restart-Service Spooler       # run something elevated, quotes and all
Test-Admin                          # am I elevated?
```

### PowerShell modules

```powershell
Get-OutdatedModule                  # what has updates?
Update-AllModule                    # update them all
Remove-OldModule                    # clean up old versions
```

### Ask Microsoft 365 Copilot

`ask` sends a question to M365 Copilot, which answers from your mail, calendar, Teams chats, OneDrive/SharePoint files and the web, and prints the answer with its sources.

```powershell
ask what meetings do I have tomorrow
ask who did I promise to follow up with this week       # follow-ups continue the same conversation
ask -New summarize unread email from my manager          # start fresh
Get-Content .\error.log -Tail 50 | ask what is causing these errors   # piped text = extra context
ask -NoWeb what did we decide about the VPN migration    # company data only, no web search
ask -File 'https://contoso.sharepoint.com/sites/IT/Shared Documents/Runbook.docx' what are the failover steps
ask -SignOut
```

**One-time setup:**

1. You need a **Microsoft 365 Copilot license** on your work account.
2. `Install-Module Microsoft.Graph.Authentication -Scope CurrentUser`
3. Run `ask hello`. A Microsoft sign-in opens. It uses Microsoft's own *Graph Command Line Tools* app, so you don't need to register an app.
4. If you see **"Need admin approval"**, your tenant hasn't approved these read permissions for that app yet. Send your Entra admin this list: `Sites.Read.All, Mail.Read, People.Read.All, OnlineMeetingTranscript.Read.All, Chat.Read, ChannelMessage.Read.All, ExternalItem.Read.All`. All of them are delegated, so Copilot only ever sees what *you* can already see.

More than one tenant? Set `$PwshProfileConfig.CopilotTenantId = 'contoso.onmicrosoft.com'` in `local.ps1`, or pass `-TenantId`.

Notes: the Copilot Chat API is still **beta** at Microsoft, so it can change. Very long questions can time out. Answers are text only.

### Little things

```powershell
genpass -Length 24 -Copy            # strong local password to clipboard (New-Password)
dp                                  # DinoPass: "stinky-raptor42" style, copied (Get-DinoPass)
dp -Strong ; dp -Count 5 -NoCopy
b64 'text' ; unb64 'dGV4dA=='       # Base64
mac 001a.2b3c.4d5e                  # MAC address formats
Get-IPSubnet -CIDR 10.1.2.0/22      # subnet math
ConvertTo-TimeZone -TimeZone 'Asia/Tokyo'
weather ; joke                      # morale
title PROD - CAREFUL                # set the tab title
ska                                 # Start-KeepAlive: stop the PC sleeping/locking
```

---

## 9. Customizing for one machine: `local.ps1`

`ep -Local` opens `~/.pwsh-profile/local.ps1`. It's **gitignored**, so nothing in it ever goes to GitHub. That makes it the place for work-specific or private settings. It runs **last**, so it can override anything.

Examples (the template has more):

```powershell
# AD: always use this DC
$PSDefaultParameterValues['*-AD*:Server'] = 'dc01.contoso.local'

# Default weather location
$PwshProfileConfig.WeatherLocation = 'Alameda'

# Don't set up these tools after startup
$PwshProfileConfig.DeferredInit = @('gh')

# Start in your scripts folder
Set-Location C:\Scripts

# A short alias for something you type all day
Set-Alias -Name k -Value kubectl

# Different prompt engine
oh-my-posh init pwsh | Invoke-Expression
```

**All settings** (`$PwshProfileConfig`):

| Setting | Default | Effect |
|---|---|---|
| `ShowGitBranch` | `$true` | git branch in the prompt |
| `ShowDuration` | `$true` | last command's duration in the prompt |
| `DurationThresholdMs` | `2000` | only show durations longer than this |
| `PromptChar` | `'>'` | the prompt character |
| `DirHistoryMax` | `50` | how many folders `dh` remembers |
| `DeferredInit` | `@('gh','zoxide')` | tools initialised after the first prompt (if installed) |
| `WeatherLocation` | (none) | default for `weather` |
| `CopilotTenantId` | (none) | tenant for `ask` (Invoke-CopilotChat) |

**Environment variables** (set before the profile loads, e.g. in Windows Terminal profile settings):

| Variable | Effect |
|---|---|
| `PWSH_PROFILE_EAGER=1` | load every function at startup (gives parameter tab-completion immediately; slower) |
| `PWSH_PROFILE_TIMING=1` | print how long each part of startup took |

Secrets (API keys, passwords) **don't** belong in `local.ps1` either. Use the SecretManagement module (`Install-Module Microsoft.PowerShell.SecretManagement, Microsoft.PowerShell.SecretStore`) and fetch them with `Get-Secret` when needed.

---

## 10. Adding your own functions

### The quick way

```powershell
newfn Get-PrinterQueue -Category System -Alias pq -Synopsis 'Shows print jobs on a print server.'
```

This creates `Functions/System/Get-PrinterQueue.ps1` from a template, registers it immediately, and opens it in your editor. Write the body, save, and run `reload` to try it.

For something that should **only** live on this machine, like a work-specific helper:

```powershell
newfn Connect-HomeLab -Local       # goes in Functions/Local/ (gitignored)
```

### The rules (the tests check these)

1. **One public function per file**, named after the function: `Functions/<Category>/Verb-Noun.ps1`. Use an approved verb (`Get-Verb`).
2. **Aliases go in a header comment** above the `function` line:
   ```powershell
   # Alias: pq
   function Get-PrinterQueue {
   ```
   Use `# Alias(Windows): df` for aliases that would hide a real macOS/Linux command.
3. **Help goes inside the function**, so `Get-Help` and `pf` can find it:
   ```powershell
   function Get-PrinterQueue {
       <#
       .SYNOPSIS
           Shows print jobs on a print server.
       .EXAMPLE
           pq printsrv01
       #>
       [CmdletBinding()]
       param([string]$ComputerName = 'localhost')
       ...
   }
   ```
4. **Helpers** go inside the main function, or in a `Private/` subfolder (files there are never turned into commands).
5. **State that must survive between calls** uses `$global:` (see `Core/00-Environment.ps1`).
6. **Keep files ASCII**, or save them as UTF-8 *with BOM*. Windows PowerShell 5.1 misreads UTF-8 files that have no BOM.

### Functions that use other functions

Just call them by name. If `Get-Thing` calls `Format-Byte`, the `Format-Byte` stub loads it on first use. You don't need to dot-source anything.

### Changing Core

`Core/` files load on every startup, so keep them small and fast. Check the cost with `$env:PWSH_PROFILE_TIMING='1'; reload`. Anything slow (spawning a process, network calls) belongs in a function, or in `Invoke-PwshProfileIdleWork` (`Core/30-Completers.ps1`), which runs after the first prompt.

### Publishing a change

```powershell
cd ~/.pwsh-profile
./tools/Update-FunctionDocs.ps1     # refresh docs/FUNCTIONS.md
git add -A
git commit -m "Add Get-PrinterQueue"
git push
```

Then run `Update-Profile` on your other machines.

---

## 11. Functions from jonlabelle/pwsh-profile

[Jon LaBelle's profile](https://github.com/jonlabelle/pwsh-profile) has a large, well-tested function library under the MIT license. **59 of his functions are included here**, mostly networking, DNS, certificates, system administration, module management and file utilities. They're marked **J** in [FUNCTIONS.md](FUNCTIONS.md), and each file starts with:

```powershell
# Source: jonlabelle/pwsh-profile@b888ab6 (MIT, Copyright (c) Jon LaBelle) - Functions/NetworkAndDns/Get-Whois.ps1
```

His license is in [THIRD-PARTY-NOTICES.md](../THIRD-PARTY-NOTICES.md).

**Pulling his latest fixes:**

```powershell
cd ~/.pwsh-profile
./tools/Sync-Upstream.ps1
./tools/Update-FunctionDocs.ps1
git diff                     # review what changed
git commit -am "Sync jonlabelle/pwsh-profile" ; git push
```

**Adding more of his functions:** add the line to `$Map` at the top of `tools/Sync-Upstream.ps1` (plus any functions it calls), then run the sync. Left out on purpose:

- his developer/GitHub/Docker helpers and media tools (not sysadmin-focused)
- his package manager UI (needs several private helpers)
- functions that clash with ours: his `Test-Port`, `Get-CertificateExpiration`, Base64, profile management, `Get-WhichCommand` and `New-RandomString`

**Changing one of his files:** the sync overwrites upstream files. If you want to change one permanently, remove it from `$Map` and delete its `# Source:` header line so it becomes yours.

---

## 12. Keeping machines in sync

| Task | Command |
|---|---|
| Check for updates | `Update-Profile -CheckOnly` |
| Update and reload | `Update-Profile` |
| Reload after editing locally | `reload` |
| Set up a new machine | the one-line install from [section 2](#2-install) |

Your `local.ps1` and `Functions/Local/` are never touched by updates.

`Update-Profile` uses `git pull --ff-only`. If you've edited files in `~/.pwsh-profile` on that machine without committing, it stops and tells you. Commit and push them, or `git stash`.

---

## 13. Using functions on remote servers

Profiles don't run in `Enter-PSSession` / `Invoke-Command` sessions. To use a profile function on a remote machine, send its definition along:

```powershell
$def = Get-Content $PwshProfileFunctions['Test-Port'] -Raw
Invoke-Command -ComputerName srv01 -ScriptBlock {
    param($code) . ([scriptblock]::Create($code))
    Test-Port dc01 389, 636
} -ArgumentList $def
```

Many functions also take `-ComputerName` themselves (`uptime`, `errs`, `ustat -Server`, ...), which is simpler.

---

## 14. How the lazy loading works

At startup, `profile.ps1`:

1. **Loads `Core/*.ps1`** in order: settings, PSReadLine, prompt, completers.
2. **Scans `Functions/`** and, for each `Verb-Noun.ps1`, defines a tiny *stub* function with the same name, plus any aliases from the file's header. Nothing in the file itself is run.
3. **Runs `local.ps1`.**

The first time you call a function, its stub:

1. dot-sources the real file
2. replaces itself (globally) with the real function
3. runs it with exactly the arguments and pipeline input you gave

After that the real function runs directly, with no extra overhead. Because the stub has the right name, `Get-Command`, tab completion of command names and other functions that check `Get-Command` all work before loading. The one trade-off is that **parameter** tab completion appears after the first call. Set `PWSH_PROFILE_EAGER=1` if you'd rather have it from the start.

Load functions on demand yourself with `Import-ProfileFunction Test-Port` or `Import-ProfileFunction -All`.

---

## 15. Performance

Measured on a small cloud VM:

| | Time |
|---|---|
| Creating stubs for all 96 functions | ~70 ms |
| Loading all 96 function files instead | ~1,100 ms |
| Whole profile (Core + stubs) | ~150-250 ms, mostly PSReadLine's own setup |

Check your machine:

```powershell
Measure-ProfileLoad                      # average of 10 shell starts, with and without the profile
$env:PWSH_PROFILE_TIMING = '1'; reload   # per-step breakdown
```

If startup feels slow, the usual causes are: something heavy in `local.ps1` (oh-my-posh, `Import-Module` of a big module), a slow network drive in `$env:PSModulePath`, or antivirus scanning `~/.pwsh-profile`. On a managed PC you may be able to ask for that folder to be excluded.

---

## 16. Troubleshooting

**The profile doesn't load at all.**
Check that the loader block is in your profile: `Get-Content $PROFILE.CurrentUserAllHosts`. Re-run the installer. On Windows, check `Get-ExecutionPolicy -List`. If it says `AllSigned`, or Group Policy forces `Restricted`, profiles can't run. Ask whoever manages the PC, or run `pwsh -ExecutionPolicy Bypass`.

**"pwsh-profile: 20-Prompt.ps1 failed: ..." at startup.**
A Core file threw an error. The rest of the profile still loaded. Run `ep` and look at that file, or `git -C ~/.pwsh-profile status` to see what changed.

**"'X' did not define a function named 'X'".**
The file name and the function name inside it don't match. Rename one so they do.

**A function works in PowerShell 7 but shows garbled characters in 5.1.**
The file is UTF-8 without a BOM. Re-save it as "UTF-8 with BOM" (VS Code: click the encoding in the status bar → *Save with Encoding*).

**An alias doesn't work.**
Check the header line is above `function` and within the first 12 lines: `# Alias: xyz`. Built-in read-only aliases (`cd`, `dir`, ...) can't be overridden. `pf` shows which aliases took effect.

**Tab completion doesn't show a profile function's parameters.**
Expected until the first call (see [section 14](#14-how-the-lazy-loading-works)). Run it once, or `Import-ProfileFunction Name`.

**My Documents folder is on OneDrive and things look odd.**
The installer uses Windows' real Documents path, so OneDrive is fine. If OneDrive says files are "online only", right-click `Documents\PowerShell` → *Always keep on this device*.

**`Update-Profile` says git pull failed.**
You have uncommitted changes in `~/.pwsh-profile`. Run `git -C ~/.pwsh-profile status`, then commit or stash them.

**AD functions say the module isn't installed.**
Install RSAT (see [section 2](#recommended-extras-optional)). The AD functions only load the module when you run them.

**Start fresh.**
`& ~/.pwsh-profile/install.ps1 -Uninstall`, delete `~/.pwsh-profile`, then reinstall.

---

## 17. Repo layout, tests and CI

```
profile.ps1                 the loader
Core/                       always loaded (keep fast)
Functions/<Category>/       one function per file, lazy-loaded
Functions/Local/            machine-only functions (gitignored)
local.example.ps1           template for local.ps1 (gitignored copy)
install.ps1                 installer / updater / uninstaller
tools/Sync-Upstream.ps1     pull functions from jonlabelle/pwsh-profile
tools/Update-FunctionDocs.ps1  regenerate docs/FUNCTIONS.md
docs/GUIDE.md               this guide
docs/FUNCTIONS.md           generated function reference
Tests/Profile.Tests.ps1     Pester tests
.github/workflows/ci.yml    CI: tests + PSScriptAnalyzer on 4 platforms
```

**Run the tests locally:**

```powershell
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser -Force -SkipPublisherCheck
Invoke-Pester ./Tests -Output Detailed
```

They check that every file parses, every function file follows the rules in [section 10](#10-adding-your-own-functions), every function loads through its stub, stubs pass arguments and pipeline input correctly, aliases don't collide, and the prompt and directory history work.

**CI** (GitHub Actions) runs on every push to Windows + PowerShell 7, Windows PowerShell 5.1, Ubuntu and macOS. It runs PSScriptAnalyzer, the Pester tests, checks `docs/FUNCTIONS.md` is up to date, and does a full install/uninstall round trip.

---

## 18. Uninstall

```powershell
& ~/.pwsh-profile/install.ps1 -Uninstall      # removes the loader block from your profiles
Remove-Item ~/.pwsh-profile -Recurse -Force   # optional: delete the files
```

Backups of any profile the installer changed are next to the original, named `profile.ps1.bak-<date>`.
