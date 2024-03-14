[CmdletBinding()]
param (
    [Parameter(Mandatory=$true)]
    [String]$CSVPath
)

# Parsing HTML is broken so it must be done manually...
Function ConvertTo-NormalHTML {
    param([Parameter(Mandatory = $true, ValueFromPipeline = $true)]$HTML)

    $NormalHTML = New-Object -Com "HTMLFile"
    $NormalHTML.IHTMLDocument2_write($HTML.RawContent)
    return $NormalHTML
}

$Date = Get-Date -Format yyyyMMdd


# Hide Invoke-Webrequest progress bar because it makes things SLOW
$ProgressPreference = 'SilentlyContinue'

#------- Create objects ------------------------------------------------------------------------------------------
$AllExtensionIDs = @() # Array of extension IDs
$FinalExtensionData = @() # Array to build final data and export to CSV
#------- Define built-in extensions ------------------------------------------------------------------------------
$BuiltInExtensions = @(
    'nmmhkkegccagdldgiimedpiccmgmieda',
    'mhjfbmdgcfjbbpaeojofohoefgiehjai',
    'pkedcjkdefgpdelpbcmbmeomcjbeemfm'
)


#------- Gather all extension IDs from spreadsheet ---------------------------------------------------------------
#------- Import the spreadsheet ----------------------------------------------------------------------------------
$Spreadsheet = Import-CSV -Path $CSVPath 
#------- Separate extension IDs and remove duplicates
$AllExtensionIDs = $Spreadsheet.PreRemediationDetectionScriptOutput.Split(',') | Sort-Object -Unique

#------- For each Extension ID... --------------------------------------------------------------------------------
#------- Get extension name and create array for spreadsheet -----------------------------------------------------
Foreach($ExtensionID in $AllExtensionIDs){
    #--- Reset variables just because ----------------------------------------------------------------------------
    $Request = $null
    $ExtName = $null
    $NumberOfDevices = $null
    $URL = $null
    $ThisExtension = $ExtensionID

    #--- Filter out built-in extensions --------------------------------------------------------------------------
    if($BuiltInExtensions -contains $ThisExtension){
        if($ThisExtension -eq "nmmhkkegccagdldgiimedpiccmgmieda"){
            $ExtName = "Google Wallet (Built-in)"
        } elseif($ThisExtension -eq "mhjfbmdgcfjbbpaeojofohoefgiehjai"){
            $ExtName = "Chrome PDF Viewer (Built-in)"
        }elseif($ThisExtension -eq "pkedcjkdefgpdelpbcmbmeomcjbeemfm"){
            $ExtName = "Chromecast (Built-in)"
        }
    } else { 
    #--- Get Extension Name from Extension ID --------------------------------------------------------------------
        #--- Try to get name from Chrome store -------------------------------------------------------------------
        try{
            #--- Build URL ---------------------------------------------------------------------------------------
            $URL = "https://chrome.google.com/webstore/detail/" + "$ExtensionID" + "?hl=en-us"
            #--- Request info from Chrome store ------------------------------------------------------------------
            $Request = Invoke-Webrequest -Uri $URL -UseBasicParsing
            #--- If web request succeeded, get name data ---------------------------------------------------------
            if($Request.StatusCode -eq 200){
                $ParsedHTML = ConvertTo-NormalHTML -HTML $Request
                $ExtName = $ParsedHtml.IHTMLDocument2_nameProp
            } else { # Otherwise, set name to "Unknown"
                $ExtName = "Unknown"
            }
        }catch{
            #--- If web request totally failed, just set extension name to "Unknown" and continue ----------------
            $ExtName = "Unknown"
        }
    } # --- Name has been set

    #--- Get number of devices with extension --------------------------------------------------------------------
    $NumberOfDevices = ($Spreadsheet.PreRemediationDetectionScriptOutput | Where-Object {$_ -match $ExtensionID}).Count
    
    #--- Build object with extension data ------------------------------------------------------------------------
    #--- Set Extension ID
    $ThisExtension | Add-Member -MemberType NoteProperty -Name "ExtensionID" -Value $ExtensionID
    #--- Set extension name
    $ThisExtension | Add-Member -MemberType NoteProperty -Name "ExtensionName" -Value $ExtName
    #--- Set number of devices with extension
    $ThisExtension | Add-Member -MemberType NoteProperty -Name "NumberOfDevices" -Value $NumberOfDevices

    #--- Add $ThisExtension data to final spreadsheet array -----------------------------------------------------------
    $FinalExtensionData += $ThisExtension

    # Export after each extension to save progress
    $FinalExtensionData | `
        Select-Object -Property ExtensionName,ExtensionID,NumberOfDevices | `
        Sort-Object -Property NumberOfDevices -Descending | `
        Export-Csv -Path "$PSScriptRoot\Chrome_Extensions-$Date.csv" -Force -NoTypeInformation
    
}

# Do a final export at the end
$FinalExtensionData | `
    Select-Object -Property ExtensionName,ExtensionID,NumberOfDevices | `
    Sort-Object -Property NumberOfDevices -Descending | `
    Export-Csv -Path "$PSScriptRoot\Chrome_Extensions-$Date.csv" -Force -NoTypeInformation
