# Get Intune Chrome Extensions
- Download the 2 scripts in this folder
- Deploy `Detection_Get-ChromeExtensions.ps1` to the desired Windows machines in Intune as a Remediation Script
- Wait for the script to process on devices
- Export the data from the Remediation script
- Run the exported CSV through `Process_Detection_Data.ps1` with:
  - `Process_Detection_Data.ps1 -CSVPath <path CSV from exported data>`
- The script will process the data and export a CSV to the same location as `Process_Detection_Data.ps1`  
  - Chrome_Extensions-yyyyMMdd.csv
