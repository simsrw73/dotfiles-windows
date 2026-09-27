#Requires -Version 7.0
# cli_tools_config.ps1  -  STAGING FILE. NOT LOADED BY ANY PROFILE. DO NOT DOT-SOURCE.
#
# This file is the un-folded remainder of the original per-tool config. Everything
# DotForge already covers has been deleted (2026-07-15); what is left is the backlog.
#
#   Design/spec:  DotForge/docs/superpowers/specs/2026-07-15-legacy-profile-fold-in-design.md
#   Full history: git show 713f6ff:ProfileModules/cli_tools_config.ps1
#
# IMPORTANT: because this file is not loaded, everything below is INACTIVE TODAY.
# These are live regressions, not a tidy-up backlog. Deleting a block here without
# folding it into DotForge silently drops the feature for good.
#
# Folded in already (deleted): eza aliases+ff, bat env+cat, fd ffd, ripgrep env+frg,
#   procs fkill, winfetch, curl, micro, less, lazygit, zoxide (fcd->fzo), gsudo,
#   posh-git pickers, Terminal-Icons, oh-my-posh, PSFzf, npm env+nls, winget wins/wrm,
#   scoop scoop-search hook, uv/chezmoi/glow/docker env vars.
# Deleted as empty placeholders: fx, jid, duf, dua, gdu, ntop, moor, gemini, win32yank,
#   scoop-completion, PSAISuite, PSWindowsUpdate, Admin, cargo, DockerCompletion, PowerType.

# ── Helpers still needed by the blocks below ─────────────────────────────────
$script:_toolsFound   = [System.Collections.Generic.List[string]]::new()
$script:_toolsMissing = [System.Collections.Generic.List[string]]::new()

function script:_HasCmd {
    param([string]$Label, [string]$Exe = '')
    if (-not $Exe) { $Exe = "$Label.exe" }
    if ($null -ne (Get-Command $Exe -ErrorAction Ignore)) {
        $null = $script:_toolsFound.Add($Label); $true
    } else {
        $null = $script:_toolsMissing.Add($Label); $false
    }
}

# _GetCachedCompletion was removed 2026-07-15: every tool that used it (fd, rg, glow,
# procs, rustup, gh, chezmoi) is now covered by carapace, so nothing needs to generate
# and cache completion scripts. Recover it from git if a tool ever falls outside
# carapace's coverage: git show 713f6ff:ProfileModules/cli_tools_config.ps1

function script:Ensure-Dir {
    param([string]$Path)
    if ($Path) { New-Item -ItemType Directory -Force -Path $Path -ErrorAction SilentlyContinue | Out-Null }
}

# ==============================================================================
# GAP 4  -  Env/config not folded in  (spec §4)
# Highest-value, lowest-effort: these are pure Tools/*.json edits.
# ==============================================================================

# fzf and delta env vars: FOLDED IN 2026-07-15 -> Tools/fzf.json, Tools/delta.json.
# Caveat recorded in the spec: DELTA_FEATURES=catppuccin-mocha is a no-op — no
# [delta "catppuccin-mocha"] feature is defined in any git config scope, and delta
# silently ignores unknown features. Ported faithfully; define the feature to use it.

#region ripgrep  -  default config seeding  (spec §4: schema limitation)
# RIPGREP_CONFIG_PATH is already folded into Tools/ripgrep.json (method 'env').
# Only the default-file seeding remains. Blocked: xdg.method is a single value and
# the 'config' branch does not set env vars, so 'env' + seed is not expressible.
if (_HasCmd 'rg') {
    if (-not (Test-Path $Env:RIPGREP_CONFIG_PATH)) {
        Set-Content -Path $Env:RIPGREP_CONFIG_PATH -Value "# ripgrep config`n--smart-case`n--hidden" -Encoding UTF8
    }
}
#endregion ripgrep

#region wget  -  config file creation  (spec §4: same schema limitation)
# WGETRC is folded into Tools/wget.json; only the empty-file touch remains.
if (_HasCmd 'wget') {
    $null = New-Item -ItemType File -Force -Path $Env:WGETRC -ErrorAction SilentlyContinue
}
#endregion wget

