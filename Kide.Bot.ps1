# Sets up location and variables that are checked later
Get-Location | Set-Location
$ProgressPreference = "Continue"
$runFetch = $False
$specificTicket = $null
$specificTicketOrdered = $False
$eventKey = $null
$prioLooped = $False
$script:timesOrdered = 0

# Fetches auth.key from key.txt
$userKey =  Get-Content "key.txt"

If ($userKey -eq "<your bearer token here>") {
  Write-Host "You haven't entered your bearer token, refer to the readme file for instructions."
  Start-Sleep 10
  break
}

# Acquire event link from user
While (!$eventkey){
  $eventKey = Read-Host "Enter the event link"
  If ($eventKey -eq ""){
    Write-Host "Please enter a valid link"`n
  }
} 

Write-Host `n"It's highly recommended to be signed in through Haka in Kide.App, in case any tickets require it.`nThe bot is not able to order tickets that have been marked as student tickets otherwise."`n
Write-Host "This script prioritizes a specific ticket name that you can enter yourself."`n
Write-Host "For example, you can try the start time of an appro, `nor a bars name where you want to end up for the after party"`n
Write-Host "It tries to get the maximum allowed amount of the ticket you specified,`nafterwhich it tries to get any other ticket type as well."`n
Write-Host "If you don't know any names that could be related to a ticket you want, `nyou can also just leave it empty by pressing enter during the prompt."`n
Write-Host "You can choose to not prioritize organization tickets, or if you are a member of an organization,`nyou can try to filter the search with your orgs name in the ticket name prompt."`n 
Write-Host "Note: This only matters if the event organizer has set the ticket type as a member ticket, `nthe script will not recognize memberships that are not required by Kide.App itself."`n 
Write-Host "Side note: Only use small letters in the prompts to be safe, `nthis is a delicate machine, and the kide.api is even more fragile."`n`n`n 

# Format the passed event key into a suitable form for http requests
$eventKey = $eventKey.Split('/')[4]
$requestLink = "https://api.kide.app/api/products/" + $eventKey
	
# Finds the events data with a http request, and formats into a ps.object for easy access of data
$getData = Invoke-WebRequest -Uri $requestLink -UseBasicParsing -Method "GET"| ConvertFrom-Json | ConvertTo-Json -depth 100
$ticketData = $getData | ConvertFrom-Json

# Prompt for ticket name
$keyWord = Read-Host "Enter a keyword that might be included in the ticket name (Name of the bar for example)"

# Prompt for jasenyys ticket
$jasenCheck = $null
Do {
  $jasenPrompt = Read-Host `n"Do you want to prioritize an organization ticket? (y/n)"
  If (($jasenPrompt -ne "y") -And ($jasenPrompt -ne "n")) {
    Write-Host "Invalid input."
  }
  Else {$jasenCheck = $jasenPrompt}
} until ($jasenCheck)

# Formats POST request parameters in advance
$target = "https://api.kide.app/api/reservations"
$header = @{"authorization" = "Bearer $userKey"}

# Checks for max checkout value, and sets it in advance
$currentDate = Get-Date
$purchaseTime = $ticketData.model.product.dateSalesFrom
$checkoutMax = $null
If ($ticketData.model.product.maxTotalReservationsPerCheckout) {
  $checkoutMax = $ticketData.model.product.maxTotalReservationsPerCheckout
}

# Waits until sales start and shows time remaining until that time
Do {
  If ($currentDate -le $purchaseTime){
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
  }
  # Starts looping this until the ticket data is available.
  # Fetches ticket data and stores it into a hashtable, also checks for when the tickets become available
  Start-Sleep -Milliseconds 500
  $ProgressPreference = "silentlyContinue"
  $getData2 = Invoke-WebRequest -Uri $requestLink -UseBasicParsing -Method "GET" | ConvertFrom-Json | ConvertTo-Json -depth 100
  $ticketData = $getData2 | ConvertFrom-Json
  $ticketState = $ticketData.model.variants.Count
  
} until ($ticketState -ne 0)

# Specific ticket script, resets variables
$keyWord = "*"+$keyWord+"*"
$specificDone = $False
$ticketFound = $False
$orgFound = $False
$ticketID = 0
# Core of the specific ticket script
:specificScript while ($specificDone -eq $False) {
  # Try to find the specific ticket
  :searcherScript while ($ticketFound -eq $False) {
    If ($ticketData.model.variants[$ticketID].name -ilike $keyWord){
      $ticketFound = $True
      If ($jasenCheck -eq "y"){
        If($ticketData.model.variants[$ticketID].isProductVariantMembershipRequired){
          $orgFound = $True
          Break searcherScript
        }
        # Scrapes through the rest to look for a organization ticket with the same keyword
        Else {
          $scrapeID = $ticketID
          while ($scrapeID -ne $ticketState){
            $scrapeID++
            If ($ticketData.model.variants[$scrapeID].name -ilike $keyWord){
              If ($ticketData.model.variants[$scrapeID].isProductVariantMembershipRequired){
                $orgFound = $True
                Break searcherScript
              }
            }
          }
        }
      }
      Elseif ($jasenCheck -eq "n") {
        $scrapeID = $ticketID
        If (!$ticketData.model.variants[$ticketID].isProductVariantMembershipRequired){
          $ticketFound = $True
          Break searcherScript
        }
        Else{
          while ($scrapeID -ne $ticketState){
            $scrapeID++
            If ($ticketData.model.variants[$scrapeID].name -ilike $keyWord){
              If (!$ticketData.model.variants[$scrapeID].isProductVariantMembershipRequired){
                $ticketID = $scrapeID
                $ticketFound = $True
                Break searcherScript
              }
            }
          }
        }
      }
    }
    Elseif ($ticketID -lt $ticketState) {
      $ticketID += 1
    }
    Elseif ($ticketID -eq $ticketState) {
      If ($ticketData.model.variants[$ticketId].name -ilike $keyWord){
        $ticketFound = $True
      }
      Else {
      Write-Host "Couldn't find specified ticket, trying to get other available tickets instead"
      $runFetch = $True
      Break specificScript
      }
    }
  }
  
  # Sets up payload for post request, checks availability and posts the request
  
  $inventoryId = $ticketData.model.variants[$ticketID].inventoryId
  $available = $ticketData.model.variants[$ticketID].availability
  
  # Sets ticket count to allowed quantity
  If ($orgFound -eq $True) {
    If ($ticketData.model.variants[$ticketID].productVariantMaximumReservableQuantity -gt 1) {
      $max = $ticketData.model.variants[$ticketID].productVariantMaximumReservableQuantity
      If ($checkoutMax) {
        If($checkoutMax -lt $max) {
          $max = $checkoutMax
        }
      }
      Elseif ($ticketData.model.variants[$ticketID].productVariantMaximumItemQuantityPerUser -lt $max) {
      $max = $ticketData.model.variants[$ticketID].productVariantMaximumItemQuantityPerUser
      }
    }
    Else {
      $max = 1
    }
  }
  
  # Checks for value that is sometimes set before sales begin
  If ($checkoutMax){
    $max = $checkoutMax
  }
  Else {$max = $ticketData.model.variants[$ticketID].productVariantMaximumReservableQuantity}

  # Final failsafe to check if tickets are available
  If ($max -gt $available) {
    If ($available -eq 0 ) {
      $runFetch = $True
      Break specificScript
    }
  }
  # Creates the json payload for the POST request with our data
  $payload = [ordered]@{  
    expectCart = $true
    includeDeliveryMethods = $false 
    toCancel = @()
    toCreate =  @(
      [ordered]@{
            inventoryId = $inventoryId
            quantity = $max
            productVariantUserForm = $null
          }
        )
        
  } | ConvertTo-Json -Depth 2

  # Runs the requests as a background job
  try {
  Start-Job -ScriptBlock {Invoke-WebRequest -UseBasicParsing -Uri $using:target -Headers $using:header -Method "POST" -Body $using:payload -ContentType "application/json" }
  $specificTicketOrdered = $True
  $specificTicket = $ticketID
  $timesOrdered++
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
$specificDone = $True
$runFetch = $True
}
function Fetch_Script {
  $ticketID = 0
  # Core of the script
  # "Fetch anything you can" version of the script
  :fetchScript while ($ticketID -ne $ticketState) { 
    
    # Checks if the keyword script already ordered this ticket
    If ($specificTicketOrdered -eq $True){
      If ($ticketID -eq $specificTicket){
        $ticketID++
          continue
      }
    }
    
    # Checks ticket priority and allows it through if appropriate
    $jasenLoop = $False
    
    :jasenCheck while ($jasenLoop -eq $False) {
      If ($ticketData.model.variants[$ticketID].isProductVariantMembershipRequired) {
        If ($jasenCheck -eq "n") {
          If ($prioLooped -eq $False) {
            $ticketID++
            break jasenCheck
          }
          Else {
            $jasenLoop = $True
            break jasenCheck
          }
        }
        Elseif ($ticketData.model.variants[$ticketID].isProductVariantMembershipRequired) {
          If ($prioLooped -eq $False){
            break jasenCheck
          }
          Else {
            $jasenLoop = $True
            $ticketID++
            continue
          }  
        }
        Else {
          $jasenLoop = $True
          continue
        }
      }
      Else {$jasenLoop = $True}
    }
    
    # Catches stray runs
    If ($ticketID -eq $specificTicket) {
      $ticketID++; continue
    }

    # Logic for determining ticket amount
    If ($checkoutMax){
      $max = $checkoutMax
    }
    Else {
      $max = $ticketData.model.variants[$ticketID].productVariantMaximumReservableQuantity
    }

    $available = $ticketData.model.variants[$ticketID].availability
    $inventoryId = $ticketData.model.variants[$ticketID].inventoryId

    If ($max -gt $available) {
      If ($available -eq 0 ) {
        $ticketID++; continue
      }
      Else {$max = $available}
    }
  
    # Creates the json payload for the POST request with our data    
    $payload = [ordered]@{   
      expectCart = $true
      includeDeliveryMethods = $false
      toCancel = @()
      toCreate =  @(
        [ordered]@{
              inventoryId = $inventoryId
              quantity = $max
              productVariantUserForm = $null
            }
          )

    } | ConvertTo-Json -Depth 2

    # Runs the requests as a background job and starts to form a new one until ticket types run out. 
    
    try {
      $script:timesOrdered++
      Start-Sleep -Milliseconds 700
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
    $ticketID++ 
  }
  $script:funcRuns += 1
  $prioLooped = $True
}

$funcRuns = 0
# Runs if permission is granted
# Loops through according to users org ticket prompt, and a second time disregarding it
If ($runFetch -eq $True) {
  while ($funcRuns -lt 2) {
    Fetch_Script
    $prioLooped = $True
  }
}


# Creates a info pop up when the script is done.
$popup = New-Object -ComObject Wscript.Shell
If($timesOrdered -eq 0){
  $popup.Popup("The bot failed to order any tickets. The cause is usually that all of the tickets were sold out. I'm sorry for the inconvenience :(",0,"Sorry :(",0x1)
}
Else{
  $popup.Popup("Refresh the kide.app page, the tickets have been added to your shopping cart. Be sure to buy them before the reservation time ends!",0,"Done",0x1)
}


