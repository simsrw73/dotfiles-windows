Describe 'AutoHotkey watchdog' {
    BeforeAll {
        $watchdog = Join-Path $PSScriptRoot '..\autohotkey-watchdog.ps1'
        . $watchdog -NoRun
    }

    BeforeEach {
        Mock Get-CimInstance { @() }
        Mock Start-Process {}
    }

    It 'accepts replacement PIDs for the same script' {
        Mock Get-CimInstance {
            @(
                [pscustomobject]@{
                    Name = 'AutoHotkey64.exe'
                    ProcessId = 101
                    CommandLine = '"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\simsr\.config\autohotkey\autohotkey.ahk"'
                },
                [pscustomobject]@{
                    Name = 'AutoHotkey64.exe'
                    ProcessId = 202
                    CommandLine = '"C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" "C:\Users\simsr\.config\autohotkey\autohotkey.ahk"'
                }
            )
        }

        (Get-ManagedAutoHotkeyProcess).ProcessId | Should -Be @(101, 202)
    }

    It 'starts immediately when initially absent' {
        (Invoke-AutoHotkeyWatchdogCheck -Initial -DryRun).Action | Should -Be 'start'
    }

    It 'accepts the explicitly null initial missing state used by the loop' {
        $missingSince = $null

        (Invoke-AutoHotkeyWatchdogCheck -MissingSince $missingSince -Initial -DryRun).Action | Should -Be 'start'
    }

    It 'waits during a later missing grace period' {
        (Invoke-AutoHotkeyWatchdogCheck -MissingSince (Get-Date) -DryRun).Action | Should -Be 'wait'
    }
}
