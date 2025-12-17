<#
.SYNOPSIS
  Builds Tier0/1/2 OU structure + standard admin groups (idempotent).

.REQUIREMENTS
  - RSAT ActiveDirectory module (Import-Module ActiveDirectory)
  - Permissions to create OUs and groups in target domain/OU

.EXAMPLE
  .\Build-Lab-AD-Structure.ps1
  .\Build-Lab-AD-Structure.ps1 -BaseOU "OU=Corp,DC=lab,DC=local"
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
  [Parameter(Mandatory=$false)]
  [string]$BaseOU, # e.g. "OU=Corp,DC=lab,DC=local" ; if empty -> domain root DN

  [Parameter(Mandatory=$false)]
  [switch]$CreateDefaultGpoLinkPlaceholders # just creates OUs used for linking; no GPO creation here
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

try {
  Import-Module ActiveDirectory -ErrorAction Stop
} catch {
  throw "ActiveDirectory module not found. Install RSAT or run on a DC. Details: $($_.Exception.Message)"
}

function Write-Info([string]$msg) { Write-Host "[INFO]  $msg" }
function Write-Warn([string]$msg) { Write-Warning $msg }

# Resolve base DN
$domain = Get-ADDomain
$domainDN = $domain.DistinguishedName

if ([string]::IsNullOrWhiteSpace($BaseOU)) {
  $BaseOU = $domainDN
  Write-Info "BaseOU not provided. Using domain root: $BaseOU"
} else {
  Write-Info "Using BaseOU: $BaseOU"
}

function Ensure-OU {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$false)][bool]$Protect = $true
  )

  $ouDN = "OU=$Name,$Path"
  $existing = Get-ADOrganizationalUnit -Filter "distinguishedName -eq '$ouDN'" -ErrorAction SilentlyContinue

  if (-not $existing) {
    if ($PSCmdlet.ShouldProcess($ouDN, "Create OU")) {
      New-ADOrganizationalUnit -Name $Name -Path $Path -ProtectedFromAccidentalDeletion:$Protect | Out-Null
      Write-Info "Created OU: $ouDN"
    }
  } else {
    # Ensure protection matches desired
    if ($existing.ProtectedFromAccidentalDeletion -ne $Protect) {
      if ($PSCmdlet.ShouldProcess($ouDN, "Set OU protection to $Protect")) {
        Set-ADOrganizationalUnit -Identity $ouDN -ProtectedFromAccidentalDeletion:$Protect
        Write-Info "Updated OU protection: $ouDN -> $Protect"
      }
    } else {
      Write-Info "OU exists: $ouDN"
    }
  }

  return $ouDN
}

function Ensure-Group {
  param(
    [Parameter(Mandatory=$true)][string]$Name,
    [Parameter(Mandatory=$true)][string]$Path,
    [Parameter(Mandatory=$false)][ValidateSet("Global","DomainLocal","Universal")][string]$Scope = "Global",
    [Parameter(Mandatory=$false)][ValidateSet("Security","Distribution")][string]$Category = "Security",
    [Parameter(Mandatory=$false)][string]$Description = ""
  )

  $existing = Get-ADGroup -Filter "Name -eq '$Name'" -SearchBase $Path -ErrorAction SilentlyContinue
  if (-not $existing) {
    if ($PSCmdlet.ShouldProcess("$Name in $Path", "Create AD Group")) {
      New-ADGroup -Name $Name -SamAccountName $Name -GroupScope $Scope -GroupCategory $Category -Path $Path -Description $Description | Out-Null
      Write-Info "Created Group: $Name (Scope=$Scope) in $Path"
    }
  } else {
    Write-Info "Group exists: $Name in $Path"
  }
}

function Ensure-GroupMember {
  param(
    [Parameter(Mandatory=$true)][string]$Group,
    [Parameter(Mandatory=$true)][string]$Member
  )

  try {
    $members = Get-ADGroupMember -Identity $Group -Recursive | Select-Object -ExpandProperty SamAccountName
    if ($members -contains $Member) {
      Write-Info "Membership exists: $Member -> $Group"
      return
    }
  } catch {
    # If group empty or lookup issues, we'll attempt add
  }

  if ($PSCmdlet.ShouldProcess("$Member -> $Group", "Add group member")) {
    Add-ADGroupMember -Identity $Group -Members $Member -ErrorAction Stop
    Write-Info "Added member: $Member -> $Group"
  }
}

# --------------------------
# 1) Build OU Tree
# --------------------------
Write-Info "Building OU structure..."

# Top-level OUs
$ouTier0      = Ensure-OU -Name "Tier0"      -Path $BaseOU
$ouTier1      = Ensure-OU -Name "Tier1"      -Path $BaseOU
$ouTier2      = Ensure-OU -Name "Tier2"      -Path $BaseOU
$ouApps       = Ensure-OU -Name "Apps"       -Path $BaseOU
$ouQuarantine = Ensure-OU -Name "Quarantine" -Path $BaseOU

# Tier0
$ouT0Admins   = Ensure-OU -Name "Admins"          -Path $ouTier0
$ouT0Acc      = Ensure-OU -Name "Accounts"        -Path $ouT0Admins
$ouT0Groups   = Ensure-OU -Name "Groups"          -Path $ouT0Admins
$ouT0DCs      = Ensure-OU -Name "Domain Controllers" -Path $ouTier0
$ouT0PKI      = Ensure-OU -Name "PKI"             -Path $ouTier0
$ouT0PAW      = Ensure-OU -Name "PAW"             -Path $ouTier0

# Tier1
$ouT1Servers  = Ensure-OU -Name "Servers"         -Path $ouTier1
$ouT1Member   = Ensure-OU -Name "Member Servers"  -Path $ouT1Servers
$ouT1App      = Ensure-OU -Name "App Servers"     -Path $ouT1Servers
$ouT1SQL      = Ensure-OU -Name "SQL Servers"     -Path $ouT1Servers
$ouT1Web      = Ensure-OU -Name "Web Servers"     -Path $ouT1Servers
$ouT1Svc      = Ensure-OU -Name "Service Accounts" -Path $ouTier1
$ouT1Groups   = Ensure-OU -Name "Server Admin Groups" -Path $ouTier1

# Tier2
$ouT2Work     = Ensure-OU -Name "Workstations"    -Path $ouTier2
$ouT2Win11    = Ensure-OU -Name "Windows 11"      -Path $ouT2Work
$ouT2VDI      = Ensure-OU -Name "VDI"             -Path $ouT2Work
$ouT2Users    = Ensure-OU -Name "Users"           -Path $ouTier2
$ouT2Emp      = Ensure-OU -Name "Employees"       -Path $ouT2Users
$ouT2Cont     = Ensure-OU -Name "Contractors"     -Path $ouT2Users
$ouT2Groups   = Ensure-OU -Name "Workstation Admin Groups" -Path $ouTier2

# Apps -> Quest/Proofpoint
$ouAppsQuest  = Ensure-OU -Name "Quest"      -Path $ouApps
$ouAppsPP     = Ensure-OU -Name "Proofpoint" -Path $ouApps

# Quest products under Apps\Quest
$ouQuestARS   = Ensure-OU -Name "ActiveRoles"     -Path $ouAppsQuest
$ouQuestGPOA  = Ensure-OU -Name "GPOADmin"        -Path $ouAppsQuest
$ouQuestCAud  = Ensure-OU -Name "ChangeAuditor"   -Path $ouAppsQuest
$ouQuestPM    = Ensure-OU -Name "PasswordManager" -Path $ouAppsQuest
$ouQuestIDX   = Ensure-OU -Name "IdentityX"       -Path $ouAppsQuest

# Quarantine
$ouQStage     = Ensure-OU -Name "Staging"         -Path $ouQuarantine
$ouQDisabled  = Ensure-OU -Name "Disabled Objects" -Path $ouQuarantine

# --------------------------
# 2) Create Groups
# --------------------------
Write-Info "Creating standard groups..."

# Tier0 groups in Tier0\Admins\Groups
Ensure-Group -Name "T0-DomainAdmins" -Path $ouT0Groups -Scope Global -Description "Tier0 Admins (privileged)."
Ensure-Group -Name "T0-PKI-Admins"   -Path $ouT0Groups -Scope Global -Description "Tier0 PKI admins."
Ensure-Group -Name "T0-GPO-Admins"   -Path $ouT0Groups -Scope Global -Description "Tier0 GPO change approvers (GPOADmin)."

# Tier1 groups in Tier1\Server Admin Groups
Ensure-Group -Name "T1-ServerAdmins" -Path $ouT1Groups -Scope Global -Description "Tier1 Server Admins."
Ensure-Group -Name "T1-SQL-Admins"   -Path $ouT1Groups -Scope Global -Description "Tier1 SQL Admins."
Ensure-Group -Name "T1-Web-Admins"   -Path $ouT1Groups -Scope Global -Description "Tier1 Web/App Admins."

# Tier2 groups in Tier2\Workstation Admin Groups
Ensure-Group -Name "T2-WorkstationAdmins" -Path $ouT2Groups -Scope Global -Description "Tier2 Workstation Admins."
Ensure-Group -Name "T2-HelpDesk"          -Path $ouT2Groups -Scope Global -Description "Tier2 HelpDesk operators (least privilege)."

# Product administration groups (optional but useful)
Ensure-Group -Name "APP-ActiveRoles-Admins"     -Path $ouAppsQuest -Scope Global -Description "Active Roles admins."
Ensure-Group -Name "APP-GPOADmin-Admins"        -Path $ouAppsQuest -Scope Global -Description "GPOADmin admins."
Ensure-Group -Name "APP-ChangeAuditor-Admins"   -Path $ouAppsQuest -Scope Global -Description "Change Auditor admins."
Ensure-Group -Name "APP-PasswordManager-Admins" -Path $ouAppsQuest -Scope Global -Description "Password Manager admins."
Ensure-Group -Name "APP-IdentityX-Admins"       -Path $ouAppsQuest -Scope Global -Description "IdentityX admins."

# --------------------------
# 3) (Optional) Nesting suggestions
# --------------------------
Write-Info "Applying recommended group nesting (safe, optional)..."

# Example: T0-DomainAdmins can include product super-admins if you want (lab convenience).
# Comment out if you want strict separation.
Ensure-GroupMember -Group "T0-GPO-Admins" -Member "APP-GPOADmin-Admins"
Ensure-GroupMember -Group "T0-DomainAdmins" -Member "APP-ActiveRoles-Admins"

Write-Info "Done. OU structure + groups are ready."

Write-Info "Next recommended steps:"
Write-Info "1) Create service accounts in: $ouT1Svc"
Write-Info "2) Place servers in Tier1 OUs (Servers\\App/SQL/Web) and link baseline GPOs via GPOADmin."
Write-Info "3) Delegate Tier2 OUs to HelpDesk via Active Roles (Managed Units)."
