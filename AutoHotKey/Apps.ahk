#Requires AutoHotkey v2.0

; One entry per app the chords can reach. Fields are documented in Lib/WindowLauncher.ahk.
; Workspace placement lives in ~/.config/komorebi/komorebi.json (initial_workspace_rules).

AppsFolder(appId) => 'explorer.exe "shell:AppsFolder\' appId '"'

LocalPrograms := EnvGet("LocalAppData") "\Programs"
Projects := EnvGet("UserProfile") "\projects"

Apps := {
    ; dev
    Zed:         { Criteria: "ahk_exe Zed.exe", Command: Quote(LocalPrograms "\Zed\Zed.exe") },
    ClaudeCode:  { Criteria: "Claude Code ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w claude new-tab --title "Claude Code" --suppressApplicationTitle -p "PowerShell" -d "' Projects '" pwsh.exe -NoExit -Command claude' },
    Shell:       { Criteria: "Shell ahk_exe WindowsTerminal.exe",
                   Command: 'wt.exe -w shell new-tab --title "Shell" --suppressApplicationTitle -p "PowerShell"' },

    ; notes
    Obsidian:    { Criteria: "ahk_exe Obsidian.exe", Command: Quote(LocalPrograms "\Obsidian\Obsidian.exe") },

    ; research
    Zen:         { Criteria: "ahk_exe zen.exe", Command: Quote("C:\Program Files\Zen Browser\zen.exe") },
    Brave:       { Criteria: "ahk_exe brave.exe", Command: Quote("C:\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe") },
    Chrome:      { Criteria: "ahk_exe chrome.exe", Exclude: "Gemini", MatchMode: 2,
                   Command: Quote("C:\Program Files\Google\Chrome\Application\chrome.exe") },
    Edge:        { Criteria: "ahk_exe msedge.exe", Command: Quote("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe") },
    Typora:      { Criteria: "ahk_exe Typora.exe", Command: Quote(LocalPrograms "\Typora\Typora.exe") },

    ; ai-lab
    Perplexity:  { Criteria: "ahk_exe Perplexity.exe", Command: AppsFolder("PerplexityAI.PerplexityApp_3jh4kjrg4dzr2!ai.perplexity.PerplexityPersonalComputer.Electron") },
    Claude:      { Criteria: "ahk_exe claude.exe", Command: AppsFolder("Claude_pzs8sxrjxfjjc!Claude") },
    ChatGPT:     { Criteria: "ahk_exe ChatGPT.exe", Command: AppsFolder("OpenAI.Codex_2p2nqsd0c76g0!App") },
    Copilot:     { Criteria: "ahk_exe github.exe", Command: Quote(LocalPrograms "\GitHub Copilot\github.exe") },
    Gemini:      { Criteria: "Gemini ahk_exe chrome.exe", MatchMode: 2, Command: AppsFolder("Chrome._crx_gdfaincndodkhapmbffkckdkhn") },

    ; comms
    Spark:       { Criteria: "ahk_exe Spark Desktop.exe", Command: Quote(LocalPrograms "\SparkDesktop\Spark Desktop.exe") },
    TickTick:    { Criteria: "ahk_exe TickTick.exe", Command: Quote("C:\Program Files (x86)\TickTick\TickTick.exe") },
    Fantastical: { Criteria: "ahk_exe Fantastical.exe", Command: AppsFolder("FlexibitsInc.Fantastical_xhwyj10g4qjsr!AppMain") },

    ; files
    Explorer:    { Criteria: "ahk_class CabinetWClass", Command: "explorer.exe" },
    Everything:  { Criteria: "ahk_class EVERYTHING ahk_exe Everything.exe", Command: Quote("C:\Program Files\Everything\Everything.exe") },

    ; popups: ignored by komorebi, so they stay visible on every workspace
    Koffee:      { Criteria: "ahk_exe Koffee.exe", Popup: true, Command: Quote(EnvGet("UserProfile") "\.local\share\scoop\apps\koffee\current\Koffee.exe") },
    Bitwarden:   { Criteria: "ahk_exe Bitwarden.exe", Popup: true, Command: Quote(LocalPrograms "\Bitwarden\Bitwarden.exe") },
    TaskManager: { Criteria: "ahk_exe Task Manager.exe", Popup: true, Command: Quote(LocalPrograms "\Task Manager TMOG\Task Manager.exe") },
}
