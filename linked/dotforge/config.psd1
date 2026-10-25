# DotForge settings, read by Start-DFSession (~/.config/dotforge is linked here).
# Data only: literal values and comments, no code. Every key: Get-Help Start-DFSession,
# or DotForge's docs/guide/configuration.md.
#
# Only the tools listed here are configured; nothing is installed at load. Missing
# ones are listed at the end of loading (Get-DFToolStatus -Missing shows them).
# Groups: Get-DFToolGroup. oh-my-posh (replaced by starship) and lsd (eza fills
# 'listing') are simply not requested; to switch back, request them here.
@{
    Tools = @(
        '+core', '+prompt', '+git', '+dev-tools', '+javascript-dev', '+python-dev', '+rust-dev',
        '+admin-tools', '+markdown', '+package-managers'
        # Not in any group. posh-git and Terminal-Icons were dropped: starship shows git
        # status, carapace completes git, and eza (ls/ll/la/tree) draws its own icons.
        # docker too: Docker Desktop writes ~/.docker whatever DOCKER_CONFIG says.
        'bitwarden', 'broot', 'choco', 'direnv', 'inshellisense', 'mdcat', 'mdv',
        'moor', 'ov', 'ps-dotenv', 'vcpkg', 'vivid'
    )
    ExcludeTools = @('lazygit')   # in +git, not installed
    InstallOrder = @('scoop', 'winget')
    PSReadLineEditMode = 'Emacs'
    PSReadLineTheme = 'catppuccin-mocha'
    # Startup banner: clears the screen, then fastfetch, drive health and the public IP,
    # gathered while tools load and printed a line at a time.
    ShowBanner = $true
}
