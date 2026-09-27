# chezmoi migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn `simsrw73/dotfiles-windows` into a chezmoi source repo that restores this machine's config, PowerShell profile, home dotfiles, secrets (Bitwarden), apps and links from a fresh Windows install.

**Architecture:** Repo root holds `bootstrap.ps1`, a tested helper module (`lib/Dotfiles.psm1`), and `linked/` (folders `~/.config` symlinks into, edited live). `home/` (via `.chezmoiroot`) is chezmoi source state: copied config, templates for secrets, symlink entries, and `run_` scripts that call the helper module.

**Tech Stack:** chezmoi 2.72, PowerShell 7, Pester 5, Bitwarden CLI (`bw`), scoop, winget, gsudo, git-filter-repo, gitleaks.

**Spec:** `docs/superpowers/specs/2026-09-27-chezmoi-migration-design.md`

## Global Constraints

- Work only in `simsrw73/dotfiles-windows`, branch `chezmoi`, worktree `C:\Users\simsr\projects\dotfiles-chezmoi`. `simsrw73/w11dwm-config` is out of scope.
- Final source dir: `C:\Users\simsr\.local\share\chezmoi`. `.chezmoiroot` contains `home`.
- Commits are GPG-signed with key `8FDC1EB03BECE139`. If pinentry times out, stop and ask the user to unlock (never pass `--no-gpg-sign`). End every commit message with:
  ```
  Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
  Claude-Session: https://claude.ai/code/session_015d5c1NpG4jLhVpJYKjBQFa
  ```
- Secrets never pass through the agent: never print, cat, or diff secret values. Anything touching `bw` item contents is run by the user (`! <command>`), or its output is hashed.
- `~/.password`, the PowerShell SecretStore vault and `CreateSecrets.ps1` are ignored — not migrated, not stored.
- Chocolatey is dropped.
- Nothing under `~/.config` is deleted before Task 11's `chezmoi diff` is reviewed; live folders are only ever renamed to `<path>.pre-chezmoi-yyyyMMdd`, never removed.
- Linked folders (symlinked from `~/.config`): `AutoHotKey`, `FlowLauncher`, `yasb`, `komorebi`, `wpm`, `claude`, `psmux`, `yazi`, `nvim`, `powershell`.

**Deviations from the spec (flag to user at review):**
1. `powershell` is added to the linked list (profile code is edited constantly).
2. Package lists live in `home/.chezmoidata/packages.yaml` instead of `packages/*.yaml`, so templates read them as `.packages` without include-path tricks.
3. Added: a user-env-var script (`SCOOP`, `KOMOREBI_CONFIG_HOME` are HKCU env vars apps need), an SSH key ACL script, and a DotForge git-repo external (the profile loads the DotForge module from `~/projects/DotForge`).

## Review Focus

1. **A real folder already sits where a link must go** (e.g., FlowLauncher auto-created `%APPDATA%\FlowLauncher` on first run) → it is renamed to `.pre-chezmoi-<date>` and linked, never merged or deleted. Tested in Task 2 (`Set-DirectoryLink backs up a real directory`).
2. **Cutover of a live folder whose tracked files have uncommitted edits** → the move aborts before touching anything and names the files. Tested in Task 2 (`Move-IntoLinked refuses on conflict and changes nothing`).
3. **Bitwarden locked, logged out, or an item missing** → the secret template fails loudly; no empty key file is written. Tested in Task 8 Step 7.
4. **Documents is local (no OneDrive)** → profile stubs go to `~/Documents/PowerShell`, not `~/OneDrive/Documents/PowerShell`. Tested in Task 5 Step 6.
5. **Second `chezmoi apply` on an already-applied machine** → no changes, no package installs, no link churn. Tested in Task 13 Step 3.

---

### Task 1: Safety backups

**Files:** none in repo. Creates `C:\Users\simsr\dotfiles-backup-2026-09-27\`.

- [ ] **Step 1: Ask user to commit or discard pending changes in `~/.config`**

Run: `git -C ~/.config status --short`
Current known changes: `claude/plugins/known_marketplaces.json`, memory files, `git/config`, `scoop/config.json`. Ask the user whether to commit them on `main` (they must be in the repo before Task 3 so the restructure carries them). Wait for answer; commit per their choice.

- [ ] **Step 2: Create bundles and copies**

```powershell
$b = "$HOME\dotfiles-backup-2026-09-27"
New-Item -ItemType Directory -Force $b | Out-Null
git -C "$HOME\.config" bundle create "$b\dotfiles-windows.bundle" --all
git -C "$HOME\OneDrive\Documents\PowerShell" bundle create "$b\powershell-profile.bundle" --all
Copy-Item -Recurse "$HOME\.ssh" "$b\ssh"
Copy-Item -Recurse "$HOME\.config\gnupg" "$b\gnupg" -ErrorAction SilentlyContinue
```

- [ ] **Step 3: Verify**

Run: `git bundle verify "$HOME\dotfiles-backup-2026-09-27\dotfiles-windows.bundle"; git bundle verify "$HOME\dotfiles-backup-2026-09-27\powershell-profile.bundle"`
Expected: both print `... is okay`.

- [ ] **Step 4: Tell the user** the backup path and that it holds private keys (keep it off cloud sync until Task 15).

---

### Task 2: Helper module `lib/Dotfiles.psm1` (TDD)

**Files:**
- Create: `lib/Dotfiles.psm1`
- Create: `tests/Dotfiles.Tests.ps1`

**Interfaces:**
- Produces:
  - `Set-DirectoryLink -Path <string> -Target <string> [-Kind Junction|SymbolicLink] [-Now <datetime>]` → returns `'created' | 'unchanged' | 'relinked' | 'backed-up'`; throws if Target dir missing.
  - `Get-BackupPath -Path <string> -Now <datetime>` → `<Path>.pre-chezmoi-yyyyMMdd[-N]` (first free).
  - `Get-Missing -Wanted <string[]> -Installed <string[]>` → `string[]` wanted-but-not-installed, case-insensitive, de-duplicated, order preserved.
  - `Move-IntoLinked -Live <string> -Linked <string> [-Now <datetime>]` → copies every file/dir/nested link from Live into Linked that Linked lacks, throws (changing nothing) if a file exists in both with different content, then `Set-DirectoryLink -Kind SymbolicLink` (Live is backed up). Returns `'already-linked'` if Live is already a link.

- [ ] **Step 1: Write the failing tests**

`tests/Dotfiles.Tests.ps1`:

```powershell
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '..\lib\Dotfiles.psm1') -Force
    $now = [datetime]'2026-09-27'
}

Describe 'Get-Missing' {
    It 'returns wanted items not installed, case-insensitively' {
        Get-Missing -Wanted 'Git','fzf','bat' -Installed 'git','BAT' | Should -Be @('fzf')
    }
    It 'handles nothing installed' {
        Get-Missing -Wanted 'a','b' -Installed @() | Should -Be @('a','b')
    }
    It 'de-duplicates and skips empty names' {
        Get-Missing -Wanted 'a','A','','b' -Installed @() | Should -Be @('a','b')
    }
    It 'returns empty array when all installed' {
        @(Get-Missing -Wanted 'a' -Installed 'a').Count | Should -Be 0
    }
}

Describe 'Get-BackupPath' {
    It 'uses the date suffix' {
        Get-BackupPath -Path "$TestDrive\x" -Now $now | Should -Be "$TestDrive\x.pre-chezmoi-20260927"
    }
    It 'adds a counter when the backup name is taken' {
        New-Item -ItemType Directory "$TestDrive\y.pre-chezmoi-20260927" | Out-Null
        Get-BackupPath -Path "$TestDrive\y" -Now $now | Should -Be "$TestDrive\y.pre-chezmoi-20260927-1"
    }
}

