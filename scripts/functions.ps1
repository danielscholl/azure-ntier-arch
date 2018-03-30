###############################
## FUNCTIONS                 ##
###############################
function Write-Color([String[]]$Text, [ConsoleColor[]]$Color = "White", [int]$StartTab = 0, [int] $LinesBefore = 0, [int] $LinesAfter = 0, [string] $LogFile = "", $TimeFormat = "yyyy-MM-dd HH:mm:ss") {
  # version 0.2
  # - added logging to file
  # version 0.1
  # - first draft
  #
  # Notes:
  # - TimeFormat https://msdn.microsoft.com/en-us/library/8kb3ddd4.aspx

  $DefaultColor = $Color[0]
  if ($LinesBefore -ne 0) {  for ($i = 0; $i -lt $LinesBefore; $i++) { Write-Host "`n" -NoNewline } } # Add empty line before
  if ($StartTab -ne 0) {  for ($i = 0; $i -lt $StartTab; $i++) { Write-Host "`t" -NoNewLine } }  # Add TABS before text
  if ($Color.Count -ge $Text.Count) {
    for ($i = 0; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine }
  }
  else {
    for ($i = 0; $i -lt $Color.Length ; $i++) { Write-Host $Text[$i] -ForegroundColor $Color[$i] -NoNewLine }
    for ($i = $Color.Length; $i -lt $Text.Length; $i++) { Write-Host $Text[$i] -ForegroundColor $DefaultColor -NoNewLine }
  }
  Write-Host
  if ($LinesAfter -ne 0) {  for ($i = 0; $i -lt $LinesAfter; $i++) { Write-Host "`n" } }  # Add empty line after
  if ($LogFile -ne "") {
    $TextToFile = ""
    for ($i = 0; $i -lt $Text.Length; $i++) {
      $TextToFile += $Text[$i]
    }
    Write-Output "[$([datetime]::Now.ToString($TimeFormat))]$TextToFile" | Out-File $LogFile -Encoding unicode -Append
  }
}
function Get-ScriptDirectory {
  $Invocation = (Get-Variable MyInvocation -Scope 1).Value
  Split-Path $Invocation.MyCommand.Path
}
function LoginAzure() {
  Write-Color -Text "Logging in and setting subscription..." -Color Green
  if ([string]::IsNullOrEmpty($(Get-AzureRmContext).Account)) {
    if($env:AZURE_TENANT) {
      Login-AzureRmAccount -TenantId $env:AZURE_TENANT
    } else {
      Login-AzureRmAccount
    }
  }
  Set-AzureRmContext -SubscriptionId ${Subscription} | Out-null

}
function CreateResourceGroup([string]$ResourceGroupName, [string]$Location) {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = LOCATION

  Get-AzureRmResourceGroup -Name $ResourceGroupName -ev notPresent -ea 0 | Out-null

  if ($notPresent) {

    Write-Host "Creating Resource Group $ResourceGroupName..." -ForegroundColor Yellow
    New-AzureRmResourceGroup -Name $ResourceGroupName -Location $Location
  }
  else {
    Write-Color -Text "Resource Group ", "$ResourceGroupName ", "already exists." -Color Green, Red, Green
  }
}
function Add-Secret ([string]$ResourceGroupName, [string]$SecretName, [securestring]$SecretValue) {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = SECRET_NAME
  # Required Argument $3 = RESOURCE_VALUE

  $KeyVault = Get-AzureRmKeyVault -ResourceGroupName $ResourceGroupName
  if (!$KeyVault) {
    Write-Error -Message "Key Vault in $ResourceGroupName not found. Please fix and continue"
    return
  }

  Write-Color -Text "Saving Secret ", "$SecretName", "..." -Color Green, Red, Green
  Set-AzureKeyVaultSecret -VaultName $KeyVault.VaultName -Name $SecretName -SecretValue $SecretValue
}
function GetStorageAccount([string]$ResourceGroupName) {
  # Required Argument $1 = RESOURCE_GROUP

  if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }

  return (Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName).StorageAccountName
}

function GetAutomationAccount([string]$ResourceGroupName) {
  # Required Argument $1 = RESOURCE_GROUP

  if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }

  return (Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroupName).AutomationAccountName
}
function GetStorageAccountKey([string]$ResourceGroupName, [string]$StorageAccountName) {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = STORAGE_ACCOUNT

  if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }
  if ( !$StorageAccountName) { throw "StorageAccountName Required" }

  return (Get-AzureRmStorageAccountKey -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName).Value[0]
}
function GetKeyVault([string]$ResourceGroupName) {
  # Required Argument $1 = RESOURCE_GROUP

  if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }

  return (Get-AzureRmKeyVault -ResourceGroupName $ResourceGroupName).VaultName
}
function Create-Container ($ResourceGroupName, $ContainerName, $Access = "Off") {
  # Required Argument $1 = RESOURCE_GROUP
  # Required Argument $2 = CONTAINER_NAME

  # Get Storage Account
  $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
  if (!$StorageAccount) {
    Write-Error -Message "Storage Account in $ResourceGroupName not found. Please fix and continue"
    return
  }

  $Keys = Get-AzureRmStorageAccountKey -Name $StorageAccount.StorageAccountName -ResourceGroupName $ResourceGroupName
  $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccount.StorageAccountName -StorageAccountKey $Keys[0].Value

  $Container = Get-AzureStorageContainer -Name $ContainerName -Context $StorageContext -ErrorAction SilentlyContinue
  if (!$Container) {
    Write-Warning -Message "Storage Container $ContainerName not found. Creating the Container $ContainerName"
    New-AzureStorageContainer -Name $ContainerName -Context $StorageContext -Permission $Access
  }
}
function Upload-File ($ResourceGroupName, $ContainerName, $FileName, $BlobName) {

  # Get Storage Account
  $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName
  if (!$StorageAccount) {
    Write-Error -Message "Storage Account in $ResourceGroupName not found. Please fix and continue"
    return
  }

  $Keys = Get-AzureRmStorageAccountKey -Name $StorageAccount.StorageAccountName `
    -ResourceGroupName $ResourceGroupName

  $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccount.StorageAccountName `
    -StorageAccountKey $Keys[0].Value

  ### Upload a file to the Microsoft Azure Storage Blob Container
  Write-Output "Uploading $BlobName..."
  $UploadFile = @{
    Context   = $StorageContext;
    Container = $ContainerName;
    File      = $FileName;
    Blob      = $BlobName;
  }

  Set-AzureStorageBlobContent @UploadFile -Force;
}
function GetSASToken ($ResourceGroupName, $StorageAccountName, $ContainerName) {

  # Get Storage Account
  $StorageAccount = Get-AzureRmStorageAccount -ResourceGroupName $ResourceGroupName -Name $StorageAccountName
  if (!$StorageAccount) {
    Write-Error -Message "Storage Account in $ResourceGroupName not found. Please fix and continue"
    return
  }

  $Keys = Get-AzureRmStorageAccountKey -Name $StorageAccount.StorageAccountName `
    -ResourceGroupName $ResourceGroupName

  $StorageContext = New-AzureStorageContext -StorageAccountName $StorageAccount.StorageAccountName `
    -StorageAccountKey $Keys[0].Value

  return New-AzureStorageContainerSASToken -Name $ContainerName -Context $StorageContext -Permission r -ExpiryTime (Get-Date).AddMinutes(20)
}
function Import-DscConfiguration ($script, $config, $ResourceGroup, $Force) {

  $AutomationAccount = (Get-AzureRmAutomationAccount -ResourceGroupName $ResourceGroup).AutomationAccountName

  $dscConfig = Join-Path $DscPath ($script + ".ps1")
  $dscDataConfig = Join-Path $DscPath $config

  $dscConfigFile = (Get-Item $dscConfig).FullName
  $dscConfigFileName = [io.path]::GetFileNameWithoutExtension($dscConfigFile)

  $dscDataConfigFile = (Get-Item $dscDataConfig).FullName
  $dscDataConfigFileName = [io.path]::GetFileNameWithoutExtension($dscDataConfigFile)

  $dsc = Get-AzureRmAutomationDscConfiguration `
    -Name $dscConfigFileName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationAccount `
    -erroraction 'silentlycontinue'

  if ($dsc -and !$Force) {
    Write-Output  "Configuration $dscConfig Already Exists"
  }
  else {
    Write-Output "Importing & compiling DSC configuration $dscConfigFileName"

    Import-AzureRmAutomationDscConfiguration `
      -AutomationAccountName $AutomationAccount `
      -ResourceGroupName $ResourceGroup `
      -Published `
      -SourcePath $dscConfigFile `
      -Force

    $configContent = (Get-Content $dscDataConfigFile | Out-String)
    Invoke-Expression $configContent

    $compiledJob = Start-AzureRmAutomationDscCompilationJob `
      -ResourceGroupName $ResourceGroup `
      -AutomationAccountName $AutomationAccount `
      -ConfigurationName $dscConfigFileName `
      -ConfigurationData $ConfigData

    while ($null -eq $compiledJob.EndTime -and $null -eq $compiledJob.Exception) {
      $compiledJob = $compiledJob | Get-AzureRmAutomationDscCompilationJob
      Start-Sleep -Seconds 3
      Write-Output "Compiling Configuration ..."
    }

    Write-Output "Compilation Complete!"
    $compiledJob | Get-AzureRmAutomationDscCompilationJobOutput
  }
}
function Import-Credential ($CredentialName, $UserName, $UserPassword, $AutomationAccount, $ResourceGroup) {

  $cred = Get-AzureRmAutomationCredential `
    -Name $CredentialName `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationAccount `
    -ErrorAction SilentlyContinue

  if (!$cred) {
    Set-StrictMode -off
    Write-Output "Importing $CredentialName credential for user $UserName into the Automation Account $account"

    $cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UserName, $UserPassword

    New-AzureRmAutomationCredential `
      -Name $CredentialName `
      -ResourceGroupName $ResourceGroup `
      -AutomationAccountName $AutomationAccount `
      -Value $cred

  }
}
function Import-Variable ($name, $value, $ResourceGroup, $AutomationAccount) {
  $variable = Get-AzureRmAutomationVariable `
    -Name $name `
    -ResourceGroupName $ResourceGroup `
    -AutomationAccountName $AutomationAccount `
    -ErrorAction SilentlyContinue

  if (!$variable) {
    Set-StrictMode -off
    Write-Output "Importing $VariableName credential into the Automation Account $account"

    New-AzureRmAutomationVariable `
      -Name $name `
      -Value $value `
      -Encrypted $false `
      -ResourceGroupName $ResourceGroup `
      -AutomationAccountName $AutomationAccount
  }
}
function Add-NodesViaFilter ($filter, $group, $dscAccount, $dscGroup, $dscConfig) {
  Write-Color -Text "`r`n---------------------------------------------------- "-Color Yellow
  Write-Color -Text "Register VM with name like ", "$filter ", "found in ", "$group ", "and apply config ", "$dscConfig", "..." -Color Green, Red, Green, Red, Green, Cyan, Green
  Write-Color -Text "---------------------------------------------------- "-Color Yellow

  Get-AzureRMVM -ResourceGroupName $group | Where-Object { $_.Name -like $filter } | `
    ForEach-Object {
    $vmName = $_.Name
    $vmLocation = $_.Location
    $vmGroup = $_.ResourceGroupName

    $dscNode = Get-AzureRmAutomationDscNode `
      -Name $vmName `
      -ResourceGroupName $dscGroup `
      -AutomationAccountName $dscAccount `
      -ErrorAction SilentlyContinue

    if ( !$dscNode ) {
      Write-Color -Text "Registering $vmName" -Color Yellow
      Register-AzureRmAutomationDscNode `
        -AzureVMName $vmName `
        -AzureVMResourceGroup $vmGroup `
        -AzureVMLocation $vmLocation `
        -AutomationAccountName $dscAccount `
        -ResourceGroupName $dscGroup `
        -NodeConfigurationName $dscConfig `
        -RebootNodeIfNeeded $true
    }
    else {
      Write-Color -Text "Skipping $vmName, as it is already registered" -Color Yellow
    }
  }
}
function GetADGroup([string]$GroupName) {
  # Required Argument $1 = GROUPNAME

  if ( !$GroupName) { throw "GroupName Required" }

  $Group = Get-AzureADGroup -Filter "DisplayName eq '$GroupName'"
  if (!$Group) {
    Write-Color -Text "Creating AD Group $GroupName" -Color Yellow
    $Group = New-AzureADGroup -DisplayName $GroupName -MailEnabled $false -SecurityEnabled $true -MailNickName $GroupName
  }
  else {
    Write-Color -Text "AD Group ", "$GroupName ", "already exists." -Color Green, Red, Green
  }
  return $Group
}
function GetADuser([string]$Email) {
  # Required Argument $1 = Email

  if (!$Email) { throw "Email Required" }

  $user = Get-AzureADUser -Filter "userPrincipalName eq '$Email'"
  if (!$User) {
    Write-Color -Text "Creating AD User $Email" -Color Yellow
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $NickName = ($Email -split '@')[0]
    New-AzureADUser -DisplayName "New User" -PasswordProfile $PasswordProfile -UserPrincipalName $Email -AccountEnabled $true -MailNickName $NickName
  }
  else {
    Write-Color -Text "AD User ", "$Email", " already exists." -Color Green, Red, Green
  }

  return $User
}

function AssignADGroup($Email, $Group) {

  if (!$Email) { throw "User Required" }
  if (!$Group) { throw "User Required" }

  $User = GetADUser $Email
  $Group = GetADGroup $Group
  $Groups = New-Object Microsoft.Open.AzureAD.Model.GroupIdsForMembershipCheck
  $Groups.GroupIds = $Group.ObjectId

  $IsMember = Select-AzureADGroupIdsUserIsMemberOf  -ObjectId $User.ObjectId -GroupIdsForMembershipCheck $Groups

  if (!$IsMember) {
    Write-Color -Text "Assigning $Email into ", $Group.DisplayName -Color Yellow, Yellow
    Add-AzureADGroupMember -ObjectId $Group.ObjectId -RefObjectId $User.ObjectId
  }
  else {
    Write-Color -Text "AD User ", "$Email", " already assigned to ", $Group.DisplayName -Color Green, Red, Green, Red
  }
}
function GetDbConnectionString($DatabaseServerName, $DatabaseName, $UserName, $Password)
{
    return "Server=tcp:{0}.database.windows.net,1433;Database={1};User ID={2}@{0};Password={3};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;" -f
        $DatabaseServerName, $DatabaseName, $UserName, $Password
}
function Get-PlainText()
{
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[System.Security.SecureString]$SecureString
	)
	BEGIN { }
	PROCESS
	{
		$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString);

		try
		{
			return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr);
		}
		finally
		{
			[Runtime.InteropServices.Marshal]::FreeBSTR($bstr);
		}
	}
	END { }
}
function GetVmssInstances([string]$ResourceGroupName) {
  # Required Argument $1 = RESOURCE_GROUP

  if ( !$ResourceGroupName) { throw "ResourceGroupName Required" }

  $ServerNames = @()
  $VMScaleSets = Get-AzureRmVmss -ResourceGroupName $ResourceGroupName
  ForEach ($VMScaleSet in $VMScaleSets) {
    $VmssVMList = Get-AzureRmVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name
    ForEach ($Vmss in $VmssVMList) {
      $Name = (Get-AzureRmVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name -InstanceId $Vmss.InstanceId).OsProfile.ComputerName

      Write-Color -Text "Adding ", $Name, " to Instance List" -Color Yellow, Red, Yellow
      $ServerNames += (Get-AzureRmVmssVM -ResourceGroupName $ResourceGroupName -VMScaleSetName $VMScaleSet.Name -InstanceId $Vmss.InstanceId).OsProfile.ComputerName
    }
  }
  return $ServerNames
}
function SetSqlClientFirewallRule($SqlServerName, $RuleName, $IP) {
  Get-AzureSqlDatabaseServerFirewallRule -ServerName $SqlServerName -RuleName $RuleName -ev notPresent -ea 0 | Out-null

  if ($notPresent) {
    Write-Host "Creating Sql Firewall Rule $RuleName..." -ForegroundColor Yellow
    New-AzureSqlDatabaseServerFirewallRule -ServerName $DbServer -RuleName $RuleName -StartIpAddress $IP -EndIpAddress $IP
  }
  else {
    Write-Color -Text "SQL Firewall Rule ", "$RuleName ", "already exists." -Color Green, Red, Green
  }
}
