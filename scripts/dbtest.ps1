function Test-SQLConnection {
  [OutputType([bool])]
  Param
  (
    [Parameter(Mandatory = $true,
      ValueFromPipelineByPropertyName = $true,
      Position = 0)]
    $ConnectionString
  )
  try {
    Write-Output $ConnectionString
    $sqlConnection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString;
    $sqlConnection.Open();
    $sqlConnection.Close();

    Write-Output  "Database Connected."
    exit 0;
  }
  catch {
    Write-Output  $_.Exception.Message
    exit 1;
  }
}

$DB_HOST = "10.0.1.190"  # Load Balancer
$DB_NAME = "SimpleAppDB"
$DB_USER = "sa"
$DB_PASSWORD = "password1!"
$CONNECTION = "Data Source=$DB_HOST,1433;Initial Catalog=$DB_NAME;User ID=$DB_USER;Password=$DB_PASSWORD"

Test-SQLConnection $CONNECTION
