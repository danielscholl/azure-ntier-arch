<#
.SYNOPSIS
  Infrastructure as Code Component
.DESCRIPTION
  Install a Private Virtual Machine
.EXAMPLE
  .\install.ps1
  Version History
  v1.0   - Initial Release
#>
#Requires -Version 5.1
#Requires -Module @{ModuleName='AzureRM.Resources'; ModuleVersion='5.0'}

Param(
  [string] $Subscription = $env:AZURE_SUBSCRIPTION,
  [string] $ResourceGroupName = $env:AZURE_GROUP,
  [string] $Location = $env:AZURE_LOCATION,
  [string] $Subnet = "web-tier",
  [string] $VMSize = "Standard_DS3_v2",
  [string] $VMName = "web",
  [string] $Image = $false,
  [string] $ImageGroup = $env:AZURE_DEVOPS,
  [string] $ImageName = $env:AZURE_SERVER_IMAGE
)

if (Test-Path ..\scripts\functions.ps1) { . ..\scripts\functions.ps1 }
if (Test-Path .\scripts\functions.ps1) { . .\scripts\functions.ps1 }
if ( !$Subscription) { throw "Subscription Required" }
if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }
if ( !$Location) { throw "Location Required" }

if (( $ImageGroup ) -and ( $ImageName ) -and ( $Image -eq $true )) {
  $UseImage = "Yes"
}
else {
  $UseImage = "No"
}

###############################
## Azure Intialize           ##
###############################
$BASE_DIR = Get-ScriptDirectory
$DEPLOYMENT = Split-Path $BASE_DIR -Leaf
LoginAzure
CreateResourceGroup $ResourceGroupName $Location

Write-Color -Text "Registering Provider..." -Color Yellow
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Compute

##############################
## Deploy Template          ##
##############################
Write-Color -Text "Gathering information for Key Vault..." -Color Green
$VaultName = GetKeyVault $ResourceGroupName

Write-Color -Text "Retrieving Diagnostic Storage Account Parameters..." -Color Green
$StorageAccountName = GetStorageAccount $ResourceGroupName

$StorageAccountKey = GetStorageAccountKey $ResourceGroupName $StorageAccountName
$SecureStorageKey = $StorageAccountKey | ConvertTo-SecureString -AsPlainText -Force
Write-Color -Text "$StorageAccountName  $StorageAccountKey" -Color White

Write-Color -Text "Retrieving Credential Parameters..." -Color Green
Write-Color -Text "Retrieving Credential Parameters..." -Color Green
$AdminUserName = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name 'adminUserName').SecretValueText
$AdminPassword = (Get-AzureKeyVaultSecret -VaultName $VaultName -Name 'adminPassword').SecretValue
Write-Color -Text "$AdminUserName\*************" -Color White

Write-Color -Text "Retrieving Virtual Network Parameters..." -Color Green
$VirtualNetworkName = "${ResourceGroupName}-vnet"
Write-Color -Text "$ResourceGroupName  $VirtualNetworkName $Subnet" -Color White

if ($UseImage -eq "Yes" ) {
  Write-Color -Text "Retrieving Image Parameters..." -Color Green
  $ManagedImage = Get-AzureRmImage -ResourceGroupName $ImageGroup -ImageName $ImageName
}
else {
  $ManagedImage = @{}
  $ManagedImage.Id = "/NoImage"
}


Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
Write-Color -Text "Deploying ", "$DEPLOYMENT ", "template..." -Color Green, Red, Green
Write-Color -Text "---------------------------------------------------- "-Color Yellow

Write-Color -Text "Private Virtual Machines Servers..." -Color Green

$Servers = @("web")

ForEach ($vmName in $Servers) {
  New-AzureRmResourceGroupDeployment -Name "$DEPLOYMENT-$VMName" `
    -TemplateFile $BASE_DIR\azuredeploy.json `
    -TemplateParameterFile $BASE_DIR\azuredeploy.parameters.json `
    -prefix $ResourceGroupName `
    -managedImageId $ManagedImage.Id -useImage $UseImage `
    -vmName $VMName -vmSize $VMSize `
    -diagnosticsStorageName $StorageAccountName -diagnosticsStorageKey $SecureStorageKey `
    -adminUserName $AdminUserName -adminPassword $AdminPassword `
    -vnetGroup $ResourceGroupName -vnet $VirtualNetworkName -subnet $Subnet `
    -ResourceGroupName $ResourceGroupName
}
