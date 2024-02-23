<#
Version: 2.0
Author: Randy Catanach
Original Author: Jay Williams
Script: SetGroupTags_Improved.ps1
Description:
Uses Graph API to add Group Tags to Autopilot Devices by serial numbers in a CSV. 
Needs App Registration configured. Once that's done, add ClientId, TenantId, and RedirectUri to $token variable. 
If you don't have MSAL module installed, you can install it by running the included "install_required_modules.ps1" script as admin. 
Permissions needed are DeviceManagementServiceConfig.ReadWrite.All.
The script is provided "AS IS" with no warranties.
#>

#Requires -Modules msal.ps

# Must set these variables
$ClientId = ""
$TenantId = ""
$RedirectUri = ""

$Counter = 0
$CounterFailed = 0
$NonAPCounter = 0

# Set token data
$Token = Get-MsalToken -ClientId $ClientId -TenantId $TenantId -Interactive -RedirectUri $RedirectUri

# Get Csv
Set-Location $PSScriptRoot
if ( Test-Path -Path .\serials.csv -PathType Leaf ){
    Write-Host ""
    Write-Host "serials.csv found!"
    Write-Host "Using csv file from script directory."
    $CsvPath = '.\serials.csv'
}
else {
    $CsvPath = Read-Host -Prompt "Where is serials.cvs? (do surround with quotes)"
}

# Set group tag
$groupTag = Read-Host "Enter Group Tag"
$serialNumbers = Get-Content -Path $csvPath | Sort-Object -unique

clear-host
Write-Host "Applying group tag: '$groupTag' to $($serialNumbers.count) serial numbers."
Write-Host ''
$confirmation = Read-Host -Prompt "     Continue? [y/n]"
        while($confirmation -ne "y"){
                if ($confirmation -eq 'n') {
                    Write-Host "Ok. Bye!"
                    exit
                }
                $confirmation = Read-Host "uhh..let's try that again...Continue? [y/n]"
            }


foreach ($serialNumber in $serialNumbers) {
    
    # Remove S from the start of serial number (PO tracker tends to add a letter S to some devices' serial numbers...)
    if ( $serialNumber.StartsWith('S')){ 
        $serialNumber = $serialNumber.substring(1)
    }
    if ( $serialNumber.StartsWith('s')){ 
        $serialNumber = $serialNumber.substring(1)
    }
        

    $apiUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?filter=contains(serialNumber,'"+$serialNumber+"')"
    $restResponse = Invoke-RestMethod -Headers @{Authorization = "Bearer $($Token.AccessToken)"} -Uri $apiUrl -Method Get
    $deviceId = $restResponse.value.id
    if ( $null -eq $deviceId ){
        Write-Host "$serialNumber not in AutoPilot."
        $NonAPCounter++
    }
    else{
        $apiUrl = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$deviceId/UpdateDeviceProperties"
        $body = "{`"groupTag`":`"$groupTag`"}"
        try { $SetTag = Invoke-WebRequest -Headers @{Authorization = "Bearer $($Token.AccessToken)"} -Uri $apiUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction SilentlyContinue
            Write-Host "$serialNumber Successful"
            $Counter++
        }
        catch {
            try {
                Write-Host "Request for $serialNumber timed out...Trying again." -ForegroundColor "Red"
                $SetTag = Invoke-WebRequest -Headers @{Authorization = "Bearer $($Token.AccessToken)"} -Uri $apiUrl -Method Post -Body $body -ContentType 'application/json' -ErrorAction SilentlyContinue
                Write-Host "$serialNumber Successful on retry!" -ForegroundColor "Green"
                $Counter++
            }
            catch{   
                Write-Host "$serialNumber FAILED!" -ForegroundColor "Red"
                $CounterFailed++
            }
        }
    }
}

Write-Host ""
Write-Host ""
Write-Host "$Counter device(s) set to $groupTag"
Write-Host "$NonAPCounter device(s) not AutoPilot enrolled."
Write-Host "$CounterFailed device(s) failed!"
Write-Host ""
Read-Host -Prompt "Press Enter to exit"
exit
