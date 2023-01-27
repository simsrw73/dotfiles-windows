#SingleInstance, Force
SendMode Input
SetWorkingDir, %A_ScriptDir%

;; With xbox game bar removed, the guide button causes an error; this stops that
VK07::
return
