<#
.SYNOPSIS
  Install the Full Infrastructure As Code Solution
.DESCRIPTION
  This Script will install the full Infrastructure.

  1. Resource Group
  2. Storage Container
  3. Key Vault
  4. Virtual Network

.EXAMPLE
  .\install.ps1
  Version History
  v1.0   - Initial Release
#>
#Requires -Version 5.1
#Requires -Module @{ModuleName='AzureRM.Resources'; ModuleVersion='5.0'}

Param(
  [boolean] $Base = $false,
  [boolean] $JumpBox = $false,
  [boolean] $Servers = $false
)
. ./.env.ps1
Get-ChildItem Env:AZURE*

if ($Base -eq $true) {
  Write-Host "Install Base Resources here we go...." -foregroundcolor "cyan"
  & ./iac-network/install.ps1
  & ./iac-storage/install.ps1
  & ./iac-keyvault/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Base Components have been installed!!!!!" -foregroundcolor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($JumpBox -eq $true) {
  Write-Host "Install Server Resources here we go...." -foregroundcolor "cyan"
  & ./iac-publicVM/install.ps1
}

if ($Servers -eq $true) {
  Write-Host "Install Server Resources here we go...." -foregroundcolor "cyan"
  & ./iac-privateVMas/install.ps1
}
