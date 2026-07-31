; Hotkeys.ahk  -  all keyboard shortcuts

; Reload main script
^!r::Reload()            ; Ctrl+Alt+R

; Open script/config folder
^!e::OpenConfigFolder()  ; uses function in Startup.ahk

#
^`::SwitchToWindowsTerminal()

SwitchToWindowsTerminal() {
    windowHandleId := WinExist("ahk_exe WindowsTerminal.exe")
    if (windowHandleId > 0) {
        if (WinExist("A") == windowHandleId)
            WinMinimize("ahk_id " . windowHandleId)
        else {
            WinActivate("ahk_id " . windowHandleId)
            WinShow("ahk_id " . windowHandleId)
        }
    } else {
        Run("wt")
    }
}

GetExplorerPath() {
    shell := ComObject("Shell.Application")
    for window in shell.Windows {
        if (window.HWND = WinGetID("A"))
            return window.Document.Folder.Self.Path
    }
    return ""
}