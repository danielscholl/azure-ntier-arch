<#
.SYNOPSIS
  Extension Component
.DESCRIPTION
  Register a Node to a DSC Configuration
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

  [Parameter(Mandatory = $true)]
  [string] $VmName,

  [Parameter(Mandatory = $true)]
  [string] $NodeConfiguration,

  [boolean] $Template = $false
)

if (Test-Path ..\scripts\functions.ps1) { . ..\scripts\functions.ps1 }
if (Test-Path .\scripts\functions.ps1) { . .\scripts\functions.ps1 }
if ( !$Subscription) { throw "Subscription Required" }
if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }

###############################
## Azure Intialize           ##
###############################
$BASE_DIR = Get-ScriptDirectory
$DEPLOYMENT = Split-Path $BASE_DIR -Leaf
LoginAzure

Write-Color -Text "Retrieving Storage Account and SAS Token Parameters..." -Color Green
$StorageAccountName = GetStorageAccount $ResourceGroupName
Write-Color -Text "$StorageAccountName" -Color White

$Token = GetSASToken $ResourceGroupName $StorageAccountName dsc
Write-Color -Text "$Token" -Color White

Write-Color -Text "Retrieving Automation Account information..." -Color Green
$AutomationAccount = (Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName).AutomationAccountName
Write-Color -Text "$AutomationAccount" -Color White

$Automation = Get-AzureRmAutomationRegistrationInfo -ResourceGroupName $ResourceGroupName -AutomationAccountName $AutomationAccount
$Registrationkey = ConvertTo-SecureString $Automation.PrimaryKey -asplaintext -force

##############################
## Deploy Template          ##
##############################
if ($Template -eq $true) {
  Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
  Write-Color -Text "Deploying ", "$DEPLOYMENT-$VmName ", "template..." -Color Green, Red, Green
  Write-Color -Text "---------------------------------------------------- "-Color Yellow
  New-AzureRmResourceGroupDeployment -Name "$DEPLOYMENT-$VmName" `
    -TemplateFile $BASE_DIR\azuredeploy.json `
    -TemplateParameterFile $BASE_DIR\azuredeploy.parameters.json `
    -storageAccountName $StorageAccountName -storageContainerName scripts -sasToken $Token `
    -registrationUrl $Automation.Endpoint -registrationKey $Registrationkey `
    -vmName $VmName -nodeConfigurationName $NodeConfiguration `
    -ResourceGroupName $ResourceGroupName
}
else {
  Get-AzureRMVM -ResourceGroupName $env:AZURE_GROUP | Where-Object { $_.Name -like $VmName } | `
    ForEach-Object {
    $Machine = $_.Name
    Add-NodesViaFilter $Machine $ResourceGroupName $AutomationAccount $ResourceGroupName $NodeConfiguration
  }
  
}