#region docker  -  unconditional DOCKER_CONFIG  (spec §4: confirm intent)
# Legacy set this OUTSIDE the availability guard so docker-compose and friends
# use the XDG path even when the docker CLI is absent. DotForge only sets it when
# docker is present. Behavior change — decide whether it matters.
$Env:DOCKER_CONFIG = Join-Path $Env:XDG_CONFIG_HOME 'docker'
Ensure-Dir $Env:DOCKER_CONFIG
#endregion docker

#region bat  -  cat fallback when bat is absent  (spec §4)
# Tools/bat.json aliases cat -> bat, but only when bat is installed. This else-branch
# fallback has no home in DotForge, which registers nothing for missing tools.
if (-not (Get-Command bat.exe -ErrorAction Ignore)) {
    function global:Join-Files {
        [CmdletBinding()]
        param([Parameter(ValueFromRemainingArguments)][string[]]$Path)
        Get-Content @Path
    }
    Set-Alias -Name cat -Value Join-Files -Scope Global -Force
}
#endregion bat

# ==============================================================================
# GAP 2  -  Completions  (spec §2)
#
# RESOLVED 2026-07-15 for 11 of 16 tools: carapace is now a DotForge tool
# (Tools/carapace.json + Tools/carapace.ps1) and registers native argument
# completers for ~519 commands, including eza, bat, fd, rg, npm, gh, glow,
# procs, rustup, chezmoi and winget. Those completers were deleted from here.
#
# No DotForge `completion` schema was built — carapace made it unnecessary for
# the common case. The five below are the entire remaining gap.
#
# Trade-off accepted: carapace ships curated specs that can lag the installed
# binary, whereas the deleted `_GetCachedCompletion` ones were generated from the
# binary itself and so always matched its version exactly.
#
# For these five, prefer a carapace custom spec (~/.config/carapace/specs/*.yaml)
# over reviving a DotForge completion engine.
# ==============================================================================