Describe 'Set-DirectoryLink' {
    BeforeEach {
        $target = Join-Path $TestDrive "target $(New-Guid)"   # space on purpose
        New-Item -ItemType Directory $target | Out-Null
        Set-Content "$target\f.txt" 'hi'
        $path = Join-Path $TestDrive "parent $(New-Guid)\link"
    }
    It 'creates a junction and its parent' {
        Set-DirectoryLink -Path $path -Target $target -Now $now | Should -Be 'created'
        (Get-Item $path).LinkType | Should -Be 'Junction'
        Get-Content "$path\f.txt" | Should -Be 'hi'
    }
    It 'creates a symbolic link when asked' {
        Set-DirectoryLink -Path $path -Target $target -Kind SymbolicLink -Now $now | Should -Be 'created'
        (Get-Item $path).LinkType | Should -Be 'SymbolicLink'
    }
    It 'is a no-op when already linked to the target' {
        Set-DirectoryLink -Path $path -Target $target -Now $now | Out-Null
        Set-DirectoryLink -Path $path -Target $target -Now $now | Should -Be 'unchanged'
    }
    It 'treats a symlink to the same target as unchanged even when Junction is requested' {
        Set-DirectoryLink -Path $path -Target $target -Kind SymbolicLink -Now $now | Out-Null
        Set-DirectoryLink -Path $path -Target $target -Kind Junction -Now $now | Should -Be 'unchanged'
    }
    It 'relinks a link pointing elsewhere without touching the old target' {
        $other = Join-Path $TestDrive "other $(New-Guid)"
        New-Item -ItemType Directory $other | Out-Null
        Set-Content "$other\keep.txt" 'keep'
        Set-DirectoryLink -Path $path -Target $other -Now $now | Out-Null
        Set-DirectoryLink -Path $path -Target $target -Now $now | Should -Be 'relinked'
        Test-Path "$other\keep.txt" | Should -BeTrue
        (Get-Item $path).Target | Should -Be $target
    }
    It 'backs up a real directory' {
        New-Item -ItemType Directory $path -Force | Out-Null
        Set-Content "$path\mine.txt" 'mine'
        Set-DirectoryLink -Path $path -Target $target -Now $now | Should -Be 'backed-up'
        Get-Content "$path.pre-chezmoi-20260927\mine.txt" | Should -Be 'mine'
        (Get-Item $path).LinkType | Should -Be 'Junction'
    }
    It 'throws when the target is missing and leaves the path alone' {
        { Set-DirectoryLink -Path $path -Target "$TestDrive\nope" -Now $now } | Should -Throw '*does not exist*'
        Test-Path $path | Should -BeFalse
    }
}

