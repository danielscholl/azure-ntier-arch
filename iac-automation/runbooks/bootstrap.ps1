<#
.SYNOPSIS
  Bootstrap master script Based off of Azure Optimization SDK
  https://github.com/Azure/azure-quickstart-templates/blob/master/azure-resource-optimization-toolkit/scripts/Bootstrap_Main.ps1
.DESCRIPTION
  Bootstrap master script for pre-configuring Automation Account
.EXAMPLE
  .\bootstrap.ps1
  Version History
  v1.0   - Initial Release
#>

function ValidateKeyVaultAndCreate([string] $keyVaultName, [string] $resourceGroup, [string] $KeyVaultLocation) {
  $GetKeyVault = Get-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroup -ErrorAction SilentlyContinue
  if (!$GetKeyVault) {
    Write-Warning -Message "Key Vault $keyVaultName not found. Creating the Key Vault $keyVaultName"
    $keyValut = New-AzureRmKeyVault -VaultName $keyVaultName -ResourceGroupName $resourceGroup -Location $keyVaultLocation
    if (!$keyValut) {
      Write-Error -Message "Key Vault $keyVaultName creation failed. Please fix and continue"
      return
    }
    $uri = New-Object System.Uri($keyValut.VaultUri, $true)
    $hostName = $uri.Host
    Start-Sleep -s 15
    # Note: This script will not delete the KeyVault created. If required, please delete the same manually.
  }
}

function CreateSelfSignedCertificate([string] $keyVaultName, [string] $certificateName, [string] $selfSignedCertPlainPassword, [string] $certPath, [string] $certPathCer, [string] $noOfMonthsUntilExpired ) {
  $certSubjectName = "cn=" + $certificateName

  $Policy = New-AzureKeyVaultCertificatePolicy -SecretContentType "application/x-pkcs12" -SubjectName $certSubjectName  -IssuerName "Self" -ValidityInMonths $noOfMonthsUntilExpired -ReuseKeyOnRenewal
  $AddAzureKeyVaultCertificateStatus = Add-AzureKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName -CertificatePolicy $Policy

  While ($AddAzureKeyVaultCertificateStatus.Status -eq "inProgress") {
    Start-Sleep -s 10
    $AddAzureKeyVaultCertificateStatus = Get-AzureKeyVaultCertificateOperation -VaultName $keyVaultName -Name $certificateName
  }

  if ($AddAzureKeyVaultCertificateStatus.Status -ne "completed") {
    Write-Error -Message "Key vault cert creation is not sucessfull and its status is: $status.Status"
  }

  $secretRetrieved = Get-AzureKeyVaultSecret -VaultName $keyVaultName -Name $certificateName
  $pfxBytes = [System.Convert]::FromBase64String($secretRetrieved.SecretValueText)
  $certCollection = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
  $certCollection.Import($pfxBytes, $null, [System.Security.Cryptography.X509Certificates.X509KeyStorageFlags]::Exportable)

  #Export  the .pfx file
  $protectedCertificateBytes = $certCollection.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Pkcs12, $selfSignedCertPlainPassword)
  [System.IO.File]::WriteAllBytes($certPath, $protectedCertificateBytes)

  #Export the .cer file
  $cert = Get-AzureKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName
  $certBytes = $cert.Certificate.Export([System.Security.Cryptography.X509Certificates.X509ContentType]::Cert)
  [System.IO.File]::WriteAllBytes($certPathCer, $certBytes)

  # Delete the cert after downloading
  $RemoveAzureKeyVaultCertificateStatus = Remove-AzureKeyVaultCertificate -VaultName $keyVaultName -Name $certificateName -PassThru -Force -ErrorAction SilentlyContinue -Confirm:$false
}

function CreateServicePrincipal([System.Security.Cryptography.X509Certificates.X509Certificate2] $PfxCert, [string] $applicationDisplayName) {
  $CurrentDate = Get-Date
  $keyValue = [System.Convert]::ToBase64String($PfxCert.GetRawCertData())
  $KeyId = [Guid]::NewGuid()

  $Application = New-AzureRmADApplication -DisplayName $ApplicationDisplayName -HomePage ("http://" + $applicationDisplayName) -IdentifierUris ("http://" + $KeyId)

  New-AzureRmADAppCredential -CertValue $keyvalue -StartDate $PfxCert.NotBefore -EndDate $PfxCert.NotAfter -ApplicationId $Application.ApplicationId.ToString()

  $ServicePrincipal = New-AzureRMADServicePrincipal -ApplicationId $Application.ApplicationId
  $GetServicePrincipal = Get-AzureRmADServicePrincipal -ObjectId $ServicePrincipal.Id

  # Sleep here for a few seconds to allow the service principal application to become active (should only take a couple of seconds normally)
  Start-Sleep -s 15
  New-AzureRmRoleAssignment -RoleDefinitionName Contributor -ServicePrincipalName $Application.ApplicationId | Write-Verbose -ErrorAction SilentlyContinue

  return $Application;
}

