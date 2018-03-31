<#
.SYNOPSIS
  Infrastructure as Code Component
.DESCRIPTION
  Install an Azure Automation Account linked to Artifacts Storage for DSC and Runbooks
.EXAMPLE
  .\install.ps1
  Version History
  v1.0   - Initial Release
#>
#Requires -Version 5.1
#Requires -Module @{ModuleName='AzureRM.Resources'; ModuleVersion='5.0'}

Param(
  [string] $Subscription = $env:AZURE_SUBSCRIPTION,
  [string] $Location = $env:AZURE_LOCATION,
  [string] $ResourceGroupName = $env:AZURE_GROUP
)

if (Test-Path ..\scripts\functions.ps1) { . ..\scripts\functions.ps1 }
if (Test-Path .\scripts\functions.ps1) { . .\scripts\functions.ps1 }
if ( !$Subscription) { throw "Subscription Required" }
if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }
if ( !$Location) { throw "Location Required" }


###############################
## Azure Intialize           ##
###############################
$BASE_DIR = Get-ScriptDirectory
$DEPLOYMENT = Split-Path $BASE_DIR -Leaf
LoginAzure
CreateResourceGroup $ResourceGroupName $Location

Write-Color -Text "Registering Provider..." -Color Yellow
Register-AzureRmResourceProvider -ProviderNamespace Microsoft.Automation


Write-Color -Text "Retrieving Storage Account Information..." -Color Green
$StorageAccountName = GetStorageAccount $ResourceGroupName

##############################
## Sync dsc artifacts       ##
##############################
$DIRECTORY = "dsc"
Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
Write-Color -Text "Uploading ", "$DIRECTORY ", "artifacts..." -Color Green, Red, Green
Write-Color -Text "---------------------------------------------------- "-Color Yellow

Write-Color -Text "Creating Container for $DIRECTORY..." -Color Yellow
Create-Container $ResourceGroupName $DIRECTORY

$files = @(Get-ChildItem $BASE_DIR\$DIRECTORY)
foreach ($file in $files) {
  Upload-File $ResourceGroupName $DIRECTORY $BASE_DIR\$DIRECTORY\$file
}

##############################
## Sync dsc artifacts       ##
##############################
$DIRECTORY = "runbooks"
Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
Write-Color -Text "Uploading ", "$DIRECTORY ", "artifacts..." -Color Green, Red, Green
Write-Color -Text "---------------------------------------------------- "-Color Yellow

Write-Color -Text "Creating Container for $DIRECTORY..." -Color Yellow
Create-Container $ResourceGroupName $DIRECTORY

$files = @(Get-ChildItem $BASE_DIR\$DIRECTORY)
foreach ($file in $files) {
  Upload-File $ResourceGroupName $DIRECTORY $BASE_DIR\$DIRECTORY\$file
}

Write-Color -Text "Retrieving Storage Account SAS Tokens..." -Color Green
Write-Color -Text "$StorageAccountName" -Color White
$RunBookToken = GetSASToken $ResourceGroupName $StorageAccountName runbooks

Write-Color -Text "$RunBookToken" -Color White
$DscToken = GetSASToken $ResourceGroupName $StorageAccountName dsc
Write-Color -Text "$DscToken" -Color White


##############################
## Deploy Template          ##
##############################
Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
Write-Color -Text "Deploying ", "$DEPLOYMENT ", "template..." -Color Green, Red, Green
Write-Color -Text "---------------------------------------------------- "-Color Yellow
New-AzureRmResourceGroupDeployment -Name $DEPLOYMENT `
  -TemplateFile $BASE_DIR\azuredeploy.json `
  -TemplateParameterFile $BASE_DIR\azuredeploy.parameters.json `
  -prefix $ResourceGroupName -storageAccountName $StorageAccountName `
  -subscriptionAdmin $(Get-AzureRmContext).Account.Id -domainAdmin "domain_admin"  `
  -runbookSasToken $RunBookToken -dscSasToken $DscToken `
  -jobGuid1 (New-Guid).Guid -jobGuid2 (New-Guid).Guid -jobGuid3 (New-Guid).Guid `
  -ResourceGroupName $ResourceGroupName
