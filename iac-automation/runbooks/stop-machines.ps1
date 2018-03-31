<#
    .DESCRIPTION
        This runbook stops all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be started.

    .NOTES
        AUTHOR: Daniel Scholl
#>

Param(
  [string]$resourceGroupName
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
Write-Output "Retrieving Virtual Machines..."
$machines = Get-AzureRmVM -ResourceGroupName $resourceGroupName

if (!$machines) {
  Write-Output "No Virtual Machines found in the Resource Group."
}
else {
  $machines | ForEach-Object {
    $name = $_.Name
    Write-Output "Stopping Server $name"
    Stop-AzureRMVM -Name $name `
      -ResourceGroupName $resourceGroupName `
      -Force
  }
}


#---------Start Virtual Machine Scale Sets---------------
Write-Output "Retrieving Virtual Machine Scale Sets..."
$scaleSets = Get-AzureRmVmss -ResourceGroupName $resourceGroupName

if (!$scaleSets) {
  Write-Output "No Virtual Machine Scale Sets found in the Resource Group."
}
else {
  $scaleSets | ForEach-Object {
    $name = $_.Name
    Write-Output "Stopping Scale Set $name"
    Stop-AzureRMVmss -VMScaleSetName $name `
      -ResourceGroupName $resourceGroupName `
      -Force
  }
}
