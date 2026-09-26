#Requires AutoHotkey v2.0

class WindowLauncher {
    static ActivateOrRun(windowCriteria, command, timeoutSeconds := 5) {
        if hwnd := WinExist(windowCriteria) {
            if WinGetMinMax("ahk_id " hwnd) = -1
                WinRestore("ahk_id " hwnd)
            WinActivate("ahk_id " hwnd)
            return true
        }

        try Run(command)
        catch Error as err {
            MsgBox("Could not start " command ".`n`n" err.Message, "AutoHotkey", "Iconx")
            return false
        }

        if !WinWait(windowCriteria, , timeoutSeconds) {
            MsgBox("Started " command ", but its window did not appear in " timeoutSeconds " seconds.", "AutoHotkey", "Icon!")
            return false
        }

        WinActivate(windowCriteria)
        return true
    }
}
