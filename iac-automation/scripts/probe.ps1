<# Copyright (c) 2017
.Synopsis
   Check a valid 200 OK Response for a URL
.DESCRIPTION
   This script will check for a 200 OK Response on a URL
.EXAMPLE

#>

Param(
  [Parameter(Mandatory = $true)]
  [string] $Url
)

# First we create the request.
$HTTP_Request = [System.Net.WebRequest]::Create($Url)

# We then get a response from the site.
$HTTP_Response = $HTTP_Request.GetResponse()

# We then get the HTTP code as an integer.
$HTTP_Status = [int]$HTTP_Response.StatusCode

If ($HTTP_Status -eq 200) {
    Write-Host "Site is OK!"
}
Else {
    Write-Host "The Site may be down, please check!"
}

# Finally, we clean up the http request by closing it.
$HTTP_Response.Close()
