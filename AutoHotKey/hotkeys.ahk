#Requires AutoHotkey v2.0

^!#r::Reload()
^!#q::ExitApp()
^!#t::OpenWindowsTerminal()
^!#e::OpenFileExplorer()
^!#f::OpenEverything()
^!#k::OpenKoffee()
^!#Esc::OpenTaskManager()

; Open perplexity, claude. Open Zed.


OpenWindowsTerminal(*) {
    WindowLauncher.ActivateOrRun("ahk_exe WindowsTerminal.exe", "wt.exe")
}

OpenFileExplorer(*) {
    WindowLauncher.ActivateOrRun("ahk_class CabinetWClass", "explorer.exe")
}

OpenEverything(*) {
    WindowLauncher.ActivateOrRun("ahk_exe everything.exe", "C:\Program Files\Everything\Everything.exe")
}

OpenKoffee(*) {
    WindowLauncher.ActivateOrRun("ahk_exe Koffee.exe", "koffee.exe")
}

OpenTaskManager(*) {
    WindowLauncher.ActivateOrRun("ahk_exe procexp64.exe", "C:\Users\simsr\.local\share\scoop\apps\sysinternals\current\procexp64.exe")
}

;"C:\Program Files\Everything\Everything.exe" -is-relaunch-command

localAppDataDir := EnvGet("LocalAppData")
chromePath := "C:\Program Files\Google\Chrome\Application\chrome.exe"
cleanProfileDir := localAppDataDir "\Google\Chrome\AHK-CleanProfile"

zenWin := "ahk_exe zen.exe"

; Meta + Shift + O: Open current Zen tab in Chrome
#HotIf WinActive(zenWin)
#+o::OpenCurrentZenTabInChrome()
#HotIf

OpenCurrentZenTabInChrome() {
    global chromePath, cleanProfileDir

    savedClip := ClipboardAll()
    A_Clipboard := ""

    ; Zen default: Copy Current URL = Ctrl+Shift+C ("^+c")
    ; Modified to Ctrl+Alt+C
    Send "^!c"

    if !ClipWait(1.5) {
        A_Clipboard := savedClip
        MsgBox "Couldn't get the current tab URL from Zen.", "AHK", "Icon!"
        return
    }
    url := Trim(A_Clipboard)
    A_Clipboard := savedClip

    if !RegExMatch(url, "i)^(https?|file|ftp)://") {
        MsgBox "Clipboard did not contain a valid URL:`n`n" url, "AHK", "Icon!"
        return
    }

    DirCreate(cleanProfileDir)

    cmd := '"' chromePath '" --new-window --user-data-dir="' cleanProfileDir '" "' url '"'

    try Run(cmd)
    catch Error as err {
        MsgBox "Failed to launch Chrome.`n`n" err.Message, "AHK", "Icon!"
    }
}
