## THIS SCRIPT IS FOR BULK ADDING DEVICES TO AN INTUNE/AzureAD GROUP BASED ON SERIAL NUMBERS. IT WILL TAKE SERIAL NUMBERS FROM .\serials.csv AND MOVE THOSE DEVICES INTO THE GROUP. 
## THE SCRIPT RELIES ON THE FOLLOWING MODULES AND WILL IMPORT THEM: 
##      AzureAD, Microsoft.Graph.Authentication, Microsoft.Graph.Groups, Microsoft.Graph.Intune.

## Serial numbers not found in Intune will be skipped.
## Blank lines will be skipped. 
## Duplicate serial numbers will be filtered.

#Requires -Modules 'AzureAD', 'Microsoft.Graph.Authentication', 'Microsoft.Graph.Groups', 'Microsoft.Graph.Intune'

# Set working directory to the script's location.
Set-Location $PSScriptRoot
#Set Counter
$Global:Counter = 0
$Global:NonIntuneCounter = 0
$Global:BlankLineCounter = 0
$Global:FailedCounter = 0

# Check for serials.csv
if ( ! ( Test-Path -Path .\serials.csv ) ) {
    Clear-Host
    Write-Output ''
    Write-Output "serials.csv missing. We need some serials to move!"
    Read-Host -Prompt "Press Enter to exit"
    exit
}

# Check for required PS Modules
$ReqModule1 = Get-InstalledModule -Name AzureAD -ErrorAction SilentlyContinue
$ReqModule2 = Get-InstalledModule -Name Microsoft.Graph.Authentication -ErrorAction SilentlyContinue
$ReqModule3 = Get-InstalledModule -Name Microsoft.Graph.Groups -ErrorAction SilentlyContinue
$ReqModule4 = Get-InstalledModule -Name Microsoft.Graph.Intune -ErrorAction SilentlyContinue

if((!$ReqModule1) -or (!$ReqModule2) -or (!$ReqModule3) -or (!$ReqModule4)){
    Write-Host "Required modules not installed. Please install the following modules by running the included ""install _required_modules.ps1"" script:
        AzureAD
        Microsoft.Graph.Authentication
        Microsoft.Graph.Groups
        Microsoft.Graph.Intune
        "
    Read-Host "Press [Enter] to exit..."
    exit
}


########################
### DEFINE FUNCTIONS ###
########################

function GetGroup {

    while(($confirmation -ne "y") -and ($null -eq $GroupInfo)){
        # Get group object ID
        $Global:GroupName = Read-Host -Prompt "Enter the name of the group"
        $Global:GroupInfo = Get-MgGroup -Filter "DisplayName eq '$Global:GroupName'" -ErrorAction SilentlyContinue
        
        
        if ($null -eq $GroupInfo){
            Write-Host "
            No group found for "$Global:GroupName". Please try again...
                "
        }

        else{
            $Global:GroupName = $Global:GroupInfo.DisplayName
            Write-Host "
            Found group:
                $Global:GroupName
        "
        

            $confirmation = Read-Host "Add $($AllSerials.count) device(s) to this group? [y/n]"
            if ($confirmation -ne "y"){
                Write-Host "Aborting!"
                Read-Host "Press [ENTER] to exit"
                exit
            }
        }
    }
}

Function MoveToGroup { 

    # Skip blank lines
    if ($DeviceSerial -eq ''){
        Write-Output 'Blank line included...skipping...'
        $Global:BlankLineCounter++
        return;
    }

    # Get Device info from Intune
    $Device = Get-IntuneManagedDevice -Filter "serialNumber eq '$DeviceSerial'"

    if ($null -eq $Device){ 
        Write-Host "$DeviceSerial is not in Intune...Skipping..." -ForegroundColor DarkYellow
        $Global:NonIntuneCounter++
    }
    else {
        foreach ($DuplicateDevice in $Device){
            # Get Azure AD device ID
            $DeviceID = $DuplicateDevice.azureADDeviceId

            # Get device info from Azure AD
            $AADDevice = Get-AzureADDevice -Filter "deviceId eq guid'$DeviceID'"
            # Get device object ID
            $DeviceObjID = $AADDevice.ObjectId
            # Get device name
            $DeviceName = $DuplicateDevice.deviceName
                        
            if ($null -eq $deviceObjID){
                # If device has no Object ID, skip it.
                Write-Host "$DeviceSerial is a duplicate or not an Intune device...skipping..." -ForegroundColor DarkYellow
            }
            else {
                try {
                    New-MgGroupMember -GroupID $Global:GroupInfo.Id -DirectoryObjectID $DeviceObjID -ErrorAction SilentlyContinue
                    Write-Host "$DeviceSerial has been added to '$Global:GroupName'" -ForegroundColor DarkGreen
                    $Global:Counter++
                }
                catch {
                    Write-Host "Failed to add $DeviceSerial!" -ForegroundColor DarkRed
                    $Global:FailedCounter++
                }
            }
        }    
    }
}

Clear-Host
#########################
### BEGIN MAIN SCRIPT ###
#########################

# Sign in to required services
Write-Output "Let's get started!"
Write-Output "  Please sign in to Azure using the popup sign in window(s). You may be prompted up to 3 times."

Connect-MSGraph
Connect-MgGraph -Scopes "Group.ReadWrite.All"
Connect-AzureAD

Clear-Host

# Get the serial numbers from a csv
$AllSerials = Get-Content .\serials.csv | Sort-Object -Unique

GetGroup

# For each serial number, move them to the desired Group
ForEach ($DeviceSerial in $AllSerials) { 
   MoveToGroup
}


Write-Host ""
Write-Host ""
Write-Host "DONE!"
Write-Host "$Global:Counter device(s) moved to the '$Global:GroupName' group." -ForegroundColor DarkGreen
Write-Host "$Global:NonIntuneCounter device(s) not in Intune." -ForegroundColor DarkYellow
Write-Host "$Global:FailedCounter device(s) failed to be added to the group." -ForegroundColor DarkRed
Write-Host 
Read-Host -Prompt "Press [Enter] to exit"
exit
