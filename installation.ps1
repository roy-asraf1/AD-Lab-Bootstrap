Start-Sleep -Seconds 30

# ========== Set Static IP ==========
New-NetIPAddress -InterfaceAlias $InterfaceAlias -IPAddress $IPAddress -PrefixLength 24 -DefaultGateway $Gateway
Set-DnsClientServerAddress -InterfaceAlias $InterfaceAlias -ServerAddresses $IPAddress

# ========== Install AD DS ==========
Install-WindowsFeature -Name AD-Domain-Services -IncludeManagementTools

# ========== Create New Domain ==========
$dsrmPwd = Read-Host "Enter DSRM (Directory Services Restore Mode) password" -AsSecureString

Install-ADDSForest `
    -DomainName $NewDomain `
    -DomainNetbiosName $NetbiosName `
    -SafeModeAdministratorPassword $dsrmPwd `
    -InstallDNS `
    -Force
