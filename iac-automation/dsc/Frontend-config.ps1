$ConfigData = @{
  AllNodes = @(
    @{
      NodeName = "Web"
    },
    @{
      NodeName           = "App"
      RebootNodeIfNeeded = $true
    }
  )
}