function CreateAutomationCertificateAsset ([string] $resourceGroup, [string] $automationAccountName, [string] $certifcateAssetName, [string] $certPath, [string] $certPlainPassword, [Boolean] $Exportable) {
  $CertPassword = ConvertTo-SecureString $certPlainPassword -AsPlainText -Force
  Remove-AzureRmAutomationCertificate -ResourceGroupName $resourceGroup -automationAccountName $automationAccountName -Name $certifcateAssetName -ErrorAction SilentlyContinue
  New-AzureRmAutomationCertificate -ResourceGroupName $resourceGroup -automationAccountName $automationAccountName -Path $certPath -Name $certifcateAssetName -Password $CertPassword -Exportable:$Exportable  | write-verbose
}

function CreateAutomationConnectionAsset ([string] $resourceGroup, [string] $automationAccountName, [string] $connectionAssetName, [string] $connectionTypeName, [System.Collections.Hashtable] $connectionFieldValues ) {
  Remove-AzureRmAutomationConnection -ResourceGroupName $resourceGroup -automationAccountName $automationAccountName -Name $connectionAssetName -Force -ErrorAction SilentlyContinue
  New-AzureRmAutomationConnection -ResourceGroupName $ResourceGroup -automationAccountName $automationAccountName -Name $connectionAssetName -ConnectionTypeName $connectionTypeName -ConnectionFieldValues $connectionFieldValues
}

