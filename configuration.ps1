# ========== Configuration ==========
$ComputerName = "DC-NEW"
$NewDomain = "lab.local"
$NetbiosName = "LAB"
$IPAddress = "10.99.200.100"
$Subnet = "255.255.255.0"
$Gateway = "10.99.200.1"
$InterfaceAlias = "Ethernet"

# ========== Rename Computer ==========
Rename-Computer -NewName $ComputerName -Force -Restart