Describe 'Move-IntoLinked' {
    BeforeEach {
        $live = Join-Path $TestDrive "live $(New-Guid)"
        $linked = Join-Path $TestDrive "linked $(New-Guid)"
        New-Item -ItemType Directory "$live\sub", "$linked\sub" | Out-Null
        Set-Content "$live\tracked.txt" 'same'
        Set-Content "$linked\tracked.txt" 'same'
        Set-Content "$live\sub\ignored.log" 'runtime'
        New-Item -ItemType Directory "$live\empty" | Out-Null
    }
    It 'copies files the linked dir lacks, backs up live, and links it' {
        Move-IntoLinked -Live $live -Linked $linked -Now $now | Should -Be 'backed-up'
        Get-Content "$linked\sub\ignored.log" | Should -Be 'runtime'
        Test-Path "$linked\empty" -PathType Container | Should -BeTrue
        (Get-Item $live).LinkType | Should -Be 'SymbolicLink'
        Test-Path "$live.pre-chezmoi-20260927\tracked.txt" | Should -BeTrue
    }
    It 'recreates nested directory links instead of copying through them' {
        $ext = Join-Path $TestDrive "ext $(New-Guid)"
        New-Item -ItemType Directory $ext | Out-Null
        New-Item -ItemType Junction -Path "$live\nested" -Target $ext | Out-Null
        Move-IntoLinked -Live $live -Linked $linked -Now $now | Out-Null
        (Get-Item "$linked\nested").LinkType | Should -Be 'Junction'
        (Get-Item "$linked\nested").Target | Should -Be $ext
    }
    It 'refuses on conflict and changes nothing' {
        Set-Content "$linked\tracked.txt" 'different'
        { Move-IntoLinked -Live $live -Linked $linked -Now $now } | Should -Throw '*tracked.txt*'
        Test-Path "$linked\sub\ignored.log" | Should -BeFalse
        (Get-Item $live).LinkType | Should -BeNullOrEmpty
    }
    It 'reports already-linked' {
        Move-IntoLinked -Live $live -Linked $linked -Now $now | Out-Null
        Move-IntoLinked -Live $live -Linked $linked -Now $now | Should -Be 'already-linked'
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run (in worktree): `pwsh -NoProfile -Command "Invoke-Pester tests -Output Detailed"`
Expected: FAIL — module file not found.

- [ ] **Step 3: Implement `lib/Dotfiles.psm1`**

```powershell
#Requires -Version 7
# Helpers used by chezmoi run_ scripts and cutover. Kept here so they can be
# tested with Pester; run_ scripts import this file from the source working tree.

function Get-Missing {
    [OutputType([string[]])]
    param([string[]] $Wanted = @(), [string[]] $Installed = @())
    $have = [Collections.Generic.HashSet[string]]::new([string[]] @($Installed | Where-Object { $_ }), [StringComparer]::OrdinalIgnoreCase)
    $seen = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    , [string[]] @($Wanted | Where-Object { $_ -and -not $have.Contains($_) -and $seen.Add($_) })
}

function Get-BackupPath {
    param([Parameter(Mandatory)][string] $Path, [datetime] $Now = (Get-Date))
    $base = '{0}.pre-chezmoi-{1:yyyyMMdd}' -f $Path, $Now
    $candidate = $base
    $n = 1
    while (Test-Path -LiteralPath $candidate) { $candidate = "$base-$n"; $n++ }
    $candidate
}

function Set-DirectoryLink {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Path,
        [Parameter(Mandatory)][string] $Target,
        [ValidateSet('Junction', 'SymbolicLink')][string] $Kind = 'Junction',
        [datetime] $Now = (Get-Date)
    )
    $Target = [IO.Path]::GetFullPath($Target).TrimEnd('\')
    if (-not (Test-Path -LiteralPath $Target -PathType Container)) {
        throw "Link target does not exist: $Target"
    }
    $item = Get-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    if ($item -and $item.LinkType) {
        $current = [IO.Path]::GetFullPath(@($item.Target)[0]).TrimEnd('\')
        if ($current -ieq $Target) { return 'unchanged' }
        $item.Delete()   # removes only the link, never the old target's contents
        $result = 'relinked'
    }
    elseif ($item) {
        Move-Item -LiteralPath $Path -Destination (Get-BackupPath -Path $Path -Now $Now)
        $result = 'backed-up'
    }
    else {
        $parent = Split-Path -Parent $Path
        if (-not (Test-Path -LiteralPath $parent)) { New-Item -ItemType Directory -Path $parent -Force | Out-Null }
        $result = 'created'
    }
    New-Item -ItemType $Kind -Path $Path -Target $Target | Out-Null
    $result
}

function Move-IntoLinked {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string] $Live,
        [Parameter(Mandatory)][string] $Linked,
        [datetime] $Now = (Get-Date)
    )
    $liveItem = Get-Item -LiteralPath $Live -Force -ErrorAction Stop
    if ($liveItem.LinkType) { return 'already-linked' }
    $Live = $liveItem.FullName.TrimEnd('\')
    $Linked = [IO.Path]::GetFullPath($Linked).TrimEnd('\')

    # Get-ChildItem does not descend into directory links, so nested links are
    # reported as single items and recreated rather than copied through.
    $items = Get-ChildItem -LiteralPath $Live -Recurse -Force
    $conflicts = foreach ($i in $items) {
        if ($i.PSIsContainer -or $i.LinkType) { continue }
        $dest = Join-Path $Linked ([IO.Path]::GetRelativePath($Live, $i.FullName))
        if ((Test-Path -LiteralPath $dest) -and
            (Get-FileHash -LiteralPath $dest).Hash -ne (Get-FileHash -LiteralPath $i.FullName).Hash) {
            [IO.Path]::GetRelativePath($Live, $i.FullName)
        }
    }
    if ($conflicts) { throw "Live and linked differ; commit or reconcile first: $($conflicts -join ', ')" }

    foreach ($i in $items) {
        $dest = Join-Path $Linked ([IO.Path]::GetRelativePath($Live, $i.FullName))
        if (Test-Path -LiteralPath $dest) { continue }
        if ($i.LinkType) {
            New-Item -ItemType $i.LinkType -Path $dest -Target @($i.Target)[0] | Out-Null
        }
        elseif ($i.PSIsContainer) {
            New-Item -ItemType Directory -Path $dest -Force | Out-Null
        }
        else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            Copy-Item -LiteralPath $i.FullName -Destination $dest
        }
    }
    Set-DirectoryLink -Path $Live -Target $Linked -Kind SymbolicLink -Now $Now
}

Export-ModuleMember -Function Get-Missing, Get-BackupPath, Set-DirectoryLink, Move-IntoLinked
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `pwsh -NoProfile -Command "Invoke-Pester tests -Output Detailed"`
Expected: all tests PASS. If a nested-link test fails because a directory inside a nested link got enumerated, change the loops to skip any item whose path starts with a link's path and re-run.

- [ ] **Step 5: Commit**

```powershell
git add lib tests
git commit -m "chezmoi: add tested link/package helper module"
```

---

### Task 3: Restructure the repo into `linked/` and `home/dot_config/`

**Files:**
- Move: `<linked dir>/**` → `linked/<dir>/**` for `AutoHotKey FlowLauncher yasb komorebi wpm claude psmux yazi nvim`
- Move: every other tracked top-level dir `X/**` → `home/dot_config/X/**`
- Remove from tracking: `chezmoi/chezmoi.toml` (replaced by `.chezmoi.toml.tmpl` in Task 4)
- Modify: `.gitmodules` (submodule path), `.gitignore` (path prefixes)
- Create: `.chezmoiroot`

- [ ] **Step 1: Record the before-state**

```powershell
git ls-files | Measure-Object | % Count   # note N
git ls-files > "$env:TEMP\before-files.txt"
```

- [ ] **Step 2: Move linked dirs (submodule via `git mv` so `.gitmodules` updates)**

```powershell
New-Item -ItemType Directory linked | Out-Null
foreach ($d in 'AutoHotKey','FlowLauncher','yasb','komorebi','wpm','claude','psmux','yazi','nvim') {
    git mv $d "linked/$d"
}
```

- [ ] **Step 3: Move everything else into `home/dot_config/`**

```powershell
New-Item -ItemType Directory home/dot_config -Force | Out-Null
$keep = 'linked','home','lib','tests','docs','.gitignore','.gitmodules','README.md'
git ls-files | ForEach-Object { ($_ -split '/')[0] } | Sort-Object -Unique |
    Where-Object { $_ -notin $keep -and $_ -ne 'chezmoi' } |
    ForEach-Object { git mv $_ "home/dot_config/$_" }
git rm --cached -r chezmoi
Set-Content -NoNewline .chezmoiroot 'home'
```

- [ ] **Step 4: Rewrite `.gitignore` paths**

Prefix each existing rule with its new location: rules for the 9 linked dirs get `linked/`, the rest get `home/dot_config/`. Replace `chezmoi/chezmoistate.boltdb` with nothing (chezmoi dir no longer in repo). Add at the top:

```gitignore
# --- chezmoi source repo ---
# secrets written at apply time into linked dirs; never commit
linked/FlowLauncher/Settings/Plugins/Github Quick Launcher/
```

Keep every existing exclusion (gnupg, github-copilot, docker, gh/hosts.yml, claude allowlist, runtime noise). The claude allowlist becomes `linked/claude/*` + `!linked/claude/settings.json` etc.

- [ ] **Step 5: Verify nothing was lost and ignores still hold**

```powershell
git add -A
git status --short | Select-String -NotMatch '^R '  # expect only: M .gitignore, M .gitmodules, A .chezmoiroot, D chezmoi/chezmoi.toml
(git ls-files | Measure-Object).Count             # expect N (one file removed, one added)
git submodule status                              # expect linked/AutoHotKey/Lib/KeyChord
git check-ignore -v "linked/claude/.credentials.json" "home/dot_config/gh/hosts.yml" "linked/yasb/x.log"
```
Expected: each path reported as ignored by the rewritten rule.

- [ ] **Step 6: Commit**

```powershell
git add -A
git commit -m "chezmoi: move tracked config into linked/ and home/dot_config/"
```

---

### Task 4: chezmoi config template, symlink entries, ignore file

**Files:**
- Create: `home/.chezmoi.toml.tmpl`
- Create: `home/dot_config/symlink_<name>.tmpl` × 9 (Task 5 adds `powershell`)
- Create: `home/.chezmoiignore`

**Interfaces:**
- Produces template data: `.name`, `.email`, `.signingkey`, `.documents` (home-relative, forward slashes, e.g. `OneDrive/Documents`).

- [ ] **Step 1: Write `home/.chezmoi.toml.tmpl`**

```
{{- $docs := output "pwsh" "-NoProfile" "-Command" "[Environment]::GetFolderPath('MyDocuments')" | trim | replace "\\" "/" -}}
{{- $home := .chezmoi.homeDir | replace "\\" "/" -}}
{{- $docsRel := $docs | trimPrefix (printf "%s/" $home) -}}
[data]
    name = "Randy W. Sims"
    email = "simsrw73@gmail.com"
    signingkey = "8FDC1EB03BECE139"
    documents = {{ $docsRel | quote }}

[bitwarden]
    unlock = "auto"

[cd]
    command = "pwsh"

[git]
    autoAdd = true
```

Note: bootstrap installs PowerShell 7 before `chezmoi init`; `pwsh` is on PATH there.

- [ ] **Step 2: Write the 9 symlink entries**

For each `$n` in `AutoHotKey FlowLauncher yasb komorebi wpm claude psmux yazi nvim`, create `home/dot_config/symlink_$n.tmpl` with exactly:

```
{{ joinPath .chezmoi.workingTree "linked" "NAME" | replace "/" "\\" }}
```

(with `NAME` replaced). Script it:

```powershell
foreach ($n in 'AutoHotKey','FlowLauncher','yasb','komorebi','wpm','claude','psmux','yazi','nvim') {
    Set-Content -NoNewline "home/dot_config/symlink_$n.tmpl" ('{{ joinPath .chezmoi.workingTree "linked" "' + $n + '" | replace "/" "\\" }}')
}
```

- [ ] **Step 3: Write `home/.chezmoiignore`**

```
README.md
{{ if ne .documents "OneDrive/Documents" }}
OneDrive/Documents/**
{{ end }}
{{ if ne .documents "Documents" }}
Documents/**
{{ end }}
```

- [ ] **Step 4: Initialize chezmoi against the worktree (config only, no apply)**

```powershell
$src = "$HOME\projects\dotfiles-chezmoi"
Copy-Item "$HOME\.config\chezmoi\chezmoi.toml" "$HOME\dotfiles-backup-2026-09-27\chezmoi.toml.orig"
chezmoi init --source $src
chezmoi --source $src data --format json | ConvertFrom-Json | Select-Object documents, signingkey
```
Expected: `documents = OneDrive/Documents`, `signingkey = 8FDC1EB03BECE139`.

- [ ] **Step 5: Verify symlink targets render as absolute Windows paths**

Run: `chezmoi --source $src cat ~/.config/yasb`
Expected: `C:\Users\simsr\projects\dotfiles-chezmoi\linked\yasb` (during development it points at the worktree; after cutover it will point at `~\.local\share\chezmoi\linked\yasb`).

- [ ] **Step 6: Verify managed set**

Run: `chezmoi --source $src managed --include=symlinks`
Expected: the 9 `.config/<name>` entries.

- [ ] **Step 7: Commit**

```powershell
git add home
git commit -m "chezmoi: config template, ~/.config symlinks, ignore rules"
```

---

### Task 5: Fold in the PowerShell profile

**Files:**
- Import (with history): `powershell-profile` repo → `linked/powershell/`
- Modify: `linked/powershell/profile.ps1` (profile root)
- Delete: `linked/powershell/CreateSecrets.ps1`
- Create: `home/dot_config/symlink_powershell.tmpl`
- Create: `home/.chezmoitemplates/pwsh-profile-allhosts`, `home/.chezmoitemplates/pwsh-profile-console`
- Create: `home/OneDrive/Documents/PowerShell/profile.ps1.tmpl`, `home/OneDrive/Documents/PowerShell/Microsoft.PowerShell_profile.ps1.tmpl`, `home/OneDrive/Documents/PowerShell/powershell.config.json`
- Create: same three under `home/Documents/PowerShell/` (local-Documents machines)

- [ ] **Step 1: Import with history via git-filter-repo**

```powershell
$tmp = "$env:TEMP\pwsh-import"
git clone "$HOME\OneDrive\Documents\PowerShell" $tmp
git -C $tmp filter-repo --to-subdirectory-filter linked/powershell --force
git remote add pwsh-import $tmp
git fetch pwsh-import
git merge --allow-unrelated-histories -m "chezmoi: import powershell-profile history into linked/powershell" pwsh-import/master
git remote remove pwsh-import
```
(If the branch is `main`, use `pwsh-import/main`; check with `git -C $tmp branch --show-current`.)

- [ ] **Step 2: Drop ignored-by-decision files and fix the profile root**

```powershell
git rm linked/powershell/CreateSecrets.ps1
```
In `linked/powershell/profile.ps1` replace:
```powershell
$profileRoot = Split-Path -Parent $PROFILE
```
with:
```powershell
# Real profile lives in ~/.config/powershell; $PROFILE is only a stub that dot-sources this file.
$profileRoot = $PSScriptRoot
```

Move the profile repo's `.gitignore` rules into the root `.gitignore` under `linked/powershell/` (Modules/, Scripts/, PowerShell.Transcripts/, .claude/settings.local.json, Help/, .examples/), then `git rm linked/powershell/.gitignore`.

- [ ] **Step 3: Stubs**

`home/.chezmoitemplates/pwsh-profile-allhosts`:
```powershell
# Managed by chezmoi. Real profile: ~/.config/powershell/profile.ps1
. (Join-Path $HOME '.config/powershell/profile.ps1')
```
`home/.chezmoitemplates/pwsh-profile-console`:
```powershell
# Managed by chezmoi. Real profile: ~/.config/powershell/Microsoft.PowerShell_profile.ps1
. (Join-Path $HOME '.config/powershell/Microsoft.PowerShell_profile.ps1')
```
For each of `home/OneDrive/Documents/PowerShell/` and `home/Documents/PowerShell/`:
- `profile.ps1.tmpl` → `{{ template "pwsh-profile-allhosts" . }}`
- `Microsoft.PowerShell_profile.ps1.tmpl` → `{{ template "pwsh-profile-console" . }}`
- `powershell.config.json` → copy of `linked/powershell/powershell.config.json` (pwsh reads it only from the Documents folder), then `git rm linked/powershell/powershell.config.json`.

`home/dot_config/symlink_powershell.tmpl`:
```
{{ joinPath .chezmoi.workingTree "linked" "powershell" | replace "/" "\\" }}
```

- [ ] **Step 4: Verify the real profile loads from its new home**

Run: `pwsh -NoLogo -Command ". '$HOME\projects\dotfiles-chezmoi\linked\powershell\profile.ps1'; Get-Command Write-ProfileMsg | % Name"`
Expected: `Write-ProfileMsg`, no errors about ProfileModules paths.

- [ ] **Step 5: Verify stub targets on this machine**

Run: `chezmoi --source $src managed | Select-String PowerShell`
Expected: `OneDrive/Documents/PowerShell/{profile.ps1,Microsoft.PowerShell_profile.ps1,powershell.config.json}` only; nothing under `Documents/PowerShell`.

- [ ] **Step 6: Review Focus #4 — local Documents**

Run: `chezmoi --source $src managed --override-data '{"documents":"Documents"}' | Select-String PowerShell`
Expected: only `Documents/PowerShell/...` entries.

- [ ] **Step 7: Commit**

```powershell
git add -A
git commit -m "chezmoi: PowerShell profile in linked/powershell with Documents stubs"
```

---

### Task 6: Links script and DotForge external

**Files:**
- Create: `home/.chezmoidata/links.yaml`
- Create: `home/.chezmoiscripts/run_onchange_after_10-links.ps1.tmpl`
- Create: `home/.chezmoiexternal.toml.tmpl`

**Interfaces:**
- Consumes: `Set-DirectoryLink` (Task 2), `.documents` (Task 4).

- [ ] **Step 1: `home/.chezmoiexternal.toml.tmpl`**

```toml
["projects/DotForge"]
    type = "git-repo"
    url = "https://github.com/simsrw73/DotForge.git"
    refreshPeriod = "168h"
```

- [ ] **Step 2: `home/.chezmoidata/links.yaml`** (paths are home-relative or env-prefixed; `{docs}` is replaced with `.documents`)

```yaml
links:
  - path: "%APPDATA%/FlowLauncher"
    target: "~/.config/FlowLauncher"
  - path: "~/{docs}/AutoHotkey"
    target: "~/.config/AutoHotKey"
  - path: "%APPDATA%/Zed"
    target: "~/.config/zed"
  - path: "%LOCALAPPDATA%/Zed"
    target: "~/.local/share/zed"
  - path: "~/{docs}/PowerShell/Modules/DotForge"
    target: "~/projects/DotForge"
```

- [ ] **Step 3: `home/.chezmoiscripts/run_onchange_after_10-links.ps1.tmpl`**

```powershell
# links.yaml hash: {{ .links | toJson | sha256sum }}
$ErrorActionPreference = 'Stop'
Import-Module '{{ joinPath .chezmoi.workingTree "lib" "Dotfiles.psm1" }}' -Force

function Resolve-LinkPath([string] $p) {
    $p = $p.Replace('{docs}', '{{ .documents }}')
    if ($p.StartsWith('~/')) { $p = Join-Path $HOME $p.Substring(2) }
    [Environment]::ExpandEnvironmentVariables($p).Replace('/', '\')
}

$links = @(
{{- range .links }}
    @{ Path = '{{ .path }}'; Target = '{{ .target }}' }
{{- end }}
)
foreach ($l in $links) {
    $path = Resolve-LinkPath $l.Path
    $target = Resolve-LinkPath $l.Target
    if (-not (Test-Path -LiteralPath $target)) { New-Item -ItemType Directory -Force $target | Out-Null }
    $r = Set-DirectoryLink -Path $path -Target $target -Kind Junction
    Write-Host "link $path -> $target : $r"
}
```

- [ ] **Step 4: Verify rendering (no apply)**

Run: `chezmoi --source $src execute-template < home/.chezmoiscripts/run_onchange_after_10-links.ps1.tmpl`
Expected: valid PowerShell; `{docs}` resolves via `OneDrive/Documents`; module path points at the worktree `lib\Dotfiles.psm1`.

- [ ] **Step 5: Verify against the live machine without changing it**

Paste the rendered script into a scratch file, replace `Set-DirectoryLink ...` with `Get-Item -Force $path | Select FullName, LinkType, Target`, and run it.
Expected: FlowLauncher and AutoHotkey show existing junctions to the same targets (→ `unchanged` at apply), DotForge shows a symlink to `~/projects/DotForge` (→ `unchanged`), Zed shows its current state (report to the user; real folders will be backed up at apply).

- [ ] **Step 6: Commit**

```powershell
git add home
git commit -m "chezmoi: junctions from links.yaml and DotForge external"
```

---

### Task 7: Home dotfiles, SSH public config, user env vars

**Files:**
- Create: `home/dot_bashrc`, `home/dot_bash_profile` (copies of `~/.bashrc`, `~/.bash_profile`)
- Create: `home/private_dot_ssh/config`, `home/private_dot_ssh/<name>.pub` × 4
- Create: `home/.chezmoiscripts/run_onchange_before_05-user-env.ps1.tmpl`
- Modify: `home/.chezmoiignore`

- [ ] **Step 1: Copy files**

```powershell
Copy-Item ~/.bashrc home/dot_bashrc
Copy-Item ~/.bash_profile home/dot_bash_profile
New-Item -ItemType Directory home/private_dot_ssh -Force | Out-Null
Copy-Item ~/.ssh/config home/private_dot_ssh/config
Get-ChildItem ~/.ssh/*.pub | Copy-Item -Destination home/private_dot_ssh/
```

- [ ] **Step 2: Don't manage `known_hosts`** — append to `home/.chezmoiignore`:

```
.ssh/known_hosts
.ssh/known_hosts.old
```

- [ ] **Step 3: `run_onchange_before_05-user-env.ps1.tmpl`**

```powershell
# Persistent user env vars apps need before first launch.
$ErrorActionPreference = 'Stop'
$vars = [ordered]@{
    SCOOP                = Join-Path $HOME '.local\share\scoop'
    KOMOREBI_CONFIG_HOME = Join-Path $HOME '.config\komorebi'
}
foreach ($k in $vars.Keys) {
    if ([Environment]::GetEnvironmentVariable($k, 'User') -ne $vars[$k]) {
        [Environment]::SetEnvironmentVariable($k, $vars[$k], 'User')
        Write-Host "set $k=$($vars[$k])"
    }
    Set-Item "env:$k" $vars[$k]
}
```

- [ ] **Step 4: Verify**

Run: `chezmoi --source $src diff ~/.bashrc ~/.bash_profile ~/.ssh/config`
Expected: no output (identical). Run: `chezmoi --source $src managed | Select-String '\.ssh'` → config + 4 `.pub`, no `known_hosts`.

- [ ] **Step 5: Commit**

```powershell
git add home
git commit -m "chezmoi: bash dotfiles, ssh public config, user env vars"
```

---

### Task 8: Secrets from Bitwarden

**Files:**
- Create: `scripts/seed-bitwarden.ps1`
- Create: `home/private_dot_ssh/private_<key>.tmpl` × 4 (`id_ed25519`, `id_a24`, `private_key`, `routeros_rsa`)
- Create: `home/private_dot_env.tmpl`
- Create: `home/.chezmoiscripts/run_onchange_after_15-flow-github-token.ps1.tmpl`
- Create: `home/.chezmoiscripts/run_onchange_after_30-gpg-import.ps1.tmpl`
- Create: `home/.chezmoiscripts/run_onchange_after_35-ssh-acl.ps1.tmpl`

- [ ] **Step 1: Install bw and confirm key list**

```powershell
scoop install bitwarden-cli
Get-ChildItem ~/.ssh -File | Where-Object { $_.Name -notmatch '\.pub$|^config$|^known_hosts' } | % Name
```
Expected: `id_a24 id_ed25519 private_key routeros_rsa` (4 keys; the spec's "5" was a miscount). If the list differs, stop and confirm with the user, then use the real list everywhere below.

- [ ] **Step 2: Write `scripts/seed-bitwarden.ps1`** (user runs it; creates or updates items in folder `dotfiles`)

```powershell
#Requires -Version 7
<#
Creates the Bitwarden items chezmoi templates read. Run while `bw` is logged in:
    $env:BW_SESSION = bw unlock --raw
    ./scripts/seed-bitwarden.ps1
Secret values go straight from local files into bw; nothing is printed.
#>
$ErrorActionPreference = 'Stop'
if (-not $env:BW_SESSION) { throw 'Set $env:BW_SESSION = (bw unlock --raw) first.' }
bw sync | Out-Null

function Get-FolderId([string] $name) {
    $f = bw list folders --search $name | ConvertFrom-Json | Where-Object name -eq $name
    if ($f) { return $f.id }
    ((@{ name = $name } | ConvertTo-Json -Compress) | bw encode | bw create folder | ConvertFrom-Json).id
}
function Get-Item-ByName([string] $name) {
    bw list items --search $name | ConvertFrom-Json | Where-Object name -eq $name | Select-Object -First 1
}
function New-SecureNote([string] $name, [string] $folderId, $fields = @()) {
    $item = bw get template item | ConvertFrom-Json
    $item.type = 2; $item.name = $name; $item.folderId = $folderId
    $item.secureNote = @{ type = 0 }; $item.notes = 'Managed for chezmoi (dotfiles-windows).'
    $item.fields = @($fields)
    ($item | ConvertTo-Json -Depth 5 -Compress) | bw encode | bw create item | ConvertFrom-Json
}
function Set-Attachment($item, [string] $file) {
    $leaf = Split-Path -Leaf $file
    $old = $item.attachments | Where-Object fileName -eq $leaf
    foreach ($a in $old) { bw delete attachment $a.id --itemid $item.id | Out-Null }
    bw create attachment --file $file --itemid $item.id | Out-Null
    Write-Host "  attached $leaf"
}

$folder = Get-FolderId 'dotfiles'

# ssh-keys
$ssh = Get-Item-ByName 'ssh-keys'
if (-not $ssh) { $ssh = New-SecureNote 'ssh-keys' $folder }
Write-Host 'ssh-keys'
foreach ($k in 'id_ed25519', 'id_a24', 'private_key', 'routeros_rsa') { Set-Attachment $ssh (Join-Path $HOME ".ssh\$k") }

# gpg-signing-key
$gpgExe = git config --get gpg.program; if (-not $gpgExe) { $gpgExe = 'gpg' }
$tmp = New-Item -ItemType Directory (Join-Path $env:TEMP "bwseed-$(New-Guid)")
try {
    & $gpgExe --export-secret-keys --armor 8FDC1EB03BECE139 | Set-Content -NoNewline "$tmp\signing-key.asc"
    & $gpgExe --export-ownertrust | Set-Content "$tmp\ownertrust.txt"
    if ((Get-Item "$tmp\signing-key.asc").Length -lt 1000) { throw 'gpg export looks empty; check the passphrase prompt.' }
    $gpg = Get-Item-ByName 'gpg-signing-key'
    if (-not $gpg) { $gpg = New-SecureNote 'gpg-signing-key' $folder }
    Write-Host 'gpg-signing-key'
    Set-Attachment $gpg "$tmp\signing-key.asc"
    Set-Attachment $gpg "$tmp\ownertrust.txt"
}
finally { Remove-Item -Recurse -Force $tmp }

# env (hidden fields, one per ~/.env variable)
$fields = Get-Content (Join-Path $HOME '.env') | Where-Object { $_ -match '^\s*[A-Za-z_][A-Za-z0-9_]*=' } | ForEach-Object {
    $n, $v = $_ -split '=', 2
    @{ name = $n.Trim(); value = $v.Trim().Trim('"'); type = 1 }
}
if (-not (Get-Item-ByName 'env')) { New-SecureNote 'env' $folder $fields | Out-Null; Write-Host "env ($($fields.Count) fields)" }
else { Write-Host 'env exists; edit fields in Bitwarden if they changed' }

# flow-github
$flowFile = Join-Path $HOME '.config\FlowLauncher\Settings\Plugins\Github Quick Launcher\Settings.json'
if (-not (Get-Item-ByName 'flow-github')) {
    $f = New-SecureNote 'flow-github' $folder
    Set-Attachment $f $flowFile
    Write-Host 'flow-github'
}
bw sync | Out-Null
Write-Host 'done'
```

(FlowLauncher's settings file is stored whole as an attachment: its token field name isn't known, and restoring the whole file avoids guessing.)

- [ ] **Step 3: User runs the seed script**

Ask the user to run:
```
! $env:BW_SESSION = bw unlock --raw; pwsh -File C:/Users/simsr/projects/dotfiles-chezmoi/scripts/seed-bitwarden.ps1
```
(`bw login` first if needed.) Wait for `done`.

- [ ] **Step 4: Secret templates**

For each key `K` in the list, `home/private_dot_ssh/private_K.tmpl`:
```
{{- bitwardenAttachment "K" (bitwarden "item" "ssh-keys").id -}}
```

`home/private_dot_env.tmpl`:
```
{{- $f := bitwardenFields "item" "env" -}}
{{- range $name, $field := $f }}
{{ $name }}={{ $field.value }}
{{- end }}
```

`home/.chezmoiscripts/run_onchange_after_15-flow-github-token.ps1.tmpl`:
```powershell
# flow-github item revision: {{ (bitwarden "item" "flow-github").revisionDate }}
$ErrorActionPreference = 'Stop'
$dir = Join-Path $HOME '.config\FlowLauncher\Settings\Plugins\Github Quick Launcher'
New-Item -ItemType Directory -Force $dir | Out-Null
$content = @'
{{ bitwardenAttachment "Settings.json" (bitwarden "item" "flow-github").id }}
'@
Set-Content -LiteralPath (Join-Path $dir 'Settings.json') -Value $content.TrimEnd("`r", "`n") -NoNewline
```

`home/.chezmoiscripts/run_onchange_after_30-gpg-import.ps1.tmpl`:
```powershell
# gpg-signing-key item revision: {{ (bitwarden "item" "gpg-signing-key").revisionDate }}
$ErrorActionPreference = 'Stop'
$gpg = git config --global --get gpg.program; if (-not $gpg) { $gpg = 'gpg' }
& $gpg --list-secret-keys 8FDC1EB03BECE139 *> $null
if ($LASTEXITCODE -eq 0) { Write-Host 'gpg key already present'; return }
$tmp = New-Item -ItemType Directory (Join-Path $env:TEMP "gpgimp-$(New-Guid)")
try {
    Set-Content -NoNewline "$tmp\k.asc" @'
{{ bitwardenAttachment "signing-key.asc" (bitwarden "item" "gpg-signing-key").id }}
'@
    Set-Content "$tmp\t.txt" @'
{{ bitwardenAttachment "ownertrust.txt" (bitwarden "item" "gpg-signing-key").id }}
'@
    & $gpg --batch --import "$tmp\k.asc"
    & $gpg --import-ownertrust "$tmp\t.txt"
}
finally { Remove-Item -Recurse -Force $tmp }
```

`home/.chezmoiscripts/run_onchange_after_35-ssh-acl.ps1.tmpl`:
```powershell
# keys: {{ (bitwarden "item" "ssh-keys").revisionDate }}
# Windows OpenSSH refuses private keys readable by other users.
$ErrorActionPreference = 'Stop'
foreach ($k in 'id_ed25519', 'id_a24', 'private_key', 'routeros_rsa') {
    $p = Join-Path $HOME ".ssh\$k"
    if (Test-Path $p) { icacls $p /inheritance:r /grant:r "${env:USERNAME}:(R,W)" | Out-Null }
}
```

- [ ] **Step 5: Verify templates match current files (hashes only, never values)**

```powershell
foreach ($t in '.ssh/id_ed25519','.ssh/id_a24','.ssh/private_key','.ssh/routeros_rsa','.env') {
    chezmoi --source $src diff "~/$t" | Measure-Object -Line | % { "$t diff lines: $($_.Lines)" }
}
```
Expected: `diff lines: 0` for each. (If `.env` differs only in ordering/quoting, rewrite `~/.env` from the template after the user confirms — values are identical.)

- [ ] **Step 6: Verify scripts render**

Run: `chezmoi --source $src execute-template < home/.chezmoiscripts/run_onchange_after_30-gpg-import.ps1.tmpl | Select-String -Pattern 'BEGIN PGP PRIVATE KEY BLOCK' -Quiet`
Expected: `True` (output not printed).

- [ ] **Step 7: Review Focus #3 — missing item / locked vault fails loudly**

```powershell
'{{ (bitwarden "item" "no-such-item-xyz").id }}' | chezmoi --source $src execute-template; "exit=$LASTEXITCODE"
```
Expected: an error and `exit=1`. Then `bw lock` and run `chezmoi --source $src cat ~/.ssh/id_ed25519 > $null; "exit=$LASTEXITCODE"` → it prompts for the master password (unlock = auto); cancel with Ctrl+C → non-zero exit, no file written. User performs this step.

- [ ] **Step 8: Commit**

```powershell
git add scripts home
git commit -m "chezmoi: secrets from Bitwarden (ssh, gpg, env, FlowLauncher token)"
```

---

### Task 9: Package lists and installer

**Files:**
- Create: `scripts/draft-packages.ps1`
- Create: `home/.chezmoidata/packages.yaml`
- Create: `home/.chezmoiscripts/run_onchange_before_20-packages.ps1.tmpl`

**Interfaces:**
- Consumes: `Get-Missing` (Task 2).
- Produces data: `.packages.scoop.buckets[] {name, url?}`, `.packages.scoop.apps[]`, `.packages.winget.user[]`, `.packages.winget.elevated[]`, `.packages.pwsh[]`.

- [ ] **Step 1: `scripts/draft-packages.ps1`** — writes a draft for the user to prune

```powershell
#Requires -Version 7
$ErrorActionPreference = 'Stop'
$out = Join-Path $PSScriptRoot '..\home\.chezmoidata\packages.yaml'
$buckets = scoop bucket list | ForEach-Object { [pscustomobject]@{ name = $_.Name; url = $_.Source } }
$scoopApps = (scoop export | ConvertFrom-Json).apps | ForEach-Object { if ($_.Source -in 'main','extras') { $_.Name } else { "$($_.Source)/$($_.Name)" } }
$wingetJson = Join-Path $env:TEMP 'winget-export.json'
winget export -o $wingetJson --source winget --accept-source-agreements | Out-Null
$winget = (Get-Content $wingetJson | ConvertFrom-Json).Sources[0].Packages.PackageIdentifier
$builtIn = 'PackageManagement','PowerShellGet','PSReadLine','DotForge','Microsoft.PowerShell.SecretManagement','Microsoft.PowerShell.SecretStore','Microsoft.PowerToys.Configure'
$docs = [Environment]::GetFolderPath('MyDocuments')
$mods = Get-ChildItem (Join-Path $docs 'PowerShell\Modules') -Directory | % Name | Where-Object { $_ -notin $builtIn }
$lines = @('packages:', '  scoop:', '    buckets:')
$lines += $buckets | ForEach-Object { "      - name: $($_.name)"; if ($_.url -and $_.name -notin 'main','extras','nirsoft') { "        url: $($_.url)" } }
$lines += '    apps:'; $lines += $scoopApps | Sort-Object | ForEach-Object { "      - $_" }
$lines += '  winget:', '    user:'; $lines += $winget | Sort-Object | ForEach-Object { "      - $_" }
$lines += '    elevated: []', '  pwsh:'; $lines += $mods | Sort-Object | ForEach-Object { "    - $_" }
Set-Content $out $lines
Write-Host "draft written: $out"
```

- [ ] **Step 2: Run it, then hand the draft to the user to prune**

Run: `pwsh -NoProfile -File scripts/draft-packages.ps1`
Then tell the user: prune `home/.chezmoidata/packages.yaml`; move admin-scope installers (e.g. `LGUG2Z.komorebi`, `LGUG2Z.whkd`, `AmN.yasb`) from `winget.user` to `winget.elevated`; drop anything they don't want on the next install. Also: add `gitleaks` to scoop apps; make sure `bitwarden-cli`, `gsudo`, `git`, `gh` are present. **Wait for the user to say the list is done.**

- [ ] **Step 3: Check PowerShell modules exist on the Gallery**

Run: `pwsh -NoProfile -Command "(Get-Content home/.chezmoidata/packages.yaml) -match '^    - ' | % { \$n = \$_.Trim('- ').Trim(); if (-not (Find-PSResource \$n -ErrorAction SilentlyContinue)) { \"NOT ON GALLERY: \$n\" } }"`
Expected: no output. Report any listed module to the user (it's local/custom and must be dropped or handled another way).

- [ ] **Step 4: `run_onchange_before_20-packages.ps1.tmpl`**

```powershell
# packages hash: {{ .packages | toJson | sha256sum }}
$ErrorActionPreference = 'Stop'
Import-Module '{{ joinPath .chezmoi.workingTree "lib" "Dotfiles.psm1" }}' -Force

# --- scoop
if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) { throw 'scoop missing: run bootstrap.ps1 first' }
$haveBuckets = @(scoop bucket list | % Name)
{{- range .packages.scoop.buckets }}
if ('{{ .name }}' -notin $haveBuckets) { scoop bucket add '{{ .name }}' {{ if .url }}'{{ .url }}'{{ end }} }
{{- end }}
$wantScoop = @({{ range $i, $a := .packages.scoop.apps }}{{ if $i }}, {{ end }}'{{ $a }}'{{ end }})
$haveScoop = @((scoop export | ConvertFrom-Json).apps | % Name)
$missing = Get-Missing -Wanted ($wantScoop | % { ($_ -split '/')[-1] }) -Installed $haveScoop
foreach ($m in $missing) { scoop install ($wantScoop | Where-Object { ($_ -split '/')[-1] -ieq $m } | Select-Object -First 1) }

# --- winget
if (Get-Command winget -ErrorAction SilentlyContinue) {
    $haveWinget = @(winget list --source winget --accept-source-agreements --disable-interactivity |
        Select-String -Pattern '\s([A-Za-z0-9][\w.+-]*\.[\w.+-]+)\s' -AllMatches | % { $_.Matches } | % { $_.Groups[1].Value })
    foreach ($id in (Get-Missing -Wanted @({{ range $i, $a := .packages.winget.user }}{{ if $i }}, {{ end }}'{{ $a }}'{{ end }}) -Installed $haveWinget)) {
        winget install --id $id -e --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
    }
    $elev = Get-Missing -Wanted @({{ range $i, $a := .packages.winget.elevated }}{{ if $i }}, {{ end }}'{{ $a }}'{{ end }}) -Installed $haveWinget
    if ($elev) {
        $cmds = ($elev | % { "winget install --id $_ -e --source winget --scope machine --accept-package-agreements --accept-source-agreements --disable-interactivity" }) -join '; '
        gsudo pwsh -NoProfile -Command $cmds
    }
}
else { Write-Warning 'winget not found; skipping winget packages (install App Installer and re-run chezmoi apply)' }

# --- PowerShell modules
$haveMods = @(Get-InstalledPSResource -ErrorAction SilentlyContinue | % Name)
foreach ($m in (Get-Missing -Wanted @({{ range $i, $a := .packages.pwsh }}{{ if $i }}, {{ end }}'{{ $a }}'{{ end }}) -Installed $haveMods)) {
    Install-PSResource -Name $m -Scope CurrentUser -TrustRepository -Quiet
}
```

- [ ] **Step 5: Verify it renders and would install nothing on this machine**

```powershell
chezmoi --source $src execute-template < home/.chezmoiscripts/run_onchange_before_20-packages.ps1.tmpl > "$env:TEMP\pkgs.ps1"
(Get-Content "$env:TEMP\pkgs.ps1") -replace '^(\s*)(scoop install|scoop bucket add|winget install|gsudo|Install-PSResource)', '$1Write-Host WOULD: $2' | Set-Content "$env:TEMP\pkgs-dry.ps1"
pwsh -NoProfile -File "$env:TEMP\pkgs-dry.ps1"
```
Expected: no `WOULD:` lines (everything listed is already installed). Any `WOULD:` line means a name mismatch in the list or the winget-list parser — fix and re-run.

- [ ] **Step 6: Commit**

```powershell
git add scripts home
git commit -m "chezmoi: curated package lists and run_onchange installer"
```

---

### Task 10: One-time setup, secret-scan hook, bootstrap, README

**Files:**
- Create: `home/.chezmoiscripts/run_once_after_40-wpmd-task.ps1.tmpl`
- Create: `.githooks/pre-commit`
- Create: `bootstrap.ps1`
- Modify: `README.md`

- [ ] **Step 1: wpmd task (reuses existing script)**

`run_once_after_40-wpmd-task.ps1.tmpl`:
```powershell
$ErrorActionPreference = 'Stop'
& '{{ joinPath .chezmoi.workingTree "linked" "wpm" "install-wpmd-task.ps1" }}'
```

- [ ] **Step 2: pre-commit hook**

`.githooks/pre-commit`:
```sh
#!/bin/sh
# Block commits containing secrets.
command -v gitleaks >/dev/null 2>&1 || { echo "pre-commit: gitleaks not installed (scoop install gitleaks)" >&2; exit 1; }
exec gitleaks git --pre-commit --staged --redact --no-banner
```
Then: `git config core.hooksPath .githooks` (in the worktree; bootstrap sets it on new clones).

- [ ] **Step 3: Verify hook blocks a fake secret**

```powershell
scoop install gitleaks
Set-Content leak-test.txt 'ghp_0123456789abcdefghijklmnopqrstuvwxyzAB'
git add leak-test.txt; git commit -m test; "exit=$LASTEXITCODE"
git rm --cached leak-test.txt; Remove-Item leak-test.txt
```
Expected: gitleaks reports a finding, `exit=1`, no commit created.

- [ ] **Step 4: `bootstrap.ps1`**

```powershell
<#
Fresh-machine setup. From Windows PowerShell or pwsh:
    irm https://raw.githubusercontent.com/simsrw73/dotfiles-windows/main/bootstrap.ps1 | iex
(The repo is private: download this file via the GitHub web UI, or run it from a clone.)
#>
$ErrorActionPreference = 'Stop'
$env:SCOOP = Join-Path $HOME '.local\share\scoop'
[Environment]::SetEnvironmentVariable('SCOOP', $env:SCOOP, 'User')

if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
    Set-ExecutionPolicy -Scope CurrentUser RemoteSigned -Force
    Invoke-RestMethod get.scoop.sh | Invoke-Expression
}
scoop install git
scoop bucket add extras
scoop install pwsh chezmoi bitwarden-cli gsudo gh gitleaks

if ((gh auth status 2>&1) -match 'not logged') { gh auth login --hostname github.com --git-protocol https --web }
gh auth setup-git

$status = bw status | ConvertFrom-Json
if ($status.status -eq 'unauthenticated') { bw login }

$src = Join-Path $HOME '.local\share\chezmoi'
chezmoi init https://github.com/simsrw73/dotfiles-windows.git --source $src
git -C $src config core.hooksPath .githooks
pwsh -NoProfile -Command "chezmoi apply -v"
Write-Host 'Done. Sign out and back in (env vars, wpmd task), then open a new terminal.'
```

- [ ] **Step 5: README**

Replace `README.md` with sections: **What this is** (one paragraph), **Fresh machine** (`bootstrap.ps1` steps above), **Daily use** (edit files in linked folders directly → `chezmoi cd`, `git status/commit/push`; for copied files `chezmoi edit <file>` or edit then `chezmoi re-add`; `chezmoi diff` before `apply`), **Add an app** (edit `home/.chezmoidata/packages.yaml`, `chezmoi apply`), **Add a secret** (add a field/attachment in the Bitwarden `dotfiles` folder, reference it in a template), **Add a linked folder** (move into `linked/`, add `symlink_<name>.tmpl`), **Pre-wipe checklist** (`chezmoi status` clean; `git -C (chezmoi source-path)/.. status` clean and pushed; Bitwarden items `ssh-keys`, `gpg-signing-key`, `env`, `flow-github` present; `~/dotfiles-backup-*` copied to offline media; list of things restored by re-login: gh, Claude, Copilot, Docker, OneDrive).

- [ ] **Step 6: Commit**

```powershell
git add .githooks bootstrap.ps1 README.md home
git commit -m "chezmoi: bootstrap, wpmd run_once, gitleaks hook, README"
```

---

### Task 11: Dry run against the real home directory

**Files:** none (review only; fixes go into earlier tasks' files).

- [ ] **Step 1: Full diff**

Run: `chezmoi --source $src diff --exclude=scripts > "$env:TEMP\chezmoi-dryrun.diff"; chezmoi --source $src status --exclude=scripts`
Expected differences only:
- `.config/<10 linked names>`: directory → symlink
- `OneDrive/Documents/PowerShell/profile.ps1` and `Microsoft.PowerShell_profile.ps1`: real profile → stub
- `.ssh` keys ACL-only (no content diff)

- [ ] **Step 2: Walk the user through every other line** in `chezmoi status`. For each: fix the source (Tasks 3–9) or accept it. Line-ending-only differences: check with `git diff --no-index --ignore-cr-at-eol <live> <source>`; if identical except EOL, add `* -text` to a root `.gitattributes`, run `git add --renormalize .`, and re-check.

- [ ] **Step 3: Check the script plan**

Run: `chezmoi --source $src status --include=scripts`
Expected: `R` for `05-user-env`, `10-links`, `15-flow-github-token`, `20-packages`, `30-gpg-import`, `35-ssh-acl`, `40-wpmd-task`. Confirm with the user that each is safe to run on this machine (packages: dry-run from Task 9 showed no installs; links: Task 6 Step 5; gpg: skips because key present; wpmd: `install-wpmd-task.ps1` must be idempotent — read it and confirm, else guard with `Get-ScheduledTask`).

- [ ] **Step 4: Commit any fixes**, then push the branch:

```powershell
git push -u origin chezmoi
```

---

### Task 12: Cutover (user-driven; Claude Code must be closed for the claude folder)

**Files:**
- Create: `scripts/cutover.ps1`

- [ ] **Step 1: Write `scripts/cutover.ps1`**

```powershell
#Requires -Version 7
<#
One-time switch from "~/.config is a git repo" to chezmoi. Run from a plain
pwsh window with Claude Code, komorebi, yasb, AHK and FlowLauncher closed.
#>
$ErrorActionPreference = 'Stop'
$cfg = Join-Path $HOME '.config'
$src = Join-Path $HOME '.local\share\chezmoi'
$backup = Join-Path $HOME 'dotfiles-backup-2026-09-27'

if (git -C $cfg status --porcelain) { throw '~/.config has uncommitted changes; commit them on main first.' }
foreach ($p in 'claude', 'komorebi', 'yasb', 'AutoHotkey64', 'Flow.Launcher', 'wpmd') {
    if (Get-Process -Name $p -ErrorAction SilentlyContinue) { throw "Close $p first." }
}
if (-not (Test-Path $src)) {
    git clone --recurse-submodules -b chezmoi https://github.com/simsrw73/dotfiles-windows.git $src
}
git -C $src config core.hooksPath .githooks
Import-Module (Join-Path $src 'lib\Dotfiles.psm1') -Force

# ~/.config stops being a repo
Move-Item (Join-Path $cfg '.git') (Join-Path $backup 'dot-config.git')
foreach ($f in '.gitignore', '.gitmodules', 'README.md') {
    $p = Join-Path $cfg $f; if (Test-Path $p) { Move-Item $p (Join-Path $backup "dot-config$f") }
}

# live folders -> linked/, keeping ignored runtime files
foreach ($n in 'AutoHotKey','FlowLauncher','yasb','komorebi','wpm','claude','psmux','yazi','nvim') {
    $r = Move-IntoLinked -Live (Join-Path $cfg $n) -Linked (Join-Path $src "linked\$n")
    Write-Host "$n : $r"
}
# the profile repo's working tree -> linked/powershell (Modules/Help/Scripts etc. stay in Documents)
Write-Host 'Now run: chezmoi init --source' $src '; chezmoi diff; chezmoi apply -v'
```

Note: `~/.config/powershell` doesn't exist yet, so chezmoi creates that symlink fresh; the old profile files in `OneDrive\Documents\PowerShell` are replaced by stubs at apply (backed up already in the bundle).

- [ ] **Step 2: Commit and push the script**

```powershell
git add scripts/cutover.ps1
git commit -m "chezmoi: cutover script"
git push
```

- [ ] **Step 3: Hand off to the user.** Tell them exactly:
1. Commit pending `~/.config` changes on `main` and push (or ask Claude to do it before closing).
2. Exit Claude Code and stop komorebi/yasb/AHK/FlowLauncher (`wpmctl stop`, `komorebic stop`, tray exit).
3. In a new pwsh window: `pwsh -File ~/projects/dotfiles-chezmoi/scripts/cutover.ps1`
4. `chezmoi init --source ~/.local/share/chezmoi` (rewrites config; accept defaults), then `chezmoi diff` (expect only the stub files and symlink conversions already in place), then `chezmoi apply -v` (Bitwarden prompt appears once).
5. Reopen Claude Code in `~/.local/share/chezmoi` (NOT the worktree: cutover moves `~/.config/.git`, which the worktree depends on, so the worktree stops working) and say "cutover done". Everything from the worktree was pushed in Task 11 and Step 2 above, and the cutover clone pulls it from GitHub.

Wait for the user.

---

### Task 13: Verify on this machine, merge

- [ ] **Step 1: State checks**

```powershell
chezmoi verify; "verify exit=$LASTEXITCODE"
Get-Item ~/.config/yasb, ~/.config/claude, ~/.config/powershell, "$env:APPDATA\FlowLauncher" -Force | Select FullName, LinkType, Target
git -C (Split-Path (chezmoi source-path)) status --short
```
Expected: `verify exit=0`; links point into `~\.local\share\chezmoi\linked\...` (FlowLauncher junction → `~\.config\FlowLauncher`); `git status` clean.

- [ ] **Step 2: Functional checks** (ask the user to reboot first, then confirm): komorebi tiles, yasb bar shows, AHK hotkeys work, FlowLauncher opens with plugins, a new pwsh window loads the profile without errors, `ssh -T git@github.com` authenticates, and a signed commit works: `git -C (chezmoi source-path)/.. commit --allow-empty -S -m "chezmoi: verify signing"` → `git log --show-signature -1` shows `Good signature` from `8FDC1EB03BECE139`.

- [ ] **Step 3: Review Focus #5 — idempotent apply**

Run: `chezmoi apply -v 2>&1 | Tee-Object "$env:TEMP\apply2.txt"; chezmoi status`
Expected: no script output (no `link ... : created/relinked/backed-up`, no installs), `chezmoi status` empty.

- [ ] **Step 4: Merge to main**

```powershell
$repo = Split-Path (chezmoi source-path)
git -C $repo fetch origin
git -C $repo checkout main
git -C $repo merge --ff-only origin/main
git -C $repo merge --no-ff chezmoi -m "Migrate dotfiles to chezmoi"
git -C $repo push origin main
```
Expected: push succeeds. Remote branch `chezmoi` can be deleted after Task 14.

---

### Task 14: Fresh-machine test in Windows Sandbox

**Files:**
- Create: `scripts/sandbox.wsb`

- [ ] **Step 1: Check Sandbox is enabled**

Run: `gsudo pwsh -NoProfile -Command "(Get-WindowsOptionalFeature -Online -FeatureName Containers-DisposableClientVM).State"`
Expected: `Enabled`. If `Disabled`, ask the user before enabling (needs reboot).

- [ ] **Step 2: `scripts/sandbox.wsb`**

```xml
<Configuration>
  <MappedFolders>
    <MappedFolder>
      <HostFolder>C:\Users\simsr\.local\share\chezmoi</HostFolder>
      <SandboxFolder>C:\dotfiles</SandboxFolder>
      <ReadOnly>true</ReadOnly>
    </MappedFolder>
  </MappedFolders>
  <LogonCommand>
    <Command>powershell -NoExit -ExecutionPolicy Bypass -Command "Write-Host 'Run: C:\dotfiles\bootstrap.ps1'"</Command>
  </LogonCommand>
</Configuration>
```

- [ ] **Step 3: User runs the test** — open `scripts/sandbox.wsb`, run `C:\dotfiles\bootstrap.ps1`, sign in to GitHub and Bitwarden when prompted. Pass criteria to check inside the sandbox:
  - `chezmoi status` empty after apply
  - `~/.config/yasb` is a symlink into `~\.local\share\chezmoi\linked\yasb`
  - `~/.ssh/id_ed25519` exists and `ssh-keygen -y -f ~/.ssh/id_ed25519` prints a public key matching `id_ed25519.pub`
  - `gpg --list-secret-keys 8FDC1EB03BECE139` lists the key
  - a new pwsh window loads the profile
  - winget is absent in Sandbox → the warning appears and everything else completes (expected)

- [ ] **Step 4: Fix anything that failed in its owning task's files, commit, push, re-run the sandbox until it passes.**

- [ ] **Step 5: Commit**

```powershell
git add scripts/sandbox.wsb
git commit -m "chezmoi: Windows Sandbox fresh-install test"
git push
```

---

### Task 15: Cleanup and records

- [ ] **Step 1: Ask the user, then** archive `simsrw73/powershell-profile`: `gh repo archive simsrw73/powershell-profile --yes`
- [ ] **Step 2: Ask the user, then** remove the old clone and worktree: `Remove-Item -Recurse -Force ~/projects/dotfiles-windows`. The `~/projects/dotfiles-chezmoi` worktree belonged to the old `~/.config/.git` (now in the backup), so it no longer works as a checkout; everything in it was pushed before cutover. Delete it: `Remove-Item -Recurse -Force ~/projects/dotfiles-chezmoi`.
- [ ] **Step 3:** delete remote branch: `git -C ~/.local/share/chezmoi push origin --delete chezmoi`
- [ ] **Step 4:** Update Claude memory `dotfiles-repo-layout.md`: source repo is `~/.local/share/chezmoi` (`simsrw73/dotfiles-windows`), linked folders list, secrets in Bitwarden folder `dotfiles`, `~/.config` is no longer a git repo, w11dwm-config `sync.ps1` still reads `~/.config` (works through the symlinks). Update the `MEMORY.md` hook line.
- [ ] **Step 5:** Remind the user: move `~/dotfiles-backup-2026-09-27` to offline media (it contains private keys), then delete the local copy.
