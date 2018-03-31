<#
.SYNOPSIS
  Connects to Azure and vertically scales down the VM

.DESCRIPTION
  This runbook connects to Azure and scales down the VM

  REQUIRED AUTOMATION ASSETS
  1. An Automation variable asset called "AzureSubscriptionId" that contains the GUID for this Azure subscription of the VM.
  2. An Automation credential asset called "AzureCredential" that contains the Azure AD user credential with authorization for this subscription.

.PARAMETER WebhookData
   Required
   This is the data that is sent in the webhook that is triggered from the VM alert rules

.NOTES
   AUTHOR: Azure Compute Team
   LASTEDIT: March 27, 2016
#>

param (
  [parameter(Mandatory = $true)]
  [object]$WebhookData
)

if ($WebhookData -ne $null) {
  # Returns strings with status messages
  [OutputType([String])]

  # Collect properties of WebhookData.
  $WebhookBody = $WebhookData.RequestBody

  # Obtain the WebhookBody containing the AlertContext
  $WebhookBody = (ConvertFrom-Json -InputObject $WebhookBody)

  if ($WebhookBody.status -eq "Activated") {
    # Obtain the AlertContext
    $AlertContext = [object]$WebhookBody.context

    $ResourceGroupName = $AlertContext.resourceGroupName
    $VmName = $AlertContext.resourceName

    $noResize = "noresize"

    $scaleDown = @{
      "Standard_A0"     = $noResize
      "Standard_A1"     = "Standard_A0"
      "Standard_A2"     = "Standard_A1"
      "Standard_A3"     = "Standard_A2"
      "Standard_A4"     = "Standard_A3"
      "Standard_A5"     = $noResize
      "Standard_A6"     = "Standard_A5"
      "Standard_A7"     = "Standard_A6"
      "Standard_A8"     = $noResize
      "Standard_A9"     = "Standard_A8"
      "Standard_A10"    = $noResize
      "Standard_A11"    = "Standard_A10"
      "Basic_A0"        = $noResize
      "Basic_A1"        = "Basic_A0"
      "Basic_A2"        = "Basic_A1"
      "Basic_A3"        = "Basic_A2"
      "Basic_A4"        = "Basic_A3"
      "Standard_D1_v2"  = $noResize
      "Standard_D2_v2"  = "Standard_D1_v2"
      "Standard_D3_v2"  = "Standard_D2_v2"
      "Standard_D4_v2"  = "Standard_D3_v2"
      "Standard_D5_v2"  = "Standard_D4_v2"
      "Standard_D11_v2" = $noResize
      "Standard_D12_v2" = "Standard_D11_v2"
      "Standard_D13_v2" = "Standard_D12_v2"
      "Standard_D14_v2" = "Standard_D13_v2"
      "Standard_DS1"    = $noResize
      "Standard_DS2"    = "Standard_DS1"
      "Standard_DS3"    = "Standard_DS2"
      "Standard_DS4"    = "Standard_DS3"
      "Standard_DS11"   = $noResize
      "Standard_DS12"   = "Standard_DS11"
      "Standard_DS13"   = "Standard_DS12"
      "Standard_DS14"   = "Standard_DS13"
      "Standard_D1"     = $noResize
      "Standard_D2"     = "Standard_D1"
      "Standard_D3"     = "Standard_D2"
      "Standard_D4"     = "Standard_D3"
      "Standard_D11"    = $noResize
      "Standard_D12"    = "Standard_D11"
      "Standard_D13"    = "Standard_D12"
      "Standard_D14"    = "Standard_D13"
      "Standard_G1"     = $noResize
      "Standard_G2"     = "Standard_G1"
      "Standard_G3"     = "Standard_G2"
      "Standard_G4"     = "Standard_G3"
      "Standard_G5"     = "Standard_G4"
      "Standard_GS1"    = $noResize
      "Standard_GS2"    = "Standard_GS1"
      "Standard_GS3"    = "Standard_GS2"
      "Standard_GS4"    = "Standard_GS3"
      "Standard_GS5"    = "Standard_GS4"
    }


    # Connect to Azure and select the subscription to work against
    $Cred = Get-AutomationPSCredential -Name 'AzureCredential'
    $null = Add-AzureRmAccount -Credential $Cred -ErrorAction Stop

    $SubId = Get-AutomationVariable -Name 'AzureSubscriptionId'
    $null = Set-AzureRmContext -SubscriptionId $SubId -ErrorAction Stop

    try {
		    $vm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -VMName $VmName -ErrorAction Stop
    }
    catch {
		    Write-Error "Virtual Machine not found"
		    exit
    }
    $currentVMSize = $vm.HardwareProfile.vmSize

    Write-Output "`nFound the specified Virtual Machine: $VmName"
    Write-Output "Current size: $currentVMSize"

    $newVMSize = ""

    $newVMSize = $scaleDown[$currentVMSize]

    if ($newVMSize -eq $noResize) {
		    Write-Output "Sorry the current Virtual Machine size $currentVMSize can't be scaled $scaleAction. You'll need to recreate the specified Virtual Machine with your requested size"
    }
    else {
		    Write-Output "`nNew size will be: $newVMSize"

      $vm.HardwareProfile.VmSize = $newVMSize
		    Update-AzureRmVm -VM $vm -ResourceGroupName $ResourceGroupName

		    $updatedVm = Get-AzureRmVm -ResourceGroupName $ResourceGroupName -VMName $VmName
		    $updatedVMSize = $updatedVm.HardwareProfile.vmSize

		    Write-Output "`nSize updated to: $updatedVMSize"
    }
  }
  else {
    Write-Output "`nAlert not activated"
    exit
  }
}
else {
  Write-Error "This runbook is meant to only be started from a webhook."
}
