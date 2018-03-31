<#
    .DESCRIPTION
        This runbook starts all of the virtual machines in the specified Azure Resource Group.

    .PARAMETER ResourceGroupName
        Name of the Azure Resource Group containing the VMs to be started.

    .NOTES
        AUTHOR: Daniel Scholl
#>

Param(
  [string]$ResourceGroupName
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
    $ErrorMessage = "Connection $connectionName not found."
    throw $ErrorMessage
  }
  else {
    Write-Error -Message $_.Exception
    throw $_.Exception
  }
}

#---------Start Virtual Machines---------------
Write-Output "Retrieving Virtual Machines..."
$Machines = Get-AzureRmVM -ResourceGroupName $ResourceGroupName

if (!$Machines) {
  Write-Output "No Virtual Machines found in the Resource Group."
}
else {
  $Machines | ForEach-Object {
    $name = $_.Name
    Write-Output "Starting Server $name"
    Start-AzureRMVM -Name $name `
      -ResourceGroupName $ResourceGroupName
  }
}


#---------Start Virtual Machine Scale Sets---------------
$Machines = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName

if (!$Machines) {
  Write-Output "No VIrtual Machine Scale Sets found in the Resource Group."
}
else {
  $Machines | ForEach-Object {
    $name = $_.Name
    Write-Output "Starting Scale Set $name"
    Start-AzureRMVmss -Name $name `
      -ResourceGroupName $ResourceGroupName
  }
}
