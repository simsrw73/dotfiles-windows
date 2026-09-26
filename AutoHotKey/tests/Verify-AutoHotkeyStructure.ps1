$ErrorActionPreference = 'Stop'

function Get-SourceText([string]$Path) {
    $lines = Get-Content -LiteralPath $Path | ForEach-Object { $_ -replace ';.*$', '' }
    return $lines -join [Environment]::NewLine
}

function Assert-Contains([string]$Path, [string]$Pattern) {
    $content = Get-SourceText $Path
    if ($content -notmatch [regex]::Escape($Pattern)) {
        throw "Expected '$Path' to contain '$Pattern'."
    }
}

function Assert-NotContains([string]$Path, [string]$Pattern) {
    $content = Get-SourceText $Path
    if ($content -match [regex]::Escape($Pattern)) {
        throw "Expected '$Path' not to contain '$Pattern'."
    }
}

function Get-FunctionBody([string]$Path, [string]$Handler) {
    $content = Get-SourceText $Path
    $searchStart = 0

    while (($handlerIndex = $content.IndexOf($Handler, $searchStart, [System.StringComparison]::Ordinal)) -ge 0) {
        $openBraceIndex = $content.IndexOf('{', $handlerIndex + $Handler.Length)
        if ($openBraceIndex -ge 0 -and $content.Substring($handlerIndex + $Handler.Length, $openBraceIndex - $handlerIndex - $Handler.Length) -match '^\s*$') {
            $depth = 0
            for ($index = $openBraceIndex; $index -lt $content.Length; $index++) {
                if ($content[$index] -eq '{') {
                    $depth++
                } elseif ($content[$index] -eq '}') {
                    $depth--
                    if ($depth -eq 0) {
                        return $content.Substring($openBraceIndex + 1, $index - $openBraceIndex - 1)
                    }
                }
            }
            break
        }
        $searchStart = $handlerIndex + $Handler.Length
    }

    throw "Expected '$Path' to define handler '$Handler'."
}

function Get-BracedBlockBody([string]$Path, [string]$Marker) {
    $content = Get-SourceText $Path
    $markerIndex = $content.IndexOf($Marker, [System.StringComparison]::Ordinal)
    if ($markerIndex -lt 0) {
        throw "Expected '$Path' to contain block marker '$Marker'."
    }

    $openBraceIndex = $content.IndexOf('{', $markerIndex + $Marker.Length)
    if ($openBraceIndex -lt 0) {
        throw "Expected block marker '$Marker' in '$Path' to have an opening brace."
    }

    $depth = 0
    for ($index = $openBraceIndex; $index -lt $content.Length; $index++) {
        if ($content[$index] -eq '{') {
            $depth++
        } elseif ($content[$index] -eq '}') {
            $depth--
            if ($depth -eq 0) {
                return $content.Substring($openBraceIndex + 1, $index - $openBraceIndex - 1)
            }
        }
    }

    throw "Expected block marker '$Marker' in '$Path' to have a closing brace."
}

