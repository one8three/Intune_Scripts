function Get-InstalledAppInfo {
    param (
        [Parameter()]
        [string]$AppNameMatch,
        [Parameter()]
        [string]$AppNameLike
        
    )

    #-------------------Set $InstalledApps to empty array
    $InstalledApps = @()

    #-------------------Get list of all installed apps
    $InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" # 32 Bit
    $InstalledApps += Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"             # 64 Bit

    #-------------------Search Installed App array
    if($AppNameMatch){
        $SearchResult = $InstalledApps | Where-Object {$_.DisplayName -Match "$AppNameMatch"} | Sort-Object -Property DisplayName | Select-Object -Property DisplayName,uninstallstring,QuietUninstallString,DisplayVersion,Estimatedsize,Publisher,InstallLocation,PSPath
    } elseif ($AppNameLike){
        $SearchResult = $InstalledApps | Where-Object {$_.DisplayName -like "$AppNameLike"} | Sort-Object -Property DisplayName | Select-Object -Property DisplayName,uninstallstring,QuietUninstallString,DisplayVersion,Estimatedsize,Publisher,InstallLocation,PSPath
    }

    $i=0

    Foreach($Result in $SearchResult){
        #------------Clear MSI Code
        $MsiCode = ""

        #------------Set quiet uninstall command
        if(($Result.QuietUninstallString) -and ($Result.QuietUninstallString -match "msiexec")){
            $MsiCode = $Result.QuietUninstallString -replace "^.*{","{" -replace "}.*","}"
            $SearchResult[$i].QuietUninstallString = "msiexec.exe /X$MsiCode /qn"
        } 

        #------------Set uninstall command from standard uninstall command
        elseif ((!$Result.QuietUninstallString) -and ($Result.UninstallString) -and ($Result.UninstallString -match "msiexec")){
            $MsiCode = $Result.UninstallString -replace "^.*{","{" -replace "}.*","}"
            $SearchResult[$i].QuietUninstallString = "msiexec.exe /X$MsiCode /qn"
        }

        #------------Set uninstall command from standard uninstall command
        if(($Result.UninstallString) -and ($Result.UninstallString -match "msiexec")){
            $MsiCode = $Result.UninstallString -replace "^.*{","{" -replace "}.*","}"
            $SearchResult[$i].UninstallString = "msiexec.exe /X$MsiCode"
        }
        
        if($Result.Estimatedsize){
            $Size = $null
            $Size = [int]$Result.Estimatedsize/1KB
            $SearchResult[$i].Estimatedsize = [string]$Size.ToString(".00") + "MB"
        }

        if($Result.PSPath){
            $SearchResult[$i].PSPath = $Result.PSPath.Replace('Microsoft.PowerShell.Core\Registry::','')
        }

        $i++

    }

    $SearchResult

}
