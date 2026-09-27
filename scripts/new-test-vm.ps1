#Requires -Version 7
<#
Creates a Hyper-V VM for fresh-machine tests of bootstrap.ps1 (Windows Sandbox
is unreliable on Insider builds). Run elevated:
    gsudo pwsh -File scripts\new-test-vm.ps1 -IsoPath D:\Win11.iso

Then install Windows once (local account), and checkpoint it:
    Checkpoint-VM -Name dotfiles-test -SnapshotName clean
Before each test run:
    Restore-VMCheckpoint -VMName dotfiles-test -Name clean -Confirm:$false
#>
param(
    [Parameter(Mandatory)][string] $IsoPath,
    [string] $Name = 'dotfiles-test',
    [int] $MemoryGB = 8,
    [int] $Cpu = 4,
    [int] $DiskGB = 80,
    [string] $SwitchName = 'Default Switch',
    [switch] $Start
)
$ErrorActionPreference = 'Stop'

$principal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Run elevated: gsudo pwsh -File scripts\new-test-vm.ps1 -IsoPath <iso>'
}
$IsoPath = (Resolve-Path -LiteralPath $IsoPath).Path
if (Get-VM -Name $Name -ErrorAction SilentlyContinue) { throw "VM '$Name' already exists." }
if (-not (Get-VMSwitch -Name $SwitchName -ErrorAction SilentlyContinue)) { throw "Switch '$SwitchName' not found." }

$vhd = Join-Path (Get-VMHost).VirtualHardDiskPath "$Name.vhdx"
if (Test-Path -LiteralPath $vhd) { throw "Disk already exists: $vhd" }

$vm = New-VM -Name $Name -Generation 2 -MemoryStartupBytes ($MemoryGB * 1GB) `
    -NewVHDPath $vhd -NewVHDSizeBytes ($DiskGB * 1GB) -SwitchName $SwitchName
Set-VMProcessor -VM $vm -Count $Cpu
Set-VMMemory -VM $vm -DynamicMemoryEnabled $false

# Windows 11 needs Secure Boot + TPM 2.0.
Set-VMFirmware -VM $vm -EnableSecureBoot On -SecureBootTemplate MicrosoftWindows
Set-VMKeyProtector -VM $vm -NewLocalKeyProtector
Enable-VMTPM -VM $vm

$dvd = Add-VMDvdDrive -VM $vm -Path $IsoPath -Passthru
Set-VMFirmware -VM $vm -FirstBootDevice $dvd

# Checkpoints only when asked, so `clean` stays the one to revert to;
# enhanced session gives clipboard paste for bootstrap.ps1.
Set-VM -VM $vm -AutomaticCheckpointsEnabled $false -EnhancedSessionTransportType HvSocket
Set-VMHost -EnableEnhancedSessionMode $true

Write-Host "Created VM '$Name' ($MemoryGB GB, $Cpu CPUs, $DiskGB GB disk at $vhd)."
if ($Start) {
    Start-VM -VM $vm
    vmconnect.exe localhost $Name
    Write-Host 'Press a key in the VM window to boot from the ISO.'
}
else {
    Write-Host "Start it: Start-VM $Name; vmconnect localhost $Name (press a key to boot the ISO)."
}
Write-Host 'After Windows setup (local account): eject the ISO and checkpoint it:'
Write-Host "    Get-VMDvdDrive -VMName $Name | Set-VMDvdDrive -Path `$null; Checkpoint-VM -Name $Name -SnapshotName clean"