function Assert-HandlerContains([string]$Path, [string]$Handler, [string]$RequiredCall) {
    $body = Get-FunctionBody $Path $Handler
    if ($body.IndexOf($RequiredCall, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Expected handler '$Handler' in '$Path' to call '$RequiredCall'."
    }
}

function Assert-HandlerMatches([string]$Path, [string]$Handler, [string]$Pattern) {
    $body = Get-FunctionBody $Path $Handler
    if ($body -notmatch $Pattern) {
        throw "Expected handler '$Handler' in '$Path' to match '$Pattern'."
    }
}

function Assert-BlockContains([string]$Path, [string]$Marker, [string]$RequiredCall) {
    $body = Get-BracedBlockBody $Path $Marker
    if ($body.IndexOf($RequiredCall, [System.StringComparison]::Ordinal) -lt 0) {
        throw "Expected block '$Marker' in '$Path' to contain '$RequiredCall'."
    }
}

function Assert-HandlerContainsInOrder([string]$Path, [string]$Handler, [string]$FirstPattern, [string]$SecondPattern) {
    $body = Get-FunctionBody $Path $Handler
    $firstIndex = $body.IndexOf($FirstPattern, [System.StringComparison]::Ordinal)
    $secondIndex = $body.IndexOf($SecondPattern, [System.StringComparison]::Ordinal)
    if ($firstIndex -lt 0 -or $secondIndex -lt 0 -or $firstIndex -ge $secondIndex) {
        throw "Expected handler '$Handler' in '$Path' to contain '$FirstPattern' before '$SecondPattern'."
    }
}

function Assert-HandlerHasImmediateNextLine([string]$Path, [string]$Handler, [string]$Line, [string]$NextLine) {
    $lines = (Get-FunctionBody $Path $Handler) -split '\r?\n'
    for ($index = 0; $index -lt $lines.Count - 1; $index++) {
        if ($lines[$index].Trim() -ceq $Line -and $lines[$index + 1].Trim() -ceq $NextLine) {
            return
        }
    }
    throw "Expected handler '$Handler' in '$Path' to have '$NextLine' immediately after '$Line'."
}

function Assert-AppLifecycle([string]$Path) {
    $content = Get-SourceText $Path
    $assignmentMatches = [regex]::Matches(
        $content,
        '^\s*(?<appVariable>[A-Za-z_]\w*)\s*:=\s*App\(A_ScriptFullPath\)\s*$',
        [System.Text.RegularExpressions.RegexOptions]::Multiline
    )
    if ($assignmentMatches.Count -ne 1) {
        throw "Expected '$Path' to contain exactly one application assignment, found $($assignmentMatches.Count)."
    }

    $appVariable = $assignmentMatches[0].Groups['appVariable'].Value
    if ($appVariable -ieq 'App') {
        throw "Application variable '$appVariable' conflicts with the App class because AutoHotkey identifiers are case-insensitive."
    }
    $startPattern = '^\s*' + [regex]::Escape($appVariable) + '\.Start\(\)\s*$'
    $startMatches = [regex]::Matches($content, $startPattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($startMatches.Count -ne 1) {
        throw "Expected '$Path' to contain exactly one '$appVariable.Start()' call, found $($startMatches.Count)."
    }
}

$root = Split-Path -Parent $PSScriptRoot
$entryPoint = Join-Path $root 'autohotkey.ahk'
$hotkeys = Join-Path $root 'hotkeys.ahk'
$app = Join-Path $root 'Lib/App.ahk'
$windowLauncher = Join-Path $root 'Lib/WindowLauncher.ahk'
$komorebi = Join-Path $root 'Lib/Komorebi.ahk'
$apps = Join-Path $root 'Apps.ahk'
$windowManager = Join-Path $root 'WindowManager.ahk'
$chords = Join-Path $root 'Chords.ahk'

Assert-Contains $entryPoint '#Requires AutoHotkey v2.0'
Assert-Contains $entryPoint '#SingleInstance Force'
Assert-Contains $entryPoint '#Warn All, StdOut'
Assert-Contains $entryPoint '#Include "Lib/App.ahk"'
Assert-Contains $entryPoint '#Include "Lib/WindowLauncher.ahk"'
Assert-Contains $entryPoint '#Include "Lib/Komorebi.ahk"'
Assert-Contains $entryPoint '#Include "Lib/KeyChord/KeyChord.ahk"'
Assert-Contains $entryPoint '#Include "Apps.ahk"'
Assert-Contains $entryPoint '#Include "WindowManager.ahk"'
Assert-Contains $entryPoint '#Include "Chords.ahk"'
Assert-Contains $entryPoint '#Include "Hotkeys.ahk"'
Assert-Contains $entryPoint '#Include "Hotstrings.ahk"'
Assert-AppLifecycle $entryPoint
Assert-NotContains $entryPoint 'CreateStartupShortcut'
Assert-NotContains $entryPoint 'FileCreateShortcut'
Assert-NotContains $entryPoint 'ToggleStartup'

Assert-Contains $app 'class App'
Assert-Contains $app 'ToggleStartup(*)'
Assert-HandlerContains $app 'Start()' 'A_TrayMenu.Add("Edit script", this.EditScript.Bind(this))'
Assert-HandlerContains $app 'Start()' 'A_TrayMenu.Add("Run at startup", this.ToggleStartup.Bind(this))'
Assert-HandlerContains $app 'Start()' 'A_TrayMenu.Add("Reload", this.ReloadScript.Bind(this))'
Assert-HandlerContains $app 'Start()' 'A_TrayMenu.Add("Exit", this.Exit.Bind(this))'
Assert-HandlerContains $app 'EditScript(*)' 'Edit()'
Assert-HandlerContains $app 'ReloadScript(*)' 'Reload()'
Assert-HandlerContains $app 'Exit(*)' 'ExitApp()'
Assert-HandlerMatches $app 'HasOwnedStartupShortcut(*)' 'FileGetShortcut\s*\(\s*this\.startupLink\s*,'
Assert-HandlerMatches $app 'HasOwnedStartupShortcut(*)' 'return\s+target\s*=\s*A_AhkPath\s*&&\s*arguments\s*=\s*Quote\(this\.scriptPath\)'
Assert-HandlerHasImmediateNextLine $app 'RemoveStartupShortcut(*)' 'if !this.HasOwnedStartupShortcut()' 'return false'
Assert-HandlerContains $app 'RemoveStartupShortcut(*)' 'FileDelete(this.startupLink)'
Assert-HandlerContainsInOrder $app 'RemoveStartupShortcut(*)' 'return false' 'FileDelete(this.startupLink)'
Assert-Contains $app 'FileCreateShortcut(A_AhkPath'
Assert-HandlerMatches $app 'ToggleStartup(*)' '(?s)if\s+this\.HasOwnedStartupShortcut\(\)\s*\{.*?RemoveStartupShortcut\(\).*?\}\s*else\s*\{.*?CreateStartupShortcut\(\)'
Assert-HandlerMatches $app 'ToggleStartup(*)' '(?s)else\s*\{\s*if\s+FileExist\(this\.startupLink\)\s*\{[^{}]*MsgBox[^{}]*return[^{}]*\}[^{}]*CreateStartupShortcut\(\)'
Assert-HandlerMatches $app 'CreateStartupShortcut(*)' '(?s)try\s+FileCreateShortcut\(A_AhkPath,\s*this\.startupLink,[^\r\n]*\)\s*catch\s+Error(?:\s+as\s+\w+)?\s*\{[^{}]*return\s+false[^{}]*\}'
Assert-HandlerMatches $app 'RemoveStartupShortcut(*)' '(?s)try\s+FileDelete\(this\.startupLink\)\s*catch\s+Error(?:\s+as\s+\w+)?\s*\{[^{}]*return\s+false[^{}]*\}'
Assert-HandlerMatches $app 'ToggleStartup(*)' '(?s)if\s+this\.HasOwnedStartupShortcut\(\)\s*\{[^{}]*if\s+this\.RemoveStartupShortcut\(\)\s*&&\s*!this\.HasOwnedStartupShortcut\(\)\s*\r?\n\s*A_TrayMenu\.Uncheck\("Run at startup"\)'
Assert-HandlerMatches $app 'ToggleStartup(*)' '(?s)else\s*\{[^{}]*if\s+FileExist\(this\.startupLink\)\s*\{[^{}]*\}[^{}]*if\s+this\.CreateStartupShortcut\(\)\s*&&\s*this\.HasOwnedStartupShortcut\(\)\s*\r?\n\s*A_TrayMenu\.Check\("Run at startup"\)'

Assert-Contains $hotkeys '^!#r::Reload()'
Assert-NotContains $hotkeys 'WindowLauncher.ActivateOrRun('

Assert-Contains $windowLauncher 'class WindowLauncher'
Assert-Contains $windowLauncher 'static Find(app)'
Assert-Contains $windowLauncher 'try Run(app.Command)'
Assert-HandlerContains $windowLauncher 'ActivateOrRun(app)' 'this.Activate(hwnd'
Assert-BlockContains $windowLauncher 'catch Error as' 'MsgBox'
Assert-BlockContains $windowLauncher 'catch Error as' 'return false'
Assert-HandlerContainsInOrder $windowLauncher 'Activate(hwnd, popupArea := "")' 'Komorebi.FocusWorkspace(workspace)' 'WinActivate(target)'

Assert-Contains $komorebi 'class Komorebi'
Assert-Contains $komorebi 'static WorkspaceOf(hwnd)'
Assert-Contains $komorebi 'RunWait(this.CommandLine(args), , "Hide")'

Assert-Contains $windowManager 'BindWorkspaceHotkeys(["dev", "notes", "ai-lab", "research", "comms", "files", "scratch"])'
Assert-Contains $chords '#Space::Chords.Open(Chords.Root)'
Assert-Contains $chords 'KeyChord()'

foreach ($name in 'Zed', 'ClaudeCode', 'Shell', 'Obsidian', 'Zen', 'Typora', 'Perplexity', 'Claude', 'ChatGPT', 'Copilot', 'Gemini',
                   'Spark', 'TickTick', 'Fantastical', 'Explorer', 'Everything', 'Koffee', 'Bitwarden', 'TaskManager') {
    Assert-Contains $apps "${name}:"
    Assert-Contains $chords "Apps.$name)"
}
