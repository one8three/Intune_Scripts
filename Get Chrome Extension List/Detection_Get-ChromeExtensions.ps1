# Deploy this as a remediation script in Intune. Let it run then export the data.

$ExtensionArray = @() # Create extension array
$ExtensionArray += (Get-ChildItem "C:\Users\*\AppData\Local\Google\Chrome\User Data\Default\Extensions\*").Name | Sort-Object -Unique # Get all extensions installed on a device
$ExtensionList = $null # Create extension list string
$ExtensionArray | ForEach-Object {$ExtensionList = $ExtensionList + "$_,"} # Create list of extensions from array
$ExtensionList = $ExtensionList.Substring(0,$ExtensionList.Length-1) # Remove the last comma in list
$ExtensionList # Print extension list
