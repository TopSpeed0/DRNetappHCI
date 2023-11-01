function Invoke-DrVMfolderMapping {
    param (
    $datacenter
    )

    $ALLfolder = get-datacenter $datacenter | Get-Folder -Type VM
    #$ALLfolder = get-folder -Type VM
    
    # Initialize collection of paths
    $folder_collection = New-Object System.Collections.ArrayList

    foreach ( $folder in $ALLfolder) {
        # Get-VMFolderPath 
        # Set properties
        
        $VMFoldermMap = @{
            Name = $folder.name
            FolderID = $folder.id
            VMFolderPath= (Get-VMFolderPath $folder.id)
            ReletivePath= (Get-VMFolderPath $folder.id).split('/vm')[1]
        }

        # Create object
        $folder_object = New-Object -TypeName PSObject -Property $VMFoldermMap
        $folder_collection.Add($folder_object) | Out-Null
    }
    $folder_collection
}

# ($folder_collection | ? { $_.Reletivepath -in $VMlist.Reletivepath }).FolderID
# Get-folder -id  ($folder_collection | ? { $_.Reletivepath -in $VMlist.Reletivepath }).FolderID