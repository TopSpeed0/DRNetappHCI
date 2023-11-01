# Yes-No prompt
function Get-YesNo ($MessageboxTitle,$Messageboxbody) {
    # https://4sysops.com/archives/how-to-display-a-pop-up-message-box-with-powershell/
    Add-Type -AssemblyName PresentationCore,PresentationFramework
    $ButtonType = [System.Windows.MessageBoxButton]::YesNo
    if ($null -eq $MessageboxTitle) { $MessageboxTitle = "Yes or No" }
    if ($null -eq $Messageboxbody) { $Messageboxbody = "Are you sure you want to do this task ?" }
    
    $MessageIcon = [System.Windows.MessageBoxImage]::Warning
    [System.Windows.MessageBox]::Show($Messageboxbody,$MessageboxTitle,$ButtonType,$messageicon)
    
}
# Get-YesNo

function Get-GridMenu ($MessageboxTitle,$options) {
# Define the options for the menu
if ($null -eq $options) {$options = @("Yes", "No")}

# Create the menu
$gridView = $options | Out-GridView -Title $MessageboxTitle -OutputMode Single

# Bring the Out-GridView window to the front of the user interface
$gridView.BringToFront()
}

