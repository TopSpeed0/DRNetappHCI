#
# Script module for module 'DRNetappHCI'
#
# Load all root files
"function\General", "function\SolidFire", "function\VMware", "function\MultiFunction"  | ForEach-Object {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $_) -Filter '*.ps1' | ForEach-Object {
       $pathToFile = $_.FullName
       try {
          . $pathToFile
       } catch {
          Write-Error -Message "Failed to import file $($pathToFile): $_"
       }
    }
 }
####################################################################################################################################