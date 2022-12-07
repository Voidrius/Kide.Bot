Get-Location | Set-Location
$ProgressPreference = "Continue"
# Fetches auth.key from key.txt
$userKey =  Get-Content "key.txt"
	
If ($userKey -eq "<your bearer token here>") {
  Write-Host "You haven't entered your bearer token, refer to the gitlab page for instructions."
  break
}

# Acquire event link from user
$eventKey = Read-Host "Enter the event link"
	
# Format the passed event key into a suitable form for http requests
$eventKey = $eventKey.Split('/')[4]
$requestLink = "https://api.kide.app/api/products/" + $eventKey
	
# Finds the events data with a http request, and formats into a ps.object for easy access of data
$getData = Invoke-WebRequest -Uri $requestLink | ConvertFrom-Json | ConvertTo-Json -depth 100
$jsonObject = $getData | ConvertFrom-Json

# Formats POST request parameters in advance
$target = "https://api.kide.app/api/reservations"
$header = @{"authorization" = "Bearer $userKey"}
	
$purchaseTime = Get-Date $jsonObject.model.product.dateSalesFrom

# Old timer
# Do {
#   $currentDate = Get-Date
#   $waitTime = (New-TimeSpan -Start $currentDate -End $purchaseTime).TotalSeconds
#   $progress = @{
#       Activity         = "Waiting until sales start"
#       SecondsRemaining = $waitTime
#   }
#   Write-Progress @progress
#   Start-Sleep -Milliseconds 200
# } until ($currentDate -gt $purchaseTime)

# Waits until sales start and shows time remaining until that time
Do {
  Do {
  # Sets up the timer, plays until sale time starts
  $currentDate = Get-Date
  $waitTime = (New-TimeSpan -Start $currentDate -End $purchaseTime).TotalSeconds
  $progress = @{
      Activity         = "Waiting until tickets are available, when sales start the timer will stop, don't worry the script is still running."
      SecondsRemaining = $waitTime
  }
  Write-Progress @progress
  } until ($currentDate -gt $purchaseTime)
  
  # Starts looping this until the ticket data is available.
  # Fetches ticket data and stores it into a hashtable, also checks for when the tickets become available
  $ProgressPreference = "silentlyContinue"
  $getData2 = Invoke-WebRequest -Uri $requestLink | ConvertFrom-Json | ConvertTo-Json -depth 100
  $jsonObject = $getData2 | ConvertFrom-Json
  $ticketState = $jsonObject.model.variants.Count
  
} until ($ticketState -ne 0)

$i = $jsonObject.model.variants.Count
$i--

# Core of the script
Do {
	
  # This part loops through all the tickets and gets their ID and maximum reservable count
	$jasenyyscheck = $jsonObject.model.variants[$i].accessControlMemberships[$i].ID
  $inventoryId = $jsonObject.model.variants[$i].inventoryId
  $max = $jsonObject.model.variants[$i].productVariantMaximumReservableQuantity
  $available = $jsonObject.model.variants[$i].availability
  
  If ($max -gt $available) {
    If ($available -eq 0 ) {
      $i--; continue
    }
    Else {$max = $available}
  }
	Elseif ($jasenyyscheck -notcontains $null) {$max = 1}
	
  # Creates the json payload for the POST request with our data
	
  $payload = [ordered]@{   
    toCancel = @()
    toCreate =  @(
      [ordered]@{
            inventoryId = $inventoryId
            quantity = $max
            productVariantUserForm = $null
          }
        )
        
  } | ConvertTo-Json -Depth 2

  # Parameters for the debugging version of requests
  # $PostParameters = @{
  #   Uri             = $target
  #   Headers         = $header
  #   Method          = 'POST' 
  #   Body            = $payload
	#   ContentType     = "application/json"
  # }

# Debugging version of the above script
# Invoke-WebRequest @PostParameters

# Runs the requests as a background job and starts to form a new one until ticket types run out. 
try {
Start-Job -ScriptBlock {Invoke-WebRequest -UseBasicParsing -Uri $using:target -Headers $using:header -Method "POST" -Body $using:payload -ContentType "application/json" }
}
catch {
    $errorMessage = $_.Exception.Message
    if (Get-Member -InputObject $_.Exception -Name 'Response') {
        try {
            $result = $_.Exception.Response.GetResponseStream()
            $reader = New-Object System.IO.StreamReader($result)
            $reader.BaseStream.Position = 0
            $reader.DiscardBufferedData()
            $responseBody = $reader.ReadToEnd();
        } catch {
            Throw "An error occurred while calling POST method at: $target. Error: $errorMessage. Cannot get more information."
        }
    }
    Throw "An error occurred while calling POST method at: $target. Error: $errorMessage. Response body: $responseBody"
}
$i--
	
} until ($i -eq -1)

# Creates a info pop up when the script is done.
$popup = New-Object -ComObject Wscript.Shell
$popup.Popup("Refresh the kide.app page, the tickets have been added to your shopping cart. Be sure to buy them before the reservation time ends!",0,"Done",0x1)
