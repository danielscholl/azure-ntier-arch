Configuration Backend {
  Import-DscResource -ModuleName PSDesiredStateConfiguration

  node Database
  {
    Script ConfigureSql {
      TestScript = {
        $disks = Get-Disk | Where-Object partitionstyle -eq 'raw'
        if ($disks -ne $null) {
          return $false
        }
        else {
          return $true
        }
      }

      SetScript  = {
        $disks = Get-Disk | Where-Object partitionstyle -eq 'raw'
        if ($disks -ne $null) {
          # Create a new storage pool using all available disks
		        New-StoragePool -FriendlyName "VMStoragePool" `
            -StorageSubsystemFriendlyName "Windows Storage*" `
            -PhysicalDisks (Get-PhysicalDisk -CanPool $True)

		        # Return all disks in the new pool
		        $disks = Get-StoragePool -FriendlyName "VMStoragePool" `
            -IsPrimordial $false | Get-PhysicalDisk

		        # Create a new virtual disk
		        New-VirtualDisk -FriendlyName "DataDisk" `
            -ResiliencySettingName Simple `
            -NumberOfColumns $disks.Count `
            -UseMaximumSize -Interleave 256KB `
            -StoragePoolFriendlyName "VMStoragePool"

		        # Format the disk using NTFS and mount it as the F: drive
		        Get-Disk | Where-Object partitionstyle -eq 'raw' |
            Initialize-Disk -PartitionStyle MBR -PassThru |
            New-Partition -DriveLetter "F" -UseMaximumSize |
            Format-Volume -FileSystem NTFS -NewFileSystemLabel "DataDisk" -Confirm:$false

		        Start-Sleep -Seconds 60

		        $logs = "F:\Logs"
		        $data = "F:\Data"
		        $backups = "F:\Backup"
		        [system.io.directory]::CreateDirectory($logs)
		        [system.io.directory]::CreateDirectory($data)
		        [system.io.directory]::CreateDirectory($backups)

          # Setup the data, backup and log directories as well as mixed mode authentication
          Import-Module "sqlps" -DisableNameChecking
          [System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo")
          $sqlesq = new-object ('Microsoft.SqlServer.Management.Smo.Server') Localhost
          $sqlesq.Settings.LoginMode = [Microsoft.SqlServer.Management.Smo.ServerLoginMode]::Mixed
          $sqlesq.Settings.DefaultFile = $data
          $sqlesq.Settings.DefaultLog = $logs
          $sqlesq.Settings.BackupDirectory = $backups
          $sqlesq.Alter()

          # Restart the SQL Server service
          Restart-Service -Name "MSSQLSERVER" -Force
          # Re-enable the sa account and set a new password to enable login
          Invoke-Sqlcmd -ServerInstance Localhost -Database "master" -Query "ALTER LOGIN sa ENABLE"
          Invoke-Sqlcmd -ServerInstance Localhost -Database "master" -Query "ALTER LOGIN sa WITH PASSWORD = 'password1!'"

          # Get the Simple App database backup
          $dbsource = "https://cloudcodeit.blob.core.windows.net/public/SimpleAppDB.bak"
          Invoke-WebRequest $dbsource -OutFile "$backups\SimpleAppDB.bak"

          Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
          Install-Module dbatools -Force

          Get-ChildItem -Path $backups | Restore-DbaDatabase -SqlInstance LocalHost

          New-NetFirewallRule -DisplayName "SQL Server" -Direction Inbound -Protocol TCP -LocalPort 1433 -Action allow
        }
      }
      GetScript  = {@{Result = $true}}
    }
  }
}
