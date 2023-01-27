#SingleInstance Force

; You can generate a fresh version of this file with "komorebic ahk-library"
#Include %A_ScriptDir%\komorebic.lib.ahk
; https://github.com/LGUG2Z/komorebi/#generating-common-application-specific-configurations
#Include %A_ScriptDir%\komorebi.generated.ahk

; Default to minimizing windows when switching workspaces
WindowHidingBehaviour("hide")

; Set cross-monitor move behaviour to insert instead of swap
CrossMonitorMoveBehaviour("insert")

; Enable hot reloading of changes to this file
WatchConfiguration("enable")

; Ensure there is 1 workspace created on monitor 0
EnsureWorkspaces(0, 1)

; Configure the invisible border dimensions
InvisibleBorders(7, 0, 14, 7)

; Configure the 1st workspace
WorkspaceName(0, 0, "I")

; Uncomment the next two lines if you want a visual border drawn around the focused window
ActiveWindowBorderColour(180, 190, 254, "single")
ActiveWindowBorderColour(116, 199, 236, "stack")
ActiveWindowBorder("enable")

; Allow komorebi to start managing windows
CompleteConfiguration()


;; ===================================

;  #    Super
;  !    Alt
;  ^    Ctrl
;  +    Shift
;  <    Left Modifier
;  >    Right Modifier

; Note: In order to free up keyboard shortcuts, it might help to remove
; some unneeded applications:
;
; Get-AppxPackage *Microsoft.XboxGameOverlay* | Remove-AppxPackage
; Get-AppxPackage *Microsoft.XboxGamingOverlay* | Remove-AppxPackage

; Left Ctrl + VIM to move focus
; Left Ctrl + Shift + VIM to move window
; Alt + Shift + Direction to stack focused window
; Alt + ] to cycle-stack


; Change the focused window, Alt + Vim direction keys (HJKL)
!h::
Focus("left")
return

!j::
Focus("down")
return

!k::
Focus("up")
return

!l::
Focus("right")
return

; Move the focused window in a given direction, Alt + Shift + Vim direction keys (HJKL)
!+h::
Move("left")
return

!+j::
Move("down")
return

!+k::
Move("up")
return

!+l::
Move("right")
return

!]::
CycleStack("next")
return

![::
CycleStack("previous")
return






; Move to a different workspace

; Switch/Move to workspace
; Switch: Alt + 1~5
; Move: Alt + 1~5
!+1::
MoveToWorkspace(0)
return
!1::
FocusWorkspace(0)
return

!+2::
MoveToWorkspace(1)
return
!2::
FocusWorkspace(1)
return

!+3::
MoveToWorkspace(2)
return
!3::
FocusWorkspace(2)
return

!+4::
MoveToWorkspace(3)
return
!4::
FocusWorkspace(3)
return

; etc

; if things get buggy, often a retile will fix it
!+r::
Retile()
return


; manage
; unmanage
; stack
; unstack

#\::
Manage()
return

#+\::
Unmanage()
return

!+Left:
Stack("left")
return

!+Right::
Stack("right")
return

!+Up::
Stack("up")
return

!+Down::
Stack("down")
return

!+c::
Unstack()
return

!+m::
ToggleMonocle()
return

; toggle-tiling
!+t::
ToggleTiling()
return

#p::
TogglePause()
return


;; TODO: Have these detect if Komorebi is running && if active before running these commands
;; Otherwise, pass along to normal Windows handler

; Close()
; Minimize()
; ToggleMaximize()
; toggle-float


;; Application / Window Operations

; cycle-move
; move-to-workspace
; promote
; promote-focus
; resize-axis
; resize-delta
; resize-edge
; send-to-workspace

; identify-border-overflow-application
; identify-layered-application
; identify-object-name-change-application
; identify-tray-application


;; Workspace Operations

; cycle-focus
; cycle-workspace
; focus-workspace
; new-workspace
; workspace-name


;; Layout

; flip-layout (BSP only)
; change-layout bsp, columns, rows, vertical-stack, horizontal-stack, ultrawide-vertical-stack]
; load-custom-layout
; load-resize
; quick-load-resize
; quick-save-resize
; save-resize
; workspace-custom-layout
; workspace-layout


;; Tiling

; toggle-pause
; toggle-window-container-behaviour
; retile
; workspace-tiling
; reload-configuration
; restore-windows


;; Rules
; float-rule
; manage-rule
; workspace-rule



; Resize the focused window
; !+h::
; Resize("right", "increase")
; Resize("left", "decrease")
; return

; !+l::
; Resize("left", "decrease")
; Resize("right", "increase")
; return







; i3 uses
; Basics
;   Super + Enter	open new terminal
;   Super + j	focus left
;   Super + k	focus down
;   Super + l	focus up
;   Super + ;	focus right
;   Super + a	focus parent
;   Super + Space	toggle focus mode

; Moving windows
;   Super + Shift + j	move window left
;   Super + Shift + k	move window down
;   Super + Shift + l	move window up
;   Super + Shift + ;	move window right

; Modifying windows
;   Super + f	toggle fullscreen
;   Super + v	split a window vertically
;   Super + h	split a window horizontally
;   Super + r	resize mode
; (Look at the “Resizing containers / windows” section of the user guide.)

; Changing the container layout
;   Super + e	default
;   Super + s	stacking
;   Super + w	tabbed

; Floating
;   Super + Shift + Space	toggle floating
;   Super + Left click	drag floating

; Using workspaces
;   Super + 0-9	switch to another workspace
;   Super + Shift + 0-9	move a window to another workspace

; Opening applications / Closing windows
;   Super + d	open application launcher (dmenu)
;   Super + Shift + q	kill a window

; Restart / Exit
;  + Shift + c	reload the configuration file
;  + Shift + r	restart i3 inplace
;  + Shift + e	exit i3

; Keybinds for File Manager, Terminal, Browser

; bsp uses
; Super + Alt + Q        Quit BSPWM (better use xfce logout button!)
; Super + Alt + R        Restart BSPWM
; Super + Shift + Q    Kill selected window
; Super + M                Toggle between monocle and tiled layout
; Super + Y                  Switch newest marked node to newest preselected node (node = window)
; Super + G                  Switch current node with the biggest window
; Super + T                  Set window tiled
; Super + Shift + T     Set window pseudo-tiled
; Super + S                  Set window floating
; Super + F                   Set window fullscreen
; Super + Shift + F      Toggle window fullscreen
; Super + Shift + (1-0)  Send window to desktop (1-10)


; There are many more commands that you can bind to whatever keys combinations you want!
;
; Have a look at the komorebic.lib.ahk file to see which arguments are required by different commands
;
; If you want more information about a command, you can run every komorebic command with "--help"
;
; For example, if you see this in komorebic.lib.ahk
;
; WorkspaceLayout(monitor, workspace, value) {
;    Run, komorebic.exe workspace-layout %monitor% %workspace% %value%, , Hide
; }
;
; Just run "komorebic.exe workspace-layout --help" and you'll get all the information you need to use the command
;
; komorebic.exe-workspace-layout
; Set the layout for the specified workspace
;
; USAGE:
;    komorebic.exe workspace-layout <MONITOR> <WORKSPACE> <VALUE>
;
; ARGS:
;    <MONITOR>      Monitor index (zero-indexed)
;    <WORKSPACE>    Workspace index on the specified monitor (zero-indexed)
;    <VALUE>        [possible values: bsp, columns, rows, vertical-stack, horizontal-stack, ultrawide-vertical-stack]
;
; OPTIONS:
;    -h, --help    Print help information
/*

-+*/