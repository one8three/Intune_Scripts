# Get Group Name
param (
    [Parameter(mandatory=$true)]
    [string] $GroupName
)

# Define variables
$RemovedCount = 0
$Failed = 0
$NonIntune = 0
$Global:Devices = @()
$Global:CartCount= 1
$Groups = @()

# Function to recursively gather devices from groups
function Get-AzureADGroupMemberNested($ObjectId) {
    $GroupName = (Get-AzureADGroup -ObjectId $ObjectID).DisplayName
	Write-Host "Getting devices from '$GroupName'..."
    #Get the members of this group
	$members = Get-AzureADGroupMember -ObjectId $ObjectID -All $true
	foreach ($member in $members)
	{
		if ($member.ObjectType -eq "Group")
		{	
            $Global:CartCount++
			#If member is a group then recursively look at group membership
			Get-AzureADGroupMemberNested -ObjectId $member.ObjectID
		} elseif ($member.ObjectType -eq "Device") {
			#If member is a device add to array to be processed
			$Global:Devices += $member.DisplayName
		}
	}
}

# BEGIN SCRIPT
Connect-MSgraph
Connect-MgGraph -Scopes DeviceManagementManagedDevices.ReadWrite.All
Connect-AzureAD


# Get group Object ID from Group Name
$GroupID = (Get-AzureADGroup -Filter "DisplayName eq '$($GroupName)'").ObjectId

Get-AzureADGroupMemberNested($GroupID)


# Remove duplicate device names
$Global:Devices = $Global:Devices | Sort-Object -Unique

Foreach ($IntuneDevice in $Global:Devices){
    # Get Graph compatible device ID for each device
    $GraphDevices = (Get-IntuneManagedDevice -Filter "deviceName eq '$($IntuneDevice)'").id
    
    # If device exists in Intune delete the primary user
    if ($GraphDevices){
        foreach ($GraphDevice in $GraphDevices){
            try {
                Write-Host "Deleting Primary user for $IntuneDevice"
                Invoke-GraphRequest -uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$GraphDevice/users/`$ref" -Method DELETE 
                $RemovedCount++
            }
            # If delete fails, retry
            catch {
                try {
                    Write-Host "Retrying for $IntuneDevice..." -ForegroundColor Yellow
                    Invoke-GraphRequest -uri "https://graph.microsoft.com/v1.0/deviceManagement/managedDevices/$GraphDevice/users/`$ref" -Method DELETE 
                    $RemovedCount++
                }
                # Count failure on second failed attempt
                catch {
                    Write-Host "$IntuneDevice FAILED!" -ForegroundColor Red
                    $Failed++
                }
            }
        }
    }
    # If device is not found in Intune, skip it.
    else {
        Write-Host "$IntuneDevice not in Intune. Skipping."
        $NonIntune++
    }
}

Write-Host ""
Write-Host ""
Write-Host "Processed $CartCount group(s)" -ForegroundColor Green
Write-Host "Removed primary user from $RemovedCount devices." -ForegroundColor Green
Write-Host "$Failed device(s) errored...might not exist?" -ForegroundColor Red
Write-Host "$NonIntune devices were not in Intune." -ForegroundColor Yellow
