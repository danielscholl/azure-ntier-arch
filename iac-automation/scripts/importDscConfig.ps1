<# Copyright (c) 2017
.Synopsis
   Imports a DSC Configuration into an automation account
   Adapted from blog posts by: KARIM VAES
.DESCRIPTION
   This script will import a dsc configuration via powershell into a provided automation account.
.EXAMPLE

#>


Param(

  [Parameter(Mandatory = $true)]
  [string] $dscRole,

  [Parameter(Mandatory = $true)]
  [string] $ResourceGroup,

  [string] $DscPath = "../dsc/",
  [string] $dscDataConfig = $dscRole + "-config.ps1",
  [bool] $Force = $false
)

function Import-DscConfiguration ($script, $config, $ResourceGroup) {

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


Import-DscConfiguration $dscRole $dscDataConfig $ResourceGroup