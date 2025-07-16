# ========== After Reboot: Open Firewall ==========
# Run this part separately after the machine is back up and domain is created

# Enable all necessary firewall rules for AD functionality
$firewallGroups = @(
    "File and Printer Sharing",
    "Windows Management Instrumentation (WMI)",
    "Remote Event Log Management",
    "Remote Volume Management",
    "Active Directory Domain Controller",
    "Active Directory Web Services",
    "DNS Server",
    "Kerberos Key Distribution Center",
    "Windows Time Service",
    "Remote Desktop",
    "Netlogon Service"
)

foreach ($group in $firewallGroups) {
    Enable-NetFirewallRule -DisplayGroup $group -ErrorAction SilentlyContinue
}

Write-Host "✅ Firewall rules enabled, domain created, all set."
