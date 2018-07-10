$ConfigData = @{
  AllNodes = @(
    @{
      NodeName                    = "Database"
      PSDscAllowPlainTextPassword = $True
      PSDscAllowDomainUser        = $True
    }
  )
}