$ConfigData = @{
  AllNodes = @(
    @{
      NodeName           = "Web"
      RebootNodeIfNeeded = $true
    },
    @{
      NodeName           = "App"
      RebootNodeIfNeeded = $true
    }
  )
}