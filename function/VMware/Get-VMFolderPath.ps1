Function Get-VMFolderPath {

    param([string]$VMFolderId)

    $Folders = [system.collections.arraylist]::new()
    $tracker = Get-Folder -Id $VMFolderId
    $Obj = [pscustomobject][ordered]@{FolderName = $tracker.Name; FolderID = $tracker.Id}
    $null = $Folders.add($Obj)

    while ($tracker) {
       if ($tracker.parent.type) {
        $tracker = (Get-Folder -Id $tracker.parentId)
        $Obj = [pscustomobject][ordered]@{FolderName = $tracker.Name; FolderID = $tracker.Id}
        $null = $Folders.add($Obj)
           }
           else {
        $Obj = [pscustomobject][ordered]@{FolderName = $tracker.parent.name; FolderID = $tracker.parentId}
        $null = $Folders.add($Obj)
            $tracker = $null
       }
    }
    $Folders.Reverse()
    $Folders.FolderName -join "/"
}