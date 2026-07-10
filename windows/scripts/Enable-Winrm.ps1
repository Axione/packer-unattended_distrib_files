# Configure WinRM for Ansible
# Windows Server 2019 Core
# HTTP 5985 + Basic auth + Firewall rules

$ErrorActionPreference = "Stop"

Write-Host "=== Configure Network Profile ==="

# Force network profile
$profiles = Get-NetConnectionProfile

foreach ($profile in $profiles) {
    try {
        Set-NetConnectionProfile `
            -InterfaceIndex $profile.InterfaceIndex `
            -NetworkCategory Private
    }
    catch {
        Write-Warning "Unable to set network profile"
    }
}


Write-Host "=== Configure WinRM Service ==="

# Service startup
Set-Service `
    -Name WinRM `
    -StartupType Automatic

Start-Service WinRM


Write-Host "=== Enable PowerShell Remoting ==="

Enable-PSRemoting `
    -Force `
    -SkipNetworkProfileCheck


Write-Host "=== Configure WinRM HTTP Listener ==="

# Remove existing listeners
$listeners = winrm enumerate winrm/config/listener

# Create HTTP listener if missing
winrm create winrm/config/Listener?Address=*+Transport=HTTP


Write-Host "=== Configure Authentication ==="

# Allow Basic authentication
winrm set winrm/config/service/auth '@{Basic="true"}'

# Allow HTTP without encryption
winrm set winrm/config/service '@{AllowUnencrypted="true"}'


Write-Host "=== Configure WinRM limits ==="

winrm set winrm/config '@{MaxTimeoutms="1800000"}'

winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="1024"}'

winrm set winrm/config/winrs '@{MaxShellsPerUser="50"}'


Write-Host "=== Configure Firewall WinRM ==="

# Enable existing rules
Get-NetFirewallRule |
Where-Object {
    $_.DisplayName -like "*Windows Remote Management*" -or
    $_.DisplayName -like "*WinRM*"
} |
Enable-NetFirewallRule


# Force create rules if missing
if (-not (Get-NetFirewallRule -DisplayName "Allow WinRM HTTP 5985" -ErrorAction SilentlyContinue)) {

    New-NetFirewallRule `
        -DisplayName "Allow WinRM HTTP 5985" `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort 5985 `
        -Action Allow
}


Write-Host "=== Configure ICMP Ping Firewall ==="

if (-not (Get-NetFirewallRule -DisplayName "Allow ICMPv4 Echo Request" -ErrorAction SilentlyContinue)) {

    New-NetFirewallRule `
        -DisplayName "Allow ICMPv4 Echo Request" `
        -Protocol ICMPv4 `
        -IcmpType 8 `
        -Direction Inbound `
        -Action Allow
}


Write-Host "=== Restart WinRM ==="

Restart-Service WinRM


Write-Host "=== Validation ==="

Write-Host "Listener:"
winrm enumerate winrm/config/listener

Write-Host "Service:"
Get-Service WinRM

Write-Host "Firewall:"
Get-NetFirewallRule |
Where-Object {
    $_.DisplayName -like "*WinRM*" -or
    $_.DisplayName -like "*ICMP*"
} |
Select DisplayName, Enabled, Direction, Action


Write-Host "WSMan test:"
Test-WSMan localhost


# Marker file for Packer troubleshooting
New-Item `
    -Path "C:\winrm-configured.txt" `
    -ItemType File `
    -Force


Write-Host "=== WinRM configuration completed ==="
