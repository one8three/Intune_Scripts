param (
    [Parameter(mandatory=$false)]
    [switch]$UninstallOnly
)

Set-Location $PSScriptRoot
###############################################################
### Auto-uninstall only works for MSI installers for now... ###
######## Use $DefinedUninstallCmd for .exe installers #########
###############################################################
$NewAppName = "APP_NAME_HERE"       # Put the new app name here (not really important - only used for text output in logs)
$OldAppNames = "OLD_APP_NAME_HERE"  # Put app names that should be uninstalled here. This is regex, so the | operates as an "or".

#---------------Install and Uninstall commands----------------------------------------------
$InstallCmd = "msiexec /i `"MSI_NAME_HERE.msi`" /qn ALLUSERS=1"     # Put the install command here
#$DefinedUninstallCmd = ""          # Use this to define a custom silent uninstall command (will override any uninstall commands from registry)

#---------------EXE detected uninstaller command options------------------------------------------------
#$ReplaceSILENTwVERYSILENT = $true  # Use this to replace "Silent" with "VerySilent" in the auto-detected uninstall string for .exe uninstallers
#$ExeUninstallCmdArgs = ""          # Arguments to add at the end of an auto-detected uninstall command

#--------------Create Desktop shortcut options-----------------------------------------------
$CreateDesktopShortcut = $false      # Set to true to create a desktop shortcut
#$DesktopShortcutName = ""           # This is the shortcut name
#$DesktopShortcutTarget = ""         # This is where the shortcut should point to

#--------------Uninstall status options--------------------------
# Sometimes needs to be set if apps don't uninstall properly. Rarely needed.
$AllowUncleanUninstall = $false

#--------------Pre/Post-install options-------------------------------------------------------
$PreUninstall = $false    # Set to true if pre-uninstall commands are required. Set them in the Invoke-Preuninstall function below. 
$PostUninstall = $false   # Set to true if post-uninstall commands are required. Set them in the Invoke-Postuninstall function below

#--------------Pre/Post-install options-------------------------------------------------------
$PreInstall = $false    # Set to true if pre-install commands are required. Set them in the Invoke-Preinstall function below. 
$PostInstall = $false   # Set to true if post-install commands are required. Set them in the Invoke-Postinstall function below

# Put anything that should happen BEFORE installation in this function. Leave empty if unrequired.

function Invoke-PreUninstall {
    Write-Host "Running defined pre-uninstall commands."
    
    # Put pre-uninstall commands here:
    

    # End pre-uninstall commands
}

function Invoke-PreInstall {
    Write-Host "Running defined pre-install commands."
    # Put pre-install commands here:
    Write-Host "Applying backedup "

    # End pre-install commands
}

# Put anything that should happen AFTER installation in this function. Leave empty if  not required.
function Invoke-Postinstall {
    Write-Host "Running defined post-install commands"
    # Put post-install commands here:

    # End post-install commands
}

#------------Limit to the number of apps from registry that will be uninstalled
$UninstallLimit = 5    # Limit to number of apps that are allowed to automatically be uninstalled. This is only here to prevent accidentally uninstalling a lot of apps. Rarely will need to be changed.

########################################################
########################################################
##### NOTHING BELOW THIS SHOULD NEED TO BE CHANGED #####
########################################################
########################################################
# Create Shortcut Function
function New-Shortcut {
    param (
        [string(mandatory)]
        $Name,
        [string(mandatory)]
        $Target
    )
    
    $WshShell = New-Object -comObject WScript.Shell
    $Shortcut = $WshShell.CreateShortcut("C:\Users\Public\Desktop\$Name.lnk")
    $Shortcut.TargetPath = $Target
    #$Shortcut.Arguments = "--kiosk $Url --edge-kiosk-type=public-browsing --kiosk-idle-timeout-minutes=10"
    $Shortcut.Save()

}

# Run pre-uninstall commands
If($PreUninstall){
    Invoke-PreUninstall
}

#### Uninstall Previous versions
## Create app arrays
$UnwantedApps = @()
$InstalledApps = @()
$UnwantedAppStatus = 0
# Get list of all installed apps
$InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
$InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"             # 64 Bit
# Get unwanted/old apps
$UnwantedApps += $InstalledApps | Where-Object {$_.DisplayName -match $OldAppNames} | Sort-Object -Property UninstallString -Unique
# $UnwantedApps = $UnwantedApps | Sort-Object -Property UninstallString -Unique

# Don't automatically continue if uninstall app count is higher than the limit, unless running as system
if (($UnwantedApps.Count -gt $UninstallLimit) -and ($env:USERNAME -notmatch "SYSTEM")){
    $Answer = $null
    While ($Answer -ne "y"){
        Write-Host "Uninstalling the following apps:
        $($UnwantedApps.DisplayName)"
        $Answer = Read-Host -Prompt "$UninstallLimit or more apps will be uninstalled. Continue? [y/n]"
        if ($Answer -eq "n"){exit}
    }
} elseif (($UnwantedApps.Count -gt $UninstallLimit) -and ($env:USERNAME -match "SYSTEM")){
    Write-Host "Uninstalling:
        $($UnwantedApps.DisplayName)"
    Write-Host "Too many apps would be uninstalled...something is probably not right." -ForegroundColor DarkRed
    exit
}


#---------------------- Uninstall all old/unwanted apps ------------------------------------------#
# If user defined uninstall command is set. Use that to uninstall.
If($DefinedUninstallCmd -and $UnwantedApps.Count -ge 1){
    Write-Host "Performing user defined uninstall command:"
    Write-Host "    $DefinedUninstallCmd"
    cmd /c "$DefinedUninstallCmd"
# Else if, no user defined uninstall is set. Use auto-detected uninstall commands.
}elseif($UnwantedApps.Count -ge 1){

    foreach ($App in $UnwantedApps){
        # Refresh installed apps
        $InstalledApps = @()
        $InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
        $InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"             # 64 Bit

        # If app is still installed, uninstall it
        if ($InstalledApps.DisplayName -contains $App.DisplayName){

            # Build uninstall command for MSI
            if(($App.QuietUninstallString) -and ($App.QuietUninstallString -match "msiexec")){
                $MsiCode = $App.QuietUninstallString -replace "^.*{","{" -replace "}.*","}"
                $MsiUninstallCmd = "msiexec.exe /X$MsiCode /qn"
            } elseif (($App.UninstallString) -and ($App.UninstallString -match "msiexec")) {
                $MsiCode = $App.UninstallString -replace "^.*{","{" -replace "}.*","}"
                $MsiUninstallCmd = "msiexec.exe /X$MsiCode /qn"
            }

            # Get uninstall string for EXEs, preferring "QuietUninstallString"
            if(($App.QuietUninstallString) -and ($App.QuietUninstallString -match "\.exe")){
                $ExeUninstallCmd = $App.QuietUninstallString
            } elseif (($App.UninstallString) -and ($App.UninstallString -match "\.exe")) {
                $ExeUninstallCmd = $App.UninstallString
            }
            
            if ($ReplaceSILENTwVERYSILENT){
                $ExeUninstallCmd = $ExeUninstallCmd.Replace("SILENT","VERYSILENT")
            }

            # Perform the uninstall
            if ($MsiUninstallCmd){
                Write-Host "Uninstalling $($App.DisplayName)..."
                Write-Host "Uninstall cmd: $MsiUninstallCmd"
                cmd /c "$MsiUninstallCmd"
            } elseif ($ExeUninstallCmd -match "C\:\\Program Files"){
                ####################
                ##### FIX ME #######
                ####################
                # Skip EXE uninstall if it contains spaces...not working yet.
                Write-Host "EXE uninstall command contains spaces. This is not yet supported by the script." -ForegroundColor DarkYellow
            } elseif ($ExeUninstallCmd){
                # Display the uninstall command (for troubleshooting)
                Write-Host "Uninstalling $($App.DisplayName)..."
                Write-Host "Uninstall cmd: $ExeUninstallCmd $ExeUninstallCmdArgs"
                cmd /c "$ExeUninstallCmd $ExeUninstallCmdArgs"
            }
            
      
            # Check if uninstall worked
            $AppsTest = @()
            $AppsTest += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
            $AppsTest += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"             # 64 Bit

            if ($AppsTest.DisplayName -contains $App.DisplayName){
                Write-Host "WARNING: $($App.DisplayName) still detected but continuing..." -ForegroundColor DarkYellow
                $UnwantedAppStatus++
            } else {
                Write-Host "$($App.DisplayName) uninstalled." -ForegroundColor DarkGreen
            }
        } else {
            Write-Host "$($App.DisplayName) already uninstalled." -ForegroundColor DarkGreen
        }
    }

    # Delete desktop shortcut
    If($CreateDesktopShortcut){
        Remove-Item -Path "C:\Users\Public\$DesktopShortcutName.lnk"
    }

}

# Perform final app uninstall check
$AppsTest = @()
$AppsTest += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
$AppsTest += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"             # 64 Bit


# Give status of old app uninstallations
if ($UnwantedApps.Count -lt 1 -or $null -eq $UnwantedApps.Count){
    Write-Host "No old version of $NewAppName detected. Nothing to uninstall." -ForegroundColor DarkGreen
}elseif (($UnwantedAppStatus -ne 0) -and (($AppsTest.DisplayName -match $App.DisplayName) -or ($DefinedUninstallCmd)) -and ($AllowUncleanUninstall -eq $true)){
    Write-Host "Not all old versions could be removed...continuing anyway because unclean uninstall is allowed." -ForegroundColor DarkYellow
}elseif (($UnwantedAppStatus -ne 0) -and (($AppsTest.DisplayName -match $App.DisplayName) -or ($DefinedUninstallCmd)) -and ($AllowUncleanUninstall -eq $false)){
    Write-Host "ERROR: Old versions of $NewAppName did not uninstall cleanly. Exiting without intallation." -ForegroundColor DarkRed
    exit
} elseif (($UnwantedAppStatus -ne 0) -and ((!($AppsTest.DisplayName -match $App.DisplayName)) -or ($DefinedUninstallCmd))) {
    Write-Host "Some app uninstallation errors or warnings may have been reported but $NewAppName did uninstall successfully." -ForegroundColor DarkGreen
} elseif (($UnwantedAppStatus -eq 0) -and ((!($AppsTest.DisplayName -match $App.DisplayName)) -or ($DefinedUninstallCmd))) {
    Write-Host "All old versions of $NewAppName uninstalled successfully." -ForegroundColor DarkGreen
} else {
    Write-Host "Uhh...not sure what happened...but let's continue anyway."
}

# Run post-uninstall commands
If($PostUninstall){
    Invoke-PostUninstall
}



if(!$UninstallOnly){
    # Run pre-install commands
    If($PreInstall){
        Invoke-Preinstall
    }

    #### Install new version
    Write-Host "Installing $NewAppName..."
    cmd /c "$InstallCmd"
    #Start-Process -Filepath '.\setup.exe' -ArgumentList "--silent" -Wait -NoNewWindow # This is the old way

    if($CreateDesktopShortcut){
        New-Shortcut -Name $DesktopShortcutName -Target $DesktopShortcutTarget
    }

    # Run post-install commands
    If($PostInstall){
        Invoke-Postinstall
    }
}
