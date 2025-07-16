# AD-Lab-Bootstrap

This repository contains a collection of PowerShell scripts to automate the deployment and configuration of a Windows Server Domain Controller in lab environments.

---

## 📂 Scripts

| Script Name        | Description                                                         |
|--------------------|---------------------------------------------------------------------|
| `installation.ps1` | Installs the AD DS role and creates a new domain (e.g., `lab.local`) |
| `configuration.ps1`| Sets static IP, DNS, and computer name configuration                |
| `openFirewall.ps1` | Enables all necessary Windows Firewall rules for DC functionality   |

---

## 🚀 Usage

## 1. Clone the repository:

## 2. Run each script in sequence from an elevated (Administrator) PowerShell session:

.\configuration.ps1
.\installation.ps1
.\openFirewall.ps1
Follow prompts (especially for the DSRM password in the installation phase).

What This Sets Up?
- Static network configuration
- Domain Controller with DNS role
- lab.local domain (customizable)
- All required firewall ports for Active Directory, DNS, and remote access

## Disclaimer
These scripts are intended for **lab use only** and are not production-hardened.
If you plan to use these in production environments, please ensure proper hardening, replication, backup, and security policies are applied.

