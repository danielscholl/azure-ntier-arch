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
  8. Apply DSC Roles to Servers

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
  [boolean] $Manage = $false,
  [boolean] $Web = $false,
  [boolean] $App = $false,
  [boolean] $Db = $false,
  [boolean] $DSC = $false
)
. ./.env.ps1
Get-ChildItem Env:AZURE*

if ($Base -eq $true) {
  Write-Host "Install Base Resources here we go...." -ForegroundColor "cyan"
  & ./iac-network/install.ps1
  & ./iac-storage/install.ps1
  & ./iac-keyvault/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Base Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($DevOps -eq $true) {
  Write-Host "Install DevOps Resources here we go...." -ForegroundColor "cyan"
  & ./iac-automation/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "DevOps Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($Manage -eq $true) {
  Write-Host "Install Management Resources here we go...." -ForegroundColor "cyan"
  & ./iac-publicVM/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Management Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($Web -eq $true) {
  Write-Host "Install Web Server Resources here we go...." -ForegroundColor "cyan"
  & ./iac-privateVMas/install.ps1 -Subnet "web-tier" -VMName "web" -VMSize "Standard_DS1_v2"

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Web Server Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($App -eq $true) {
  Write-Host "Install App Server Resources here we go...." -ForegroundColor "cyan"
  & ./iac-privateVMas/install.ps1 -Subnet "app-tier" -VMName "app" -VMSize "Standard_DS2_v2"
  & ./iac-internalLB/install.ps1 -Subnet "app-tier" -IPAddress "10.0.1.126"

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "App Server Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($Db -eq $true) {
  Write-Host "Install DB Resources here we go...." -ForegroundColor "cyan"
  & ./iac-privateDBas/install.ps1 -Subnet "data-tier" -VMName "db" -VMSize "Standard_DS3_v2"
  & ./iac-internalLB/install.ps1 -Subnet "data-tier" -IPAddress "10.0.1.190"

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "DB Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($DSC -eq $true) {
  Enable-AzureRmContextAutosave
  Write-Host "Applying DSC Configurations here we go...." -ForegroundColor "cyan"
  & ./ext-dscNode/install.ps1 -VMName '*web*' -NodeConfiguration 'Frontend.Web'
  & ./ext-dscNode/install.ps1 -VMName '*app*' -NodeConfiguration 'Frontend.Web'
  & ./ext-dscNode/install.ps1 -VMName '*db*' -NodeConfiguration 'Backend.Database'


  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Background jobs for DSC Configs have been applied!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}