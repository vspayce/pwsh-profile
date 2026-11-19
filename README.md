# pwsh-profile

A fast, modular PowerShell profile for sysadmins. **New here? Read the [guide](docs/GUIDE.md).** Every function lives in its own file and only loads the first time you use it, so the shell stays quick no matter how many you add.

Works on **PowerShell 7+** (Windows, macOS, Linux) and **Windows PowerShell 5.1**.

## Install

```powershell
irm https://raw.githubusercontent.com/vspayce/pwsh-profile/main/install.ps1 | iex
```

What that does:

- clones this repo to `~/.pwsh-profile` (it downloads a zip if git isn't installed)
- adds a three-line loader block to your profile; on Windows it does this for **both** PowerShell 7 and 5.1
- backs up any profile file it changes, and is safe to run again

Update later with `Update-Profile`. Uninstall with `& ~/.pwsh-profile/install.ps1 -Uninstall`.

> Windows PowerShell 5.1 on an older machine? Run this first:
> `[Net.ServicePointManager]::SecurityProtocol = 'Tls12'`

## How it works

```
profile.ps1                    loader - dot-sourced from $PROFILE
Core/                          always loaded, kept tiny
  00-Environment.ps1           settings, platform/admin flags, UTF-8, TLS 1.2
  10-PSReadLine.ps1            history search, predictions, menu completion
  20-Prompt.ps1                prompt, directory history, window title
  30-Completers.ps1            winget/dotnet completion, deferred gh/zoxide init
  40-Shortcuts.ps1             ..  ...  ....
Functions/<Category>/Verb-Noun.ps1   one function per file, lazy-loaded
Functions/Local/               your machine-only functions (gitignored)
local.ps1                      your machine-only settings (gitignored)
```

At startup the loader creates a tiny stub for each file in `Functions/`. The first time you call `Test-Port`, its stub dot-sources `Test-Port.ps1`, replaces itself with the real function, and runs it with your arguments and pipeline input. Aliases come from a comment at the top of each file, so `tp` works before anything is loaded.

Slow init scripts (like `gh` completion and `zoxide`) run right after the first prompt appears, so they never delay startup.

Want to see where startup time goes? Run `$env:PWSH_PROFILE_TIMING = '1'; reload`, or `Measure-ProfileLoad`.

## What's in it

**98 functions** across networking & DNS, certificates & TLS, Active Directory, system health, files, modules and everyday utilities: 39 of ours plus 59 curated from [jonlabelle/pwsh-profile](https://github.com/jonlabelle/pwsh-profile).

- **[docs/GUIDE.md](docs/GUIDE.md)**: the full guide (install, cookbook, customizing, adding functions, troubleshooting)
- **[docs/FUNCTIONS.md](docs/FUNCTIONS.md)**: every function with alias, description and an example (generated from the code)
- In your shell: `pf` lists them all, `pf dns` searches, `Get-Help <name> -Examples` shows examples

A taste:

| Alias | Does |
|---|---|
| `tp host 80,443` | fast port check (many hosts/ports) |
| `netdiag host` | full network diagnostic with a latency graph |
| `certexp host` | when a TLS cert expires |
| `myip` | local + public IP |
| `flushdns` | flush DNS on any OS |
| `locked` / `ustat user -Unlock` | AD lockouts and real password expiry |
| `seu name` / `seg name` | fuzzy AD user / group search |
| `copygroups from to -WhatIf` | copy group memberships |
| `uptime` / `errs` | last boot / recent Critical+Error events |
| `Get-SystemInfo` / `Test-PendingReboot` | one-screen system summary / reboot pending? |
| `admin cmd` | run something elevated (new Windows Terminal tab) |
| `dh` / `j 3` / `j proj` | session folder history and jump back |
| `search text` / `sarep old new` | search / replace inside files |
| `ask what's on my calendar` | Microsoft 365 Copilot from the terminal ([setup](docs/GUIDE.md#ask-microsoft-365-copilot)) |
| `genpass -Copy` / `dp` | strong password / a DinoPass one ("stinky-raptor42") to clipboard |
| `cliplist` | pasted list to a clean array |
| `pf` / `newfn` / `ep` / `reload` | list / create / edit / reload profile functions |

### Prompt

```
 ADMIN  ~/src/pwsh-profile (main) 3.4s
>
```

- a red **ADMIN** badge when elevated; `user@host` over SSH or remoting
- the git branch, read straight from `.git/HEAD` (no git.exe call, so it's instant)
- how long the last command took, when it was over 2 seconds
- the `>` turns red when the last command failed
- tells Windows Terminal your current folder, so **Duplicate tab** opens in the same place

Every folder you visit is recorded, including via `cd`, `pushd`, `cd -` and scripts, so `dh` and `j` always have the full history.

### Keys (PSReadLine)

| Key | Action |
|---|---|
| ↑ / ↓ | Search history for lines starting with what you've typed |
| Tab / F1 | Menu of all completions |
| F2 | Switch inline / list prediction view |
| Ctrl+F | Accept the next word of a suggestion |
| Ctrl+D | Exit on an empty line |

Lines containing things like `password`, `token` or `-AsPlainText` are never saved to your history file.

## Customizing

- **Settings for one machine:** `ep -Local` opens `local.ps1`, which is never committed. It shows how to set a default AD server, turn off parts of the prompt, add oh-my-posh, and so on.
- **A new function for everyone:** `newfn Get-PrinterQueue -Category System -Alias pq` creates the file from a template, registers it, and opens it. Commit and push.
- **A function for this machine only:** `newfn Connect-HomeLab -Local` (goes in `Functions/Local/`, which is gitignored).

### Rules for function files

1. Name the file after the function: `Functions/<Category>/Verb-Noun.ps1`, one public function per file.
2. Put aliases in the header: `# Alias: tp` (or `# Alias(Windows): df` for Windows-only).
3. Put comment-based help **inside** the function so `Get-Help` and `pf` can read it.
4. Put helper functions inside the main function, or in a `Private/` folder (those are skipped by the loader).
5. Use `$global:` for state that has to outlive a call (see `Core/00-Environment.ps1`).

Tests in `Tests/` enforce 1–3 on every push.

## Tests

```powershell
Install-Module Pester -MinimumVersion 5.5 -Scope CurrentUser
Invoke-Pester ./Tests
```

GitHub Actions runs the tests and PSScriptAnalyzer on Windows (PowerShell 7 and 5.1), macOS and Linux, and checks `docs/FUNCTIONS.md` is current (`./tools/Update-FunctionDocs.ps1`).

## Credits

- 59 functions come from **[jonlabelle/pwsh-profile](https://github.com/jonlabelle/pwsh-profile)** (MIT, Copyright (c) Jon LaBelle). See [THIRD-PARTY-NOTICES.md](THIRD-PARTY-NOTICES.md). Pull his updates with `./tools/Sync-Upstream.ps1`.
- Ideas from the r/PowerShell thread *"What clever things do you have in your $profile?"*

## License

MIT
