param (
  [object]$WebhookData
)
 
##############################################
##############################################
#### OUTPUT ALL INCOMING DATA
 
$WebhookName = $WebhookData.WebhookName
$WebhookHeaders = $WebhookData.RequestHeader
$WebhookBody = $WebhookData.RequestBody
 
Write-Output "###############################"
Write-Output "WebHookName"
Write-Output $WebhookName
 
Write-Output "###############################"
Write-Output "WebHookHeaders"
Write-output $WebhookHeaders
 
Write-Output "###############################"
Write-Output "WebHookBody"
Write-output $WebhookBody
 
Write-Output "###############################"
 
#Resets the user password to Password1 temporarily, but is forced to reset the password on next logon
Set-ADAccountPassword -identity $WebhookBody -NewPassword (ConvertTo-SecureString -AsPlainText "Password123" -Force) –Reset Set-ADuser -ChangePasswordAtLogon $True