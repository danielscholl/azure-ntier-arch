# Azure NTier Architecture

This is a Powershell Infrastruture as Code (iac) automation solution for a Standard IaaS Ntier Architecture.

__Requirements:__

1. [Windows Powershell](https://docs.microsoft.com/en-us/powershell/scripting/setup/installing-windows-powershell?view=powershell-5.1)

```powershell
  $PSVersionTable.PSVersion

  # Result
  Major  Minor  Build  Revision
  -----  -----  -----  --------
  5      1      16299  248
```

2. [Azure PowerShell Modules](https://www.powershellgallery.com/packages/Azure/5.1.1)

```powershell
  Get-Module Azure -list | Select-Object Name,Version

  # Result
  Name  Version
  ----  -------
  Azure 5.1.1
```

3. [AzureRM Powershell Modules](https://www.powershellgallery.com/packages/AzureRM/5.1.1)

```powershell
  Get-Module AzureRM.* -list | Select-Object Name,Version

  # Result
  Name                                  Version
  ----                                  -------
  AzureRM.Automation                    4.3.1
  AzureRM.Compute                       4.5.0
  AzureRM.KeyVault                      4.2.1
  AzureRM.Network                       5.4.1
  AzureRM.profile                       4.5.0
  AzureRM.Resources                     5.5.1
  AzureRM.Scheduler                     0.16.2
  AzureRM.Storage                       4.2.2
```

__Installation:__

Install Required PowerShell Modules if needed

```powershell
Install-Module Azure
Install-Module AzureRM

Import-Module Azure
Import-Module AzureRM
```

## Azure Network Architecture

The Network scheme is an ARM Network scheme with multiple subnets.

__Network Resource Requirements:__

- A Unique /24 Address Space  ie: 10.0.1.0/24
- Azure Region Location (EastUS)
- Subnet 1 Web-Tier 10.1.0.0/26
- Subnet 2 App-Tier 10.1.0.64/26
- Subnet 3 Data-Tier 10.1.0.128/26
- Subnet 4 Mgmt-Tier 10.1.0.192/287
- Subnet 5 GatewaySubnet 10.1.0.224/28

## Azure IaaS Architecture

The architecture depends upon the following items:

1. Azure Storage Account - Diagnostic Storage, Runbooks, DSC Configuration and Scripts
1. KeyVault - Local Admininstrator Information
1. Automation Account - DSC and Runbooks

### Mgmt-Tier Server Requirements

| Size           | vCPU | Memory (GiB) | Network Bandwidth MBps | Instances |
| -------------- | ---- | ------------ | ---------------------- | --------- |
| Standard_A1_v2 | 1    | 2            | 250                    | 1         |

| OS Disk     | Disk Type    | Disk Throughput (IOPS/MBps) |
| ----------- | ------------ | --------------------------- |
| Managed SSD | Standard_LRS |                             |

### Web-Tier Server Requirements

| Size            | vCPU | Memory (GiB) | Network Bandwidth MBps | Instances |
| --------------- | ---- | ------------ | ---------------------- | --------- |
| Standard_DS1_v2 | 1    | 4            | 750                    | 2         |

| OS Disk     | Disk Type    | Disk Throughput (IOPS/MBps) |
| ----------- | ------------ | --------------------------- |
| Managed SSD | Standard_LRS |                             |

### App-Tier Server Requirements

| Size            | vCPU | Memory (GiB) | Network Bandwidth MBps | Instances |
| --------------- | ---- | ------------ | ---------------------- | --------- |
| Standard_DS2_v2 | 2    | 7            | 1500                   | 2         |

| OS Disk     | Disk Type    | Disk Throughput (IOPS/MBps) |
| ----------- | ------------ | --------------------------- |
| Managed SSD | Standard_LRS |                             |

### Data-Tier Server Requirements

| Size            | vCPU | Memory (GiB) | Network Bandwidth MBps | Instances |
| --------------- | ---- | ------------ | ---------------------- | --------- |
| Standard_DS3_v2 | 4    | 14           | 3000                   | 2         |

| OS Disk     | Disk Type    | Disk Throughput (IOPS/MBps) |
| ----------- | ------------ | --------------------------- |
| Managed SSD | Standard_LRS |                             |

![[0]][0]
_Architecture Diagram_

## Installation Procedure

>NOTE: ALWAYS USE A NEW POWERSHELL SESSION!!!

### Create Environment File

Create an environment setting file in the root directory ie: `.env.ps1`

Default Environment Settings

| Parameter            | Default                              | Description                              |
| -------------------- | ------------------------------------ | ---------------------------------------- |
| _AZURE_SUBSCRIPTION_ | xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx | Azure Subscription Id                    |
| _AZURE_LOCATION_     | EastUS                               | Azure Region for Resources to be located |
| _AZURE_GROUP_        | ntier                                | Azure Resource Group Name                |
| _AZURE_USERNAME_     | localAdmin                           | Default Local Admin UserName             |
| _AZURE_PASSWORD_     | localPassword                        | Default Local Admin Password             |

### Create Resources

Resources are broken up into sections only for the purpose of not having an excessively long running task.

#### Install Base Resources

```powershell
# Install the Base Resources
./install.ps1 -Base $true
```

#### Install Automation Resources

Automation Accounts requires 2 additional pieces of information.
- subscriptionPassword -- Used temporarily for creation of RunAs Accounts
- domainPassword -- Stores Domain Credentials for ability to add to Active Directory Domain (Future Expansion)


```powershell
# Install the Automation Resources
./install.ps1 -DevOps $true

# Required Values Collected
cmdlet New-AzureRmResourceGroupDeployment at command pipeline position 1
Supply values for the following parameters:
(Type !? for Help.)
subscriptionPassword: ***********
domainPassword: ************
```

#### Install the Tier Compute Resources

```powershell
# Install the Management Resources
./install.ps1 -Manage $true -Web $true -App $true -Db $true
```

#### Apply the Resource Configurations

```powershell
# Apply the DSC Configs
./install.ps1 -DSC $true
```

## Manage the Solution

To gracefully suspend the solution from Azure a runbook can be applied or a schedule to run it setup.

### Shutdown the Servers using the runbook

```powershell
$params = @{"RESOURCEGROUPNAME"="ntier"}

Start-AzureAutomationRunbook -AutomationAccountName "ntier-automate" -Name "stop-machines" -Parameters $params
```

### Delete the Entire Solution

```powershell
# Remove the Resource Group

Remove-AzureRmResourceGroup -Name "ntier"
```

[0]: ./diagrams/Architecture.png "Architecture Diagram"