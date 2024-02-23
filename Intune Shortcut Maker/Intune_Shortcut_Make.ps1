## This script is for creating system-wide shortcuts in the start menu or public desktop.
## Intune "Webapps" deploy per-user which is not ideal in a shared computer environment.
##
## Set parameters via comand line:
##      Intune_Shortcut_Maker.ps1 -Url "https://www.google.com/" -ShortcutName "Google"
##

## Define parameters
param (
    [Parameter(mandatory=$true)]
    [string] $Url, 
    [Parameter(mandatory=$true)]
    [string] $ShortcutName,
    [Parameter(mandatory=$false)]
    [switch]$Desktop,
    [Parameter(mandatory=$false)]
    [switch]$StartMenu
)

##################
## Begin Script ##
##################
Write-Output "Creating shortcut(s) for $url, called $ShortcutName."

## If desktop switch is enabled, create desktop shortcut
if ($Desktop){
    Write-Output "Creating shortcut for $ShortcutName on desktop..."
    $ShortcutPath = "C:\Users\Public\Desktop\$ShortcutName.lnk"
    $Icon = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

    if (Test-Path -Path $ShortcutPath){
        Remove-Item -Path $ShortcutPath
    }

    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $Shortcut = $WScriptObj.CreateShortcut($ShortcutPath)

    $Shortcut.TargetPath = $Url
    $Shortcut.IconLocation = $Icon
    $Shortcut.Save()
}

## If start menu switch is enable, create start menu shortcut
if ($StartMenu){
    Write-Output "Creating shortcut for $ShortcutName in the Start Menu..."
    $ShortcutPath = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\$ShortcutName.lnk"
    $Icon = "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe"

    if ( Test-Path -Path $ShortcutPath ){
        Remove-Item -Path $ShortcutPath
    }

    $WScriptObj = New-Object -ComObject ("WScript.Shell")
    $Shortcut = $WScriptObj.CreateShortcut($ShortcutPath)

    $Shortcut.TargetPath = $Url
    $Shortcut.IconLocation = $Icon
    $Shortcut.Save()
}

## Notify that a switch must be enabled for this script to do anything.
if (!($StartMenu -or $Desktop)){
    Write-Output "Missing Desktop and/or StartMenu switches...no shortcuts made."
}
