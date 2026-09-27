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
        (Get-Item $live).LinkType | Should -Be 'Junction'
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

Describe 'ConvertFrom-CargoInstallList' {
    It 'returns crate names from `cargo install --list` output, including git installs' {
        $text = @(
            'choose v1.3.7:'
            '    choose.exe'
            'wpmd v0.1.0 (https://github.com/LGUG2Z/wpm#38728307):'
            '    wpmd.exe'
        )
        ConvertFrom-CargoInstallList $text | Should -Be @('choose', 'wpmd')
    }
    It 'returns nothing for empty output' {
        @(ConvertFrom-CargoInstallList @()).Count | Should -Be 0
    }
}

Describe 'ConvertFrom-NameVersionList' {
    It 'reads `pipx list --short` output' {
        ConvertFrom-NameVersionList @('beets 2.13.1', 'rich-cli 1.8.1') | Should -Be @('beets', 'rich-cli')
    }
    It 'reads `uv tool list` output, skipping the executable lines' {
        ConvertFrom-NameVersionList @('pls v6.0.0.post1', '- pls', '- pls-dev', 'pynvim v0.6.0', '- pynvim-python') | Should -Be @('pls', 'pynvim')
    }
    It 'ignores blank lines and messages like "No tools installed"' {
        @(ConvertFrom-NameVersionList @('', 'No tools installed')).Count | Should -Be 0
    }
}
