Get-Location | Set-Location
$ProgressPreference = "Continue"
# Fetches auth.key from key.txt
$userKey =  Get-Content "key.txt"
	
If ($userKey -eq "") {
  Write-Host "Your key.txt is empty, fill it!"
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
	
$nowDate    = Get-Date
$targetDate = Get-Date $jsonObject.model.product.dateSalesFrom
$timeSpan   = $targetDate - $nowDate
$stopWatch  = [System.Diagnostics.Stopwatch]::StartNew()

Do {
    $progress = @{
        Activity         = 'Waiting until sales start'
        SecondsRemaining = ($timeSpan - $stopWatch.Elapsed).TotalSeconds
    }
    Write-Progress @progress
    Start-Sleep -Milliseconds 200
}
until($stopWatch.Elapsed -ge $timeSpan)


# Waits until sales start and shows time remaining until that time
# Do {
#   $currentDate = Get-Date
#   $waitTime = (New-TimeSpan -End $purchaseTime).TotalSeconds
#   Write-Progress -Activity "Waiting until sales start" -SecondsRemaining $waitTime
#   Start-Sleep -Milliseconds 201
# } until ($currentDate -gt $purchaseTime)

# This makes making the webrequests smoother and won't overflow the terminal
$ProgressPreference = "silentlyContinue"

# Fetches ticket data and stores it into a hashtable
$getData2 = Invoke-WebRequest -Uri $requestLink | ConvertFrom-Json | ConvertTo-Json -depth 100
$jsonObject = $getData2 | ConvertFrom-Json	
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
  Else {}
  
	
  # Creates the json payload for the POST request with our data
	
  $payload = @{   
    toCreate =  @(
          @{
            inventoryId = $inventoryId
            quantity = $max
            productVariantUserForm = $null
          }
        )
        toCancel = @(@{})
  } | ConvertTo-Json -Depth 2

  # Parameters for the debugging version of requests
  # $PostParameters = @{
  #   Uri             = $target
  #   Headers         = $header
  #   Method          = 'POST' 
  #   Body            = $payload
	#   ContentType     = "application/json"
  # }

	
# Runs the requests as a background job and starts to form a new one until ticket types run out. 
Start-Job -ScriptBlock {Invoke-WebRequest -UseBasicParsing -Uri $using:target -Headers $using:header -Method "POST" -Body $using:payload -ContentType "application/json" }

# Debugging version of the above script
# Invoke-WebRequest @PostParameters
$i--
	
} until ($i -eq -1)

Start-Sleep -Seconds 3
Get-Job 
$popup = New-Object -ComObject Wscript.Shell
$popup.Popup("Refresh the kide.app page, the tickets have been added to your shopping cart. Be sure to buy them before the reservation time ends!",0,"Done",0x1)
