#Requires -Version 7.0

Set-PSReadLineOption -EditMode Windows -HistorySearchCursorMovesToEnd
try {
    # PredictionSource and ListView require a real VT-capable terminal
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin
    Set-PSReadLineOption -PredictionViewStyle ListView
    Set-PSReadLineOption -Colors @{ InlinePrediction = '#ffdd99' }
} catch {
    # Non-interactive or redirected — skip prediction UI options silently
}
Remove-PSReadLineKeyHandler 'Ctrl+r'
Remove-PSReadLineKeyHandler 'Ctrl+t'
Set-PSReadLineKeyHandler -Chord Ctrl+p -Function PreviousHistory
Set-PSReadLineKeyHandler -Chord Ctrl+n -Function NextHistory

$catppuccinMochaTheme = @{
    Rosewater = '#f5e0dc'
    Flamingo  = '#f2cdcd'
    Pink      = '#f5c2e7'
    Mauve     = '#cba6f7'
    Red       = '#f38ba8'
    Maroon    = '#eba0ac'
    Peach     = '#fab387'
    Yellow    = '#f9e2af'
    Green     = '#a6e3a1'
    Teal      = '#94e2d5'
    Sky       = '#89dceb'
    Sapphire  = '#74c7ec'
    Blue      = '#89b4fa'
    Lavender  = '#b4befe'
    Text      = '#cdd6f4'
    Subtext1  = '#bac2de'
    Subtext0  = '#a6adc8'
    Overlay2  = '#9399b2'
    Overlay1  = '#7f849c'
    Overlay0  = '#6c7086'
    Surface2  = '#585b70'
    Surface1  = '#45475a'
    Surface0  = '#313244'
    Base      = '#1e1e2e'
    Mantle    = '#181825'
    Crust     = '#11111b'
}

$catppuccin = $catppuccinMochaTheme

$catppuccinSyntaxTheme = @{
    Command            = $catppuccin.Blue
    Comment            = $catppuccin.Overlay0
    ContinuationPrompt = $catppuccin.Yellow
    Default            = $catppuccin.Peach
    Emphasis           = $catppuccin.Yellow
    Error              = $catppuccin.Red
    Keyword            = $catppuccin.Sky
    Member             = $catppuccin.Flamingo
    Number             = $catppuccin.Peach
    Operator           = $catppuccin.Sky
    Parameter          = $catppuccin.Lavender
    Selection          = $catppuccin.Surface2
    String             = $catppuccin.Green
    Type               = $catppuccin.Red
    Variable           = $catppuccin.Text
}

Set-PSReadLineOption -Colors $catppuccinSyntaxTheme

# History — XDG path, deduplication, sensible limit
$psrlHistoryOpts = @{
    HistorySavePath     = Join-Path $Env:XDG_STATE_HOME 'ps_history.txt'
    MaximumHistoryCount = 10000
    HistoryNoDuplicates = $true
}
Set-PSReadLineOption @psrlHistoryOpts
