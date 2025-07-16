# Configuration
$ipAddress = "10.0.0.1"
$subnetPrefix = 24
$gateway = "10.0.0.254"
$domainName = "corp.local"
$netbiosName = "CORP"

# Get the first active network adapter
$interface = Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | Select-Object -First 1

Write-Host "`n🌐 Configuring static IP address..." -ForegroundColor Cyan
New-NetIPAddress -InterfaceIndex $interface.IfIndex -IPAddress $ipAddress -PrefixLength $subnetPrefix -DefaultGateway $gateway -ErrorAction SilentlyContinue
Set-DnsClientServerAddress -InterfaceIndex $interface.IfIndex -ServerAddresses "127.0.0.1"

Write-Host "`n🛡️ Opening ALL firewall ports (inbound + outbound)..." -ForegroundColor Yellow
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultInboundAction Allow
Set-NetFirewallProfile -Profile Domain,Private,Public -DefaultOutboundAction Allow
Write-Host "✔️ All firewall ports are now allowed (use only in secure/test environments)." -ForegroundColor Green

Write-Host "`n🔧 Installing Active Directory Domain Services..." -ForegroundColor Cyan
Install-WindowsFeature AD-Domain-Services -IncludeManagementTools

Write-Host "`n🏗️ Creating new forest: $domainName" -ForegroundColor Cyan
$dsrmPassword = Read-Host -AsSecureString "Enter DSRM (Directory Services Restore Mode) password"
Install-ADDSForest -DomainName $domainName -DomainNetbiosName $netbiosName -InstallDNS -SafeModeAdministratorPassword $dsrmPassword -Force
