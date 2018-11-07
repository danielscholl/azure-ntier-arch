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
  [boolean] $Infra = $false,
  [boolean] $Config = $false
)
. ./.env.ps1
Get-ChildItem Env:AZURE*

if ($Base -eq $true) {
  Write-Host "Install Base Resources here we go...." -ForegroundColor "cyan"
  & ./iac-network/install.ps1
  & ./iac-storage/install.ps1
  & ./iac-keyvault/install.ps1
  & ./iac-automation/install.ps1

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Base Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}

if ($Infra -eq $true) {
  Write-Host "Install Infrastructure Resources here we go...." -ForegroundColor "cyan"
  & ./iac-publicVM/install.ps1

  & ./iac-privateVMas/install.ps1 -Subnet "web-tier" -VMName "web" -VMSize "Standard_DS1_v2"
  & ./iac-appGateway/install.ps1

  & ./iac-privateVMas/install.ps1 -Subnet "app-tier" -VMName "app" -VMSize "Standard_DS2_v2"
  & ./iac-internalLB/install.ps1 -Subnet "app-tier" -IPAddress "10.0.1.126"

  & ./iac-privateDBas/install.ps1 -Subnet "data-tier" -VMName "db" -VMSize "Standard_DS3_v2"
  & ./iac-internalLB/install.ps1 -Subnet "data-tier" -IPAddress "10.0.1.190"

  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Infrastucture Components have been installed!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}


if ($Config -eq $true) {
  Enable-AzureRmContextAutosave
  Write-Host "Applying DSC Configurations here we go...." -ForegroundColor "cyan"
  & ./ext-dscNode/install.ps1 -VMName '*web*' -NodeConfiguration 'Frontend.Web'
  & ./ext-dscNode/install.ps1 -VMName '*app*' -NodeConfiguration 'Frontend.App'
  & ./ext-dscNode/install.ps1 -VMName '*db*' -NodeConfiguration 'Backend.Database'


  Write-Host "---------------------------------------------" -ForegroundColor "blue"
  Write-Host "Background jobs for DSC Configs have been applied!!!!!" -ForegroundColor "red"
  Write-Host "---------------------------------------------" -ForegroundColor "blue"
}
