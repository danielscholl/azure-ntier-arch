<#
.SYNOPSIS
  Install the Full Infrastructure As Code Solution
.DESCRIPTION
  This Script will install all the infrastructure needed for the solution.

  1. Resource Group
  2. Virtual Network
  2. Storage Container
  3. Key Vault
  4. JumpBox Server
  5. Web Tier Servers
  6. App Tier Servers
  7. Data Tier Servers

.EXAMPLE
  .\install.ps1
  Version History
  v1.0   - Initial Release
#>
#Requires -Version 5.1
#Requires -Module @{ModuleName='AzureRM.Resources'; ModuleVersion='5.0'}

Param(
  [boolean] $Base = $false,
  [boolean] $DevOps = $false,
  [boolean] $Management = $false,
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

if ($Management -eq $true) {
  Write-Host "Install Management Resources here we go...." -foregroundcolor "cyan"
  & ./iac-publicVM/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Management Components have been installed!!!!!" -foregroundcolor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($DevOps -eq $true) {
  Write-Host "Install DevOps Resources here we go...." -foregroundcolor "cyan"
  & ./iac-automation/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "DevOps Components have been installed!!!!!" -foregroundcolor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($Servers -eq $true) {
  Write-Host "Install Server Resources here we go...." -foregroundcolor "cyan"
  & ./iac-privateVMas/install.ps1 -Subnet "web-tier" -VMName "web"
  # & ./iac-privateVMas/install.ps1 -Subnet "app-tier" -VMName "app"
  # & ./iac-privateVMas/install.ps1 -Subnet "data-tier" -VMName "db"

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Server Components have been installed!!!!!" -foregroundcolor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}