try {
  Write-Output "Bootstrap main script execution started..."

  Write-Output "Checking for the RunAs account..."

  $servicePrincipalConnection = Get-AutomationConnection -Name 'AzureRunAsConnection' -ErrorAction SilentlyContinue

  #---------Inputs variables for NewRunAsAccountCertKeyVault.ps1 child bootstrap script--------------
  $automationAccountName = Get-AutomationVariable -Name 'automationAccountName'
  $SubscriptionId = Get-AutomationVariable -Name 'azureSubscriptionId'
  $ResourceGroupName = Get-AutomationVariable -Name 'omsResourceGroupName'

  if ($servicePrincipalConnection -eq $null) {
    #---------Read the Credentials variable---------------
    $myCredential = Get-AutomationPSCredential -Name 'AzureCredentials'
    $AzureLoginUserName = $myCredential.UserName
    $securePassword = $myCredential.Password
    $AzureLoginPassword = $myCredential.GetNetworkCredential().Password

    #++++++++++++++++++++++++RUN_AS execution starts++++++++++++++++++++++++++

    #In RUN_AS we are creating keyvault to generate cert and creating runas account...

    Write-Output "Executing RUN_AS : Create the keyvault certificate and connection asset..."

    Write-Output "RunAsAccount Creation Started..."

    try {
      Write-Output "Logging into Azure Subscription..."

      #-----L O G I N - A U T H E N T I C A T I O N-----
      $secPassword = ConvertTo-SecureString $AzureLoginPassword -AsPlainText -Force
      $AzureOrgIdCredential = New-Object System.Management.Automation.PSCredential($AzureLoginUserName, $secPassword)
      Login-AzureRmAccount -Credential $AzureOrgIdCredential
      Get-AzureRmSubscription -SubscriptionId $SubscriptionId | Select-AzureRmSubscription
      Write-Output "Successfully logged into Azure Subscription..."

      [String] $ApplicationDisplayName = "$($automationAccountName)-app"
      [Boolean] $CreateClassicRunAsAccount = $false
      [String] $SelfSignedCertPlainPassword = [Guid]::NewGuid().ToString().Substring(0, 8) + "!"
      [String] $KeyVaultName = "KeyVault" + [Guid]::NewGuid().ToString().Substring(0, 5)
      [int] $NoOfMonthsUntilExpired = 36

      $RG = Get-AzureRmResourceGroup -Name $ResourceGroupName
      $KeyVaultLocation = $RG[0].Location

      # Create Run As Account using Service Principal
      $CertifcateAssetName = "AzureRunAsCertificate"
      $ConnectionAssetName = "AzureRunAsConnection"
      $ConnectionTypeName = "AzureServicePrincipal"

      Write-Output "Creating Keyvault for generating cert..."
      Write-Output " $KeyVaultName $ResourceGroupName $KeyVaultLocation "
      ValidateKeyVaultAndCreate $KeyVaultName $ResourceGroupName $KeyVaultLocation

      $CertificateName = $automationAccountName + $CertifcateAssetName
      $PfxCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".pfx")
      $PfxCertPlainPasswordForRunAsAccount = $SelfSignedCertPlainPassword
      $CerCertPathForRunAsAccount = Join-Path $env:TEMP ($CertificateName + ".cer")

      Write-Output "Generating the cert using Keyvault..."
      CreateSelfSignedCertificate $KeyVaultName $CertificateName $PfxCertPlainPasswordForRunAsAccount $PfxCertPathForRunAsAccount $CerCertPathForRunAsAccount $NoOfMonthsUntilExpired

      Write-Output "Creating service principal..."
      # Create Service Principal
      $PfxCert = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Certificate2 -ArgumentList @($PfxCertPathForRunAsAccount, $PfxCertPlainPasswordForRunAsAccount)
      $Application = CreateServicePrincipal $PfxCert $ApplicationDisplayName

      Write-Output "Creating Certificate in the Asset..."
      # Create the automation certificate asset
      CreateAutomationCertificateAsset $ResourceGroupName $automationAccountName $CertifcateAssetName $PfxCertPathForRunAsAccount $PfxCertPlainPasswordForRunAsAccount $true

      #Populate the ConnectionFieldValues
      $SubscriptionInfo = Get-AzureRmSubscription -SubscriptionId $SubscriptionId
      $TenantID = $SubscriptionInfo | Select-Object TenantId -First 1
      $Thumbprint = $PfxCert.Thumbprint
      $ConnectionFieldValues = @{"ApplicationId" = $Application.ApplicationId; "TenantId" = $TenantID.TenantId; "CertificateThumbprint" = $Thumbprint; "SubscriptionId" = $SubscriptionId}

      Write-Output "Creating Connection in the Asset..."
      # Create a Automation connection asset named AzureRunAsConnection in the Automation account. This connection uses the service principal.
      CreateAutomationConnectionAsset $ResourceGroupName $automationAccountName $ConnectionAssetName $ConnectionTypeName $ConnectionFieldValues

      Write-Output "RunAsAccount Creation Completed..."

      Write-Output "Completed Step-1 ..."
    }
    catch {
      Write-Output "Error Occurred on Step-1..."
      Write-Output $_.Exception
      Write-Error $_.Exception
      exit
    }
  }
  else {
    Write-Output "RunAs account already available..."
    $connectionName = "AzureRunAsConnection"

    try {
      # Get the connection "AzureRunAsConnection "
      $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName

      Get-AutomationConnection -Name $connectionName
      "Logging in to Azure..."
      Add-AzureRmAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
    }
    catch {
      if (!$servicePrincipalConnection) {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
      }
      else {
        Write-Error -Message $_.Exception
        throw $_.Exception
        exit
      }
    }
  }

  #++++++++++++++++++++++++RUN_AS execution ends++++++++++++++++++++++++++

  #=======================CLEAN UP execution starts===========================

  #In CLEANUP we are deleting the runbook, Credential asset variable, and Keyvault...
  try {
    Write-Output "Executing CLEANUP : Performing clean up tasks (Bootstrap script, Bootstrap Schedule, Credential asset variable, and Keyvault) ..."

    if ($KeyVaultName -ne $null) {
      Write-Output "Removing the Keyvault : ($($KeyVaultName))..."
      Remove-AzureRmKeyVault -VaultName $KeyVaultName -ResourceGroupName $ResourceGroupName -Confirm:$False -Force
    }

    $checkCredentials = Get-AzureRmAutomationCredential -Name "AzureCredentials" -automationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if ($checkCredentials -ne $null) {
      Write-Output "Removing the Azure Credentials..."
      Remove-AzureRmAutomationCredential -Name "AzureCredentials" -automationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName
    }

    $checkScheduleBootstrap = Get-AzureRmAutomationSchedule -automationAccountName $automationAccountName -Name "bootstrapSchedule" -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue

    if ($checkScheduleBootstrap -ne $null) {
      Write-Output "Removing Bootstrap Schedule..."
      Remove-AzureRmAutomationSchedule -Name "bootstrapSchedule" -automationAccountName $automationAccountName -ResourceGroupName $ResourceGroupName -Force
    }
  }
  catch {
    Write-Output "Error Occurred in Cleanup..."
    Write-Output $_.Exception
    Write-Error $_.Exception
  }

}
catch {
  Write-Output "Error Occured in Boostrap Wrapper..."
  Write-Output $_.Exception
  Write-Error $_.Exception
}
