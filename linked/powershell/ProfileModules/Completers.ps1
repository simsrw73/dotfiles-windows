#Requires -Version 7.0

#f45873b3-b655-43a6-b217-97c00aa0db58 PowerToys CommandNotFound module

try {
    Import-Module -Name Microsoft.WinGet.CommandNotFound -ErrorAction Stop
} catch {
    # Module not available (requires PowerToys)
}
#f45873b3-b655-43a6-b217-97c00aa0db58
