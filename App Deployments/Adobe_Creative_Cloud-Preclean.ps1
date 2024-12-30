# Universal Adobe App Uninstaller for old Creative Cloud apps
# Will uninstall all old versions of apps that are being installed
# Relies on AdobeUninstaller.exe

####################################################################################################
############################ Nothing below should need to be edited ################################
####################################################################################################

# Get package name for logging
$PackageName = (Get-ChildItem "$PSScriptRoot\..\" -filter *.ccp).BaseName
$PackageName = $PackageName.Replace(" ","_")
$Date = Get-Date -Format yyyyMMddhhmm

# Start log
Start-Transcript -Path "C:\Logs\AppDeploy-PreClean-$PackageName-$Date.log"

# Get the apps and versions that will be installed
$PackageInfo = (Get-Content -Path $PSScriptRoot\..\PackageInfo.txt | Where-Object {$_ -match "\b[A-Z]{3,4} \(\d+\.\d+(\.\d+)?\)"}) -split "`n"

# Initialize NewApps hash table
$NewApps = @{}

# Loop through each line and add app/version to hash table
foreach ($App in $PackageInfo) {
    if ($App -match "CCDA") {
        # Skip Creative Cloud App
    } elseif ($App -match '([A-Z]{3,4}) \((\d+\.\d+(\.\d+)?)\)') {
        $key = $matches[1]
        $value = $matches[2]
        $NewApps[$key] = $value
    }
}

#----------------------------Set working dir to $PSScriptRoot--------------------------------------#
Set-Location $PSScriptRoot

#----------------------------Rename columns to match AdobeUninstaller.exe output--------------------------#
$NewApps = $NewApps.GetEnumerator() |
ForEach-Object {
    [PSCustomObject]@{
        SAPCode = $_.Key
        BaseVersion = $_.Value
        }
}
    

#----------------------------Build list of installed apps------------------------------------------#
$UninstallXML = (.\AdobeUninstaller.exe --list --format=XML).Replace('AdobeUninstaller exiting with Return Code (0)','')
$UninstallXML = [xml]$UninstallXML
$InstalledApps = @($UninstallXML.UninstallXML.UninstallInfo.Products.Product)

#----------------------------Exit if no old Adobe CC apps are installed----------------------------#
if(!$InstalledApps){
    Write-Host "No old Adobe CC apps detected."
    Exit
}

#----------------------------Create $UninstallList variable----------------------------------------#
$UninstallList = ""

#----------------------------For each installed app, add to uninstall string if it is older than the new
Foreach($InstalledApp in $InstalledApps){
    # Reset $MatchingNewApp
    $MatchingNewApp = $null
    # Filter to matching apps
    $MatchingNewApp = $NewApps | Where-Object {$_.SAPCode -eq $InstalledApp.SAPCode}

    # If there is a matching app and the install one is older than the new one, add the installed app to the uninstall list
    if(($MatchingNewApp) -and ([System.Version]$MatchingNewApp.BaseVersion -gt [System.Version]$InstalledApp.BaseVersion )){
        $UninstallList = $UninstallList + "$($InstalledApp.SAPCode)" + "#" + "$($InstalledApp.BaseVersion),"
    }
}


#----------------------------If uninstall list exists, proceed to uninstall
if($UninstallList.Length -gt 0){
    #----------------------------Remove last comma from uninstall list string--------------------------#
    $UninstallList = $UninstallList.Substring(0,$UninstallList.Length-1)

    #----------------------------Report which apps will be uninstalled---------------------------------#
    Write-Host "Uninstalling the following applications:" -ForegroundColor DarkYellow
    Write-Host "$($UninstallList.Split(','))"

    #----------------------------Run the uninstalls----------------------------------------------------#
    cmd /c "start /B /wait `"`" `".\AdobeUninstaller.exe`" --products=$UninstallList" 
}

Stop-Transcript

