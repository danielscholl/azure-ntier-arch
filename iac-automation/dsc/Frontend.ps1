Configuration Frontend {
  Import-DscResource -ModuleName xPSDesiredStateConfiguration
  Import-DscResource -ModuleName xWebAdministration
  Import-DscResource -ModuleName xNetworking

  $features = @(
    @{Name = "Web-Server"; Ensure = "Present"},
    @{Name = "Web-WebServer"; Ensure = "Present"},
    @{Name = "Web-Common-http"; Ensure = "Present"},
    @{Name = "Web-Default-Doc"; Ensure = "Present"},
    @{Name = "Web-Http-Errors"; Ensure = "Present"},
    @{Name = "Web-Static-Content"; Ensure = "Present"},
    @{Name = "Web-Http-Logging"; Ensure = "Present"},
    @{Name = "Web-Performance"; Ensure = "Present"},
    @{Name = "Web-Security"; Ensure = "Present"},
    @{Name = "Web-App-Dev"; Ensure = "Present"},
    @{Name = "Web-Asp-Net45"; Ensure = "Present"},
    @{Name = "Web-Mgmt-Tools"; Ensure = "Present"},
    @{Name = "Web-Mgmt-Console"; Ensure = "Present"}
  )

  node App
  {
    WindowsFeature WebServerRole
    {
      Name = "Web-Server"
      Ensure = "Present"
    }

    WindowsFeature WebManagementConsole
    {
      Name = "Web-Mgmt-Console"
      Ensure = "Present"
    }

    xFirewall HTTPRulesInboundTCP
    {
      Name = "Custom Web Inbound Rules TCP"
      Ensure = "Present"
      Direction = "Inbound"
      Description = "HTTP Inbound Rules for Additional Web Site"
      Profile = "Public"
      Protocol = "TCP"
      LocalPort = ("8080")
      Action = "Allow"
      Enabled = "True"
    }

    xRemoteFile Payload {
      Uri             = "https://cloudcodeit.blob.core.windows.net/public/SimpleApp.API.zip"
      DestinationPath = "C:\deploy\website.zip"
    }

    xRemoteFile InstallDotNetCoreWindowsHosting {
      Uri             = "https://download.microsoft.com/download/1/f/7/1f7755c5-934d-4638-b89f-1f4ffa5afe89/dotnet-hosting-2.1.2-win.exe"
      DestinationPath = "C:\deploy\dotnet-hosting-2.1.2-win.exe"
    }

    xRemoteFile InstallWebDeploy {
      Uri             = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
      DestinationPath = "C:\deploy\WebDeploy_amd64_en-US.msi"
    }

    Archive WebAppExtract
    {
      Path = "C:\deploy\website.zip"
      Destination = "C:\inetpub\simpleapp\wwwroot"
      DependsOn = "[xRemoteFile]Payload"
    }

    Package InstallDotNetCoreWindowsHosting {
      Ensure    = "Present"
      Path      = "C:\deploy\dotnet-hosting-2.1.2-win.exe"
      Arguments = "/q /norestart"
      Name      = "Microsoft .NET Core 2.1.2 - Windows Server Hosting"
      ProductId = "5efe489b-a529-4d85-98ba-4eedd41d3f36"
      DependsOn = "[xRemoteFile]InstallDotNetCoreWindowsHosting"
    }

    Package InstallWebDeploy {
      Ensure    = "Present"
      Path      = "C:\deploy\WebDeploy_amd64_en-US.msi"
      Name      = "Microsoft Web Deploy 3.6"
      LogPath   = "C:\deploy\logoutput.txt"
      ProductId = "6773A61D-755B-4F74-95CC-97920E45E696"
      Arguments = "LicenseAccepted='0' ADDLOCAL=ALL"
      DependsOn = "[xRemoteFile]InstallWebDeploy"
    }

    xWebAppPool WebAppAppPool
    {
      Ensure          = "Present"
      Name            = "simpleapp"
      State           = "Started"
      managedRuntimeVersion = ""
      DependsOn = "[Package]InstallWebDeploy"
    }

    xWebsite WebAppWebSite
    {
      Ensure          = "Present"
      Name            = "simpleapp"
      State           = "Started"
      PhysicalPath    = "C:\inetpub\simpleapp\wwwroot"
      ApplicationPool = "simpleapp"
      BindingInfo = MSFT_xWebBindingInformation
      {
        Port = '8080'
        IPAddress = '*'
        Protocol = 'HTTP'
      }
      DependsOn = "[xWebAppPool]WebAppAppPool"
    }

    Script Reboot
    {
        TestScript = {
            return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
        }
        SetScript = {
            New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
             $global:DSCMachineStatus = 1

        }
        GetScript = { return @{result = 'result'}}
        DependsOn = '[xWebsite]WebAppWebSite'
    }
  }

  node Web
  {
    WindowsFeature WebServerRole {
      Name   = "Web-Server"
      Ensure = "Present"
    }

    WindowsFeature WebManagementConsole {
      Name   = "Web-Mgmt-Console"
      Ensure = "Present"
    }

    xFirewall HTTPRulesInboundTCP
    {
      Name        = "Custom Web Inbound Rules TCP"
      Ensure      = "Present"
      Direction   = "Inbound"
      Description = "HTTP Inbound Rules for Additional Web Site"
      Profile     = "Public"
      Protocol    = "TCP"
      LocalPort   = ("8080")
      Action      = "Allow"
      Enabled     = "True"
    }

    xRemoteFile Payload {
      Uri             = "https://cloudcodeit.blob.core.windows.net/public/SimpleApp.WEB.zip"
      DestinationPath = "C:\deploy\website.zip"
    }

    xRemoteFile InstallDotNetCoreWindowsHosting {
      Uri             = "https://download.microsoft.com/download/1/f/7/1f7755c5-934d-4638-b89f-1f4ffa5afe89/dotnet-hosting-2.1.2-win.exe"
      DestinationPath = "C:\deploy\dotnet-hosting-2.1.2-win.exe"
    }

    xRemoteFile InstallWebDeploy {
      Uri             = "https://download.microsoft.com/download/0/1/D/01DC28EA-638C-4A22-A57B-4CEF97755C6C/WebDeploy_amd64_en-US.msi"
      DestinationPath = "C:\deploy\WebDeploy_amd64_en-US.msi"
    }

    Archive WebAppExtract {
      Path        = "C:\deploy\website.zip"
      Destination = "C:\inetpub\simpleapp\wwwroot"
      DependsOn   = "[xRemoteFile]Payload"
    }

    Package InstallDotNetCoreWindowsHosting {
      Ensure    = "Present"
      Path      = "C:\deploy\dotnet-hosting-2.1.2-win.exe"
      Arguments = "/q /norestart"
      Name      = "Microsoft .NET Core 2.1.2 - Windows Server Hosting"
      ProductId = "5efe489b-a529-4d85-98ba-4eedd41d3f36"
      DependsOn = "[xRemoteFile]InstallDotNetCoreWindowsHosting"
    }

    Package InstallWebDeploy {
      Ensure    = "Present"
      Path      = "C:\deploy\WebDeploy_amd64_en-US.msi"
      Name      = "Microsoft Web Deploy 3.6"
      LogPath   = "C:\deploy\logoutput.txt"
      ProductId = "6773A61D-755B-4F74-95CC-97920E45E696"
      Arguments = "LicenseAccepted='0' ADDLOCAL=ALL"
      DependsOn = "[xRemoteFile]InstallWebDeploy"
    }

    xWebAppPool WebAppAppPool
    {
      Ensure                = "Present"
      Name                  = "simpleapp"
      State                 = "Started"
      managedRuntimeVersion = ""
      DependsOn             = "[Package]InstallWebDeploy"
    }

    xWebsite WebAppWebSite
    {
      Ensure          = "Present"
      Name            = "simpleapp"
      State           = "Started"
      PhysicalPath    = "C:\inetpub\simpleapp\wwwroot"
      ApplicationPool = "simpleapp"
      BindingInfo     = MSFT_xWebBindingInformation
      {
        Port      = '8080'
        IPAddress = '*'
        Protocol  = 'HTTP'
      }
      DependsOn       = "[xWebAppPool]WebAppAppPool"
    }

    Script Reboot {
      TestScript = {
        return (Test-Path HKLM:\SOFTWARE\MyMainKey\RebootKey)
      }
      SetScript  = {
        New-Item -Path HKLM:\SOFTWARE\MyMainKey\RebootKey -Force
        $global:DSCMachineStatus = 1

      }
      GetScript  = { return @{result = 'result'}}
      DependsOn  = '[xWebsite]WebAppWebSite'
    }
  }
}