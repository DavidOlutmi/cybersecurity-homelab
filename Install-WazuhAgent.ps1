# ===================================================================
# Wazuh Agent Silent Install — Windows
# Run this on the DC, the Windows 10 client, or any future
# domain-joined machine you want reporting to your Wazuh SIEM.
# ===================================================================

# ----- Edit these Variables for your own Use Case ----- #
$WAZUH_MANAGER_IP = "192.168.56.20"   # Ubuntu Wazuh host's IP on the internal network
$WAZUH_AGENT_MSI  = "https://packages.wazuh.com/4.x/windows/wazuh-agent-4.9.0-1.msi"
$INSTALL_PATH     = "$env:TEMP\wazuh-agent.msi"
$AGENT_NAME       = $env:COMPUTERNAME  # names the agent after this machine automatically
# ------------------------------------------------------ #

Write-Host "Downloading Wazuh agent installer..." -ForegroundColor Cyan
Invoke-WebRequest -Uri $WAZUH_AGENT_MSI -OutFile $INSTALL_PATH

if (-not (Test-Path $INSTALL_PATH)) {
    Write-Host "ERROR: Wazuh agent MSI failed to download." -ForegroundColor Red
    exit
}

Write-Host "Installing Wazuh agent and registering with manager at $WAZUH_MANAGER_IP..." -ForegroundColor Cyan

# Silent install, passing the manager IP and agent name directly as MSI properties.
# This registers the agent to your Wazuh manager without any manual configuration.
Start-Process msiexec.exe -ArgumentList @(
    "/i", "`"$INSTALL_PATH`"",
    "/q",
    "WAZUH_MANAGER=`"$WAZUH_MANAGER_IP`"",
    "WAZUH_AGENT_NAME=`"$AGENT_NAME`""
) -Wait

# Start the Wazuh agent service
Write-Host "Starting Wazuh agent service..." -ForegroundColor Cyan
Start-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue

# Verify the service is running
$service = Get-Service -Name "WazuhSvc" -ErrorAction SilentlyContinue
if ($service -and $service.Status -eq "Running") {
    Write-Host "`nWazuh agent installed and running on $AGENT_NAME, registered to $WAZUH_MANAGER_IP" -ForegroundColor Green
    Write-Host "Check the Wazuh dashboard (Agents page) to confirm this host appears as connected.`n" -ForegroundColor Green
} else {
    Write-Host "`nWazuh agent installed but the service is not running. Check manually with:" -ForegroundColor Yellow
    Write-Host "  Get-Service WazuhSvc" -ForegroundColor Yellow
    Write-Host "  Get-Content 'C:\Program Files (x86)\ossec-agent\ossec.log' -Tail 30`n" -ForegroundColor Yellow
}

# Clean up the installer
Remove-Item $INSTALL_PATH -ErrorAction SilentlyContinue
