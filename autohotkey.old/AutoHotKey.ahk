; =================================================================
;  Startup.ahk  -  Personal AutoHotkey v2 startup script for Win 11
; =================================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; -----------------------------------------------------------------
;  Includes (separate files in the same folder)
; -----------------------------------------------------------------
; These files should sit next to Startup.ahk:
;   Hotkeys.ahk     -> all your hotkeys
;   Hotstrings.ahk  -> all your hotstrings
#Include "Hotkeys.ahk"
#Include "Hotstrings.ahk"

; -----------------------------------------------------------------
;  Self-install into user Startup
; -----------------------------------------------------------------
EnsureStartupShortcut()

EnsureStartupShortcut() {
    startupDir := A_Startup
    scriptName := StrReplace(A_ScriptName, ".ahk", "")
    shortcut   := startupDir "\" scriptName ".lnk"

    if !FileExist(shortcut) {
        try {
            FileCreateShortcut(
                A_ScriptFullPath,  ; Target
                shortcut,          ; .lnk path
                A_ScriptDir
            )
        }
        catch as e {
            MsgBox "Failed to create Startup shortcut:`n" e.Message, "Startup.ahk", 48
        }
    }
}

; -----------------------------------------------------------------
;  Global configuration
; -----------------------------------------------------------------
A_MaxHotkeysPerInterval := 1000
A_HotkeyInterval        := 2000

; -----------------------------------------------------------------
;  Startup initialization
; -----------------------------------------------------------------
Init()

Init() {
    ; Run helper tools, set tray icon, etc.
    ; Run "C:\Path\To\SomeTool.exe", , "Min"
    ; TraySetIcon "C:\Path\To\Icon.ico"
}

; -----------------------------------------------------------------
;  Shared functions (used by included files or here)
; -----------------------------------------------------------------
OpenConfigFolder() {
    Run A_ScriptDir
}

; Add more shared helpers below.

; -----------------------------------------------------------------
;  End of auto-execute section
; -----------------------------------------------------------------
Return
