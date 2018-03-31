<#
    .DESCRIPTION
        This runbook scales up an App Service Plan in an Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the App Plan to be scaled.

    .NOTES
        AUTHOR: Daniel Scholl
#>

Param(
  [string]$resourceGroupName,
  [string]$sku,
  [string]$size = "Small"
)

$connectionName = "AzureRunAsConnection"

try {
  #---------Read the Credentials variable---------------
  # Get the connetion  "AzureRunAsConnection"
  $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

  #-----L O G I N - A U T H E N T I C A T I O N-----
  Write-Output "Logging into Azure Account..."

  Add-AzureRmAccount `
    -ServicePrincipal `
    -TenantId $servicePrincipalConnection.TenantId `
    -ApplicationId $servicePrincipalConnection.ApplicationId `
    -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint

  Write-Output "Successfully logged into Azure Subscription..."
}
catch {
  if (!$servicePrincipalConnection) {
    $errorMessage = "Connection $connectionName not found."
    throw $errorMessage
  }
  else {
    Write-Error -Message $_.Exception
    throw $_.Exception
  }
}

#---------Start Virtual Machines---------------
Write-Output "Retrieving App Service Plans..."
$plans = Get-AzureRmAppServicePlan -ResourceGroupName $resourceGroupName

if (!$plans) {
  Write-Output "No App Service Plan found in the Resource Group."
}
else {
  $plans | ForEach-Object {
    $name = $_.Name
    Write-Output "Scaling Down $name"
    Set-AzureRmAppServicePlan -Name $name `
      -ResourceGroupName $resourceGroupName `
      -Tier $sku `
      -Workersize $size
  }
}