#region completions still missing: not covered by carapace  (spec §2)
if (_HasCmd 'broot') {
    Register-ArgumentCompleter -Native -CommandName broot -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $flags = @(
            '--sizes', '--dates', '--permissions', '--hidden', '--git-ignored',
            '--no-sizes', '--no-dates', '--no-permissions',
            '--color', '--cmd', '--conf', '--outcmd',
            '--sort-by-count', '--sort-by-date', '--sort-by-size',
            '--whale-spotting', '--only-folders', '--show-root-fs',
            '--install', '--print-shell-function', '--help', '--version'
        )
        $flags | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

# sfsu has no Tools/*.json record yet (spec §6)
if (_HasCmd 'sfsu') {
    Register-ArgumentCompleter -Native -CommandName sfsu -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'search', 'info', 'install', 'update', 'upgrade',
            'status', 'depends', 'checkver', 'cat', 'virustotal'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

# nvm has no Tools/*.json record yet (spec §6)
if (_HasCmd 'nvm' -Exe 'nvm') {
    Register-ArgumentCompleter -Native -CommandName nvm -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'install', 'uninstall', 'use', 'list', 'ls', 'list available',
            'ls-remote', 'current', 'alias', 'unalias', 'reinstall-packages',
            'version', 'version-remote', 'deactivate', 'root', 'arch', 'node_mirror', 'npm_mirror'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

if (_HasCmd 'uv') {
    Register-ArgumentCompleter -Native -CommandName uv -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'pip', 'venv', 'run', 'sync', 'lock', 'add', 'remove', 'tool',
            'python', 'init', 'build', 'publish', 'cache', 'self', 'version',
            'help', 'export', 'tree', 'generate-shell-completion'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}

if (_HasCmd 'bw' -Exe 'bw') {
    Register-ArgumentCompleter -Native -CommandName bw -ScriptBlock {
        param($wordToComplete, $commandAst, $cursorPosition)
        $subcommands = @(
            'login', 'logout', 'lock', 'unlock', 'sync', 'list', 'get',
            'create', 'edit', 'delete', 'restore', 'move', 'confirm',
            'import', 'export', 'generate', 'encode', 'config', 'update',
            'completion', 'status', 'serve', 'receive'
        )
        $subcommands | Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
#endregion completions still missing

# ==============================================================================
# GAP 3  -  Pickers declared "custom" but never implemented  (spec §3)
# Each tool below has "picker": "custom" in Tools/*.json with no sidecar picker,
# so Register-DFTool silently does nothing.
# ==============================================================================

#region jq  -  fjq
if (_HasCmd 'jq') {
    function global:Select-JsonPath {
        [CmdletBinding()]
        param([string]$File = '')
        if (-not $File) {
            $File = fzf --header 'Select JSON file' --preview 'bat --color=always {}'
        }
        if (-not $File -or -not (Test-Path $File)) { return }
        $json = Get-Content $File -Raw
        $filter = Read-Host 'jq filter (default: .)'
        if (-not $filter) { $filter = '.' }
        $json | jq $filter
    }
    Set-Alias -Name fjq -Value Select-JsonPath -Scope Global
}
#endregion jq

#region glow  -  fgl
if (_HasCmd 'glow') {
    function global:Read-MarkdownFile {
        [CmdletBinding()]
        param([string]$Path = '.')
        $file = Get-ChildItem -Path $Path -Recurse -Filter '*.md' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty FullName |
            fzf --preview 'glow --style dark {}' `
                --preview-window 'right:60%' `
                --header 'Select markdown file (Enter to render with glow)'
        if ($file) { glow $file }
    }
    Set-Alias -Name fgl -Value Read-MarkdownFile -Scope Global
}
#endregion glow

#region docker  -  fdc / fdi
if (_HasCmd 'docker' -Exe 'docker') {
    function global:Select-DockerContainer {
        [CmdletBinding()]
        param([switch]$All)
        $dockerArgs = if ($All) { @('ps', '--all') } else { @('ps') }
        $container = docker @dockerArgs --format 'table {{.ID}}\t{{.Names}}\t{{.Image}}\t{{.Status}}' 2>$null |
            Select-Object -Skip 1 |
            fzf --preview-window 'hidden' `
                --header 'Select container (Enter to exec shell)'
        if ($container) {
            $id = ($container -split '\s+')[0]
            docker exec -it $id sh
        }
    }
    Set-Alias -Name fdc -Value Select-DockerContainer -Scope Global

    function global:Select-DockerImage {
        [CmdletBinding()]
        param()
        $image = docker images --format 'table {{.Repository}}\t{{.Tag}}\t{{.ID}}\t{{.Size}}' 2>$null |
            Select-Object -Skip 1 |
            fzf --preview-window 'hidden' `
                --header 'Select image'
        if ($image) { ($image -split '\s+')[2] }
    }
    Set-Alias -Name fdi -Value Select-DockerImage -Scope Global
}
#endregion docker

#region scoop  -  sins / srm  (Tools/scoop.ps1 exists but has no picker)
if (_HasCmd 'scoop' -Exe 'scoop') {
    function global:Select-ScoopPackage {
        [CmdletBinding()]
        param([string]$Query = '')
        $pkg = sfsu search $Query 2>$null |
            fzf --header 'Select package to install (Enter to scoop install)' `
                --preview 'sfsu info {}' `
                --preview-window 'right:60%'
        if ($pkg) {
            $name = ($pkg -split '\s+')[0]
            Write-Host "⚙  Installing $name…" -ForegroundColor Cyan
            scoop install $name
        }
    }
    Set-Alias -Name sins -Value Select-ScoopPackage -Scope Global

    function global:Remove-ScoopPackage {
        [CmdletBinding()]
        param()
        $pkg = scoop list 2>$null | Select-Object -Skip 2 |
            Where-Object { $_ -match '\S' } |
            fzf --header 'Select package to uninstall (Enter to scoop uninstall)'
        if ($pkg) {
            $name = ($pkg -split '\s+')[0]
            Write-Host "⚙  Uninstalling $name…" -ForegroundColor DarkYellow
            scoop uninstall $name
        }
    }
    Set-Alias -Name srm -Value Remove-ScoopPackage -Scope Global
}
#endregion scoop

#region rustup  -  frtc
if (_HasCmd 'rustup') {
    function global:Select-RustupToolchain {
        [CmdletBinding()]
        param()
        $toolchain = rustup toolchain list 2>$null |
            fzf --preview-window 'hidden' `
                --header 'Select Rust toolchain (Enter to rustup default)'
        if ($toolchain) {
            $name = ($toolchain -split '\s+')[0]
            rustup default $name
        }
    }
    Set-Alias -Name frtc -Value Select-RustupToolchain -Scope Global
}
#endregion rustup

#region npm  -  fns
if (_HasCmd 'npm' -Exe 'npm') {
    function global:Select-NpmScript {
        [CmdletBinding()]
        param()
        if (-not (Test-Path 'package.json')) {
            Write-Warning 'No package.json in current directory'
            return
        }
        $scripts = (Get-Content 'package.json' -Raw | ConvertFrom-Json).scripts.PSObject.Properties |
            ForEach-Object { "$($_.Name)" }
        $script = $scripts | fzf --preview-window 'hidden' `
            --header 'Select npm script (Enter to npm run)'
        if ($script) { npm run $script }
    }
    Set-Alias -Name fns -Value Select-NpmScript -Scope Global
}
#endregion npm

#region gh  -  fpr / fgi
if (_HasCmd 'gh') {
    function global:Select-GHPr {
        [CmdletBinding()]
        param()
        $pr = gh pr list --json number,title,author,headRefName 2>$null |
            ConvertFrom-Json |
            ForEach-Object { "$($_.number)`t$($_.title)`t($($_.author.login))" } |
            fzf --preview-window 'hidden' `
                --header 'Select PR to checkout' --delimiter "`t" --with-nth '1,2'
        if ($pr) {
            $num = ($pr -split "`t")[0].Trim()
            gh pr checkout $num
        }
    }
    Set-Alias -Name fpr -Value Select-GHPr -Scope Global

    function global:Select-GHIssue {
        [CmdletBinding()]
        param()
        $issue = gh issue list --json number,title,assignees,state 2>$null |
            ConvertFrom-Json |
            ForEach-Object { "$($_.number)`t$($_.title)" } |
            fzf --preview-window 'hidden' `
                --header 'Select issue to view' --delimiter "`t" --with-nth '1,2'
        if ($issue) {
            $num = ($issue -split "`t")[0].Trim()
            gh issue view $num --web
        }
    }
    Set-Alias -Name fgi -Value Select-GHIssue -Scope Global
}
#endregion gh

#region uv  -  fvenv
if (_HasCmd 'uv') {
    function global:Select-UvVenv {
        [CmdletBinding()]
        param([string]$SearchPath = $home)
        $venv = Get-ChildItem -Path $SearchPath -Recurse -Depth 4 -Filter 'pyvenv.cfg' -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty DirectoryName |
            fzf --preview 'cat {}/pyvenv.cfg' `
                --preview-window 'right:60%' `
                --header 'Select Python venv to activate'
        if ($venv) {
            $activate = Join-Path $venv 'Scripts' 'Activate.ps1'
            if (Test-Path $activate) { & $activate }
            else { Write-Warning "No Activate.ps1 found in $venv" }
        }
    }
    Set-Alias -Name fvenv -Value Select-UvVenv -Scope Global
}
#endregion uv

#region chezmoi  -  czf
if (_HasCmd 'chezmoi') {
    function global:Edit-DotFile {
        [CmdletBinding()]
        param()
        $file = chezmoi managed 2>$null |
            fzf --preview 'bat --color=always {}' `
                --preview-window 'right:60%' `
                --header 'Select dotfile to edit (Enter to chezmoi edit)'
        if ($file) { chezmoi edit $file }
    }
    Set-Alias -Name czf -Value Edit-DotFile -Scope Global
}
#endregion chezmoi

#region bitwarden  -  fbw
if (_HasCmd 'bw' -Exe 'bw') {
    function global:Select-BwItem {
        [CmdletBinding()]
        param(
            [ValidateSet('login', 'note', 'card', 'identity', 'all')]
            [string]$Type = 'all'
        )
        $bwArgs = @('list', 'items')
        if ($Type -ne 'all') { $bwArgs += '--search'; $bwArgs += $Type }
        $items = bw @bwArgs 2>$null | ConvertFrom-Json
        if (-not $items) { Write-Warning 'No items found. Are you logged in? Run: bw login'; return }
        $selected = $items | ForEach-Object { "$($_.name)`t$($_.id)" } |
            fzf --delimiter "`t" --with-nth 1 `
                --preview-window 'hidden' `
                --header 'Select vault item (Enter to copy password)'
        if ($selected) {
            $id = ($selected -split "`t")[1]
            bw get password $id | Set-Clipboard
            Write-Host '✓ Password copied to clipboard' -ForegroundColor Green
        }
    }
    Set-Alias -Name fbw -Value Select-BwItem -Scope Global
}
#endregion bitwarden

#region nvm  -  fnv  (no Tools/nvm.json record yet — spec §6)
if (_HasCmd 'nvm' -Exe 'nvm') {
    function global:Select-NodeVersion {
        [CmdletBinding()]
        param()
        $version = nvm list 2>$null |
            Where-Object { $_ -match '\d+\.\d+' } |
            fzf --preview-window 'hidden' `
                --header 'Select Node.js version (Enter to nvm use)'
        if ($version) {
            $ver = ($version -replace '[^\d.]', '').Trim()
            nvm use $ver
        }
    }
    Set-Alias -Name fnv -Value Select-NodeVersion -Scope Global
}
#endregion nvm

# ==============================================================================
# GAP 5  -  Functions/aliases not folded in  (spec §5)
# ==============================================================================

#region scoop  -  sstat / supd
# Port target: Tools/scoop.ps1. NOTE: supd overlaps the planned Invoke-DFMaintenance
# (TODO.md) — fold it in there rather than porting verbatim.
if (_HasCmd 'scoop' -Exe 'scoop') {
    function global:sstat { [CmdletBinding()] param() scoop update; scoop status }
    function global:supd  { [CmdletBinding()] param() scoop update *; scoop cleanup * }
}
#endregion scoop

#region winget  -  wstat / wupd  (port target: Tools/winget.ps1)
if (_HasCmd 'winget' -Exe 'winget') {
    function global:wstat { [CmdletBinding()] param() winget upgrade }
    function global:wupd  { [CmdletBinding()] param() winget upgrade --all }
}
#endregion winget

#region notepadplusplus  -  edit alias
# Overlaps $Env:EDITOR (set in Env.ps1) — reconcile rather than port blindly.
if (Test-Path -Path 'C:\Program Files\Notepad++\notepad++.exe' -PathType Leaf) {
    Set-Alias -Name edit -Value 'C:\Program Files\Notepad++\notepad++.exe' -Scope Global
} else {
    Set-Alias -Name edit -Value 'C:\Windows\system32\notepad.exe' -Scope Global
}
#endregion notepadplusplus

#region glazewm  -  needs Tools/glazewm.json + sidecar (spec §6)
if (_HasCmd 'glazewm') {
    function global:Start-GlazeWM {
        [CmdletBinding()]
        param([Parameter(ValueFromRemainingArguments)][string[]]$Arguments)
        glazewm --config (Join-Path $Env:XDG_CONFIG_HOME 'glazewm' 'config.yaml') @Arguments
    }
    Set-Alias -Name glazewm -Value Start-GlazeWM -Scope Global
}
#endregion glazewm

#region mosquitto  -  needs Tools/mosquitto.json (spec §6). Note: not XDG (~/.mosquitto).
if (_HasCmd 'mosquitto') {
    function global:Invoke-MQTT {
        $mqtt_config_file = Join-Path -Path $home -ChildPath '.mosquitto' 'config'
        mosquitto -v -c $mqtt_config_file
    }
    Set-Alias -Name mqtt -Value Invoke-MQTT -Scope Global
}
#endregion mosquitto

# ==============================================================================
# GAP 6  -  Tools with no DotForge record  (spec §6)
# ==============================================================================

#region nano  -  needs Tools/nano.json
if (_HasCmd 'nano') {
    $Env:NANORC = Join-Path $Env:XDG_CONFIG_HOME 'nano' 'nanorc'
    Ensure-Dir (Join-Path $Env:XDG_CONFIG_HOME 'nano')
    $null = New-Item -ItemType File -Force -Path $Env:NANORC -ErrorAction SilentlyContinue
}
#endregion nano

#region nvm  -  needs Tools/nvm.json
# VERIFY BEFORE PORTING: NVM_DIR is for Unix nvm. nvm-windows (scoop) uses
# NVM_HOME/NVM_SYMLINK, so this line is probably wrong on this machine.
if (_HasCmd 'nvm' -Exe 'nvm') {
    $Env:NVM_DIR = Join-Path $Env:XDG_DATA_HOME 'nvm'
}
#endregion nvm
