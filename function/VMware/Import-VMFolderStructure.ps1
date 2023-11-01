function Import-VMFolderStructure {
    <#
    .SYNOPSIS
    Create a vCenter VM folder structure using an imported .csv.

    .DESCRIPTION
    With Import-VMFolderStructure you can create a vCenter VM folder structure using a .csv created with Export-VMFolderStructure. It's highly recommended to import into an empty VM folder structure.

    .PARAMETER Path
    Full path of the .csv file. Example: C:\Export\export.csv
    
    .PARAMETER Datacenter
    Datacenter name. If no datacenter specified and there's only one datacenter we use it.

    .PARAMETER Server
    IP or DNS name of the VIServer. If already connected to a VIServer this parameter will be ignored.

    .EXAMPLE
    Import-VMFolderStructure -Path C:\Export\export.csv -Datacenter "Datacenter test" -Server 192.168.111.111

    .NOTES
    Name: Import-VMFolderStructure
    Author: Marc Meseguer
    Moded: Yitzhak Bohadana
    Version 1.0.1
    - Initial release.
    #>
    [CmdletBinding()]
    param (
        # Path to the file to import
        [Parameter(Mandatory=$true)]
        [ValidateScript({Test-Path $_ -PathType Leaf})]
        [string]$Path,
        # Datacenter name. If no datacenter specified and there's only one datacenter we use it.
        [Parameter(Mandatory=$true)]
        [string]$Datacenter,
        # IP or DNS name of the VIServer. If already connected to a VIServer this parameter will be ignored.
        [string]$Server
)
    begin {
        # Initialize disconnect flag.
        $disconnect = $false

        # If not connected to VIServer and no server is specified drop error.
        if (!$global:defaultviserver -and !$Server)
        {
            Write-Error 'You are not connected to any server, you must connect to a vCenter Server or specify one.' -ErrorAction Stop
        }
        # If not connected to VIServer but a server is specified we try to connect
        elseif (!$global:defaultviserver) {
            try {
                Connect-VIServer -Server $Server -ErrorAction Stop | Out-Null
                $disconnect = $true
                Write-Verbose "Connected to $Server"
            }
            catch {
                # If we cannot connect to VIServer drop error
                Write-Error "Error trying to connect to $Server" -ErrorAction Stop
            }            
        }
        else {
            Write-Verbose "Using already connected {$global:defaultviserver.Name}"
        }
        
        # If no Datacenter is specified we check if there's more than one
        if (!$Datacenter -and (Get-Datacenter).Count -ne 1){
            Write-Error "If there's more than one datacenter you have to select one." -ErrorAction Stop
        }
    }

    process {
        # Retrieve collection of folders
        $folders = Import-Csv $Path

        # Retrieve top level VM Folder
        $folder_top = Get-Datacenter $datacenter | Get-Folder -Type VM -name VM
        #Get-Datacenter NetApp-HCI-Datacenter-01-HRZ | Get-Folder -Type VM -name VM

        # Loop through folders
        foreach ($folder in $folders){
            # If there's no path we create the folder under the Datacenter
            if (!$folder.Path){
                try { 
                    $folder_top | Get-Folder $folder.Name -ErrorAction Stop  | Out-Null
                    #
                    Write-Host "TopFolder:" -ForegroundColor Yellow -NoNewline        
                    Write-Host "$($folder.Name)" -ForegroundColor blue -NoNewline
                    Write-Host " exist Skipping ..." -ForegroundColor Yellow
                    " "
                } catch {
                    $folder_top | New-Folder $folder.Name
                }
            }
            # If there's a Path we create the folder under it
            else {
                # Split the path to iterate through it
                $splitted_path = ($folder.Path -split ('\\'))
                # Set the location to the top folder
                $location = $folder_top
                # Iterate through the path to get the last folder of it as the location of the new folder
                foreach ($subpath in $splitted_path){
                    $location = $location | Get-Folder -NoRecursion | Where-Object Name -eq $subpath
                }
                # Create the folder
                try 
                {   
                    # if folder not exist out
                    $location | get-Folder -Name $folder.Name -Type VM -ErrorAction Stop | Where-Object {$_.Name -notin $fexceptions} | Out-Null
                    
                    $curentfolder = $location | get-Folder -Name $folder.Name -Type VM -ErrorAction Stop | Where-Object {$_.Name -notin $fexceptions}
                    ##########
                    # Declaration of special folder to not process them.
                    $fexceptions = "Datacenters","vm","network","datastore","host"

                    # Initialize collection of paths
                    # $folder_collection = New-Object System.Collections.ArrayList

                    # Get all "VM" folders that are not in exceptions.
                    # if ($Datacenter){
                    #     $folders = Get-Datacenter $Datacenter | Get-Folder -Type VM | Where-Object {$_.Name -notin $fexceptions}
                    # }
                    # else {
                    #     $folders = Get-Folder -Type VM | Where-Object {$_.Name -notin $fexceptions}
                    # }
                    # Loop through folders.
                    ForEach ($folder in $curentfolder) {
                        # Initialize path.
                        $fpath = ""
                        # Obtain parent folder.
                        $fparent = $folder.Parent

                        # Loop while a parent folder exist and is not an exception.
                        while ($fparent -and $fparent -notin $fexceptions) {
                            # Append parent to path.
                            $fpath = "$fparent\$fpath"
                            # Move fparent to its own parent.
                            $fparent = $fparent.Parent
                        }
                    
                        # Remove last "\" from the path
                        if ($fpath) {
                            $fpath = $fpath.Substring(0,$fpath.Length-1)
                        }
                        # Set properties
                        $folder_properties = @{
                            Name = $folder.Name
                            Path = $fpath
                        }
                        # Create object
                        $folder_object = New-Object -TypeName PSObject -Property $folder_properties
                        # Add object to collection
                        # $folder_collection.Add($folder_object) | Out-Null
                    }
                    #########
                    Write-Host "Folder: $($folder.Name) exist at location:" -ForegroundColor Yellow -NoNewline
                    Write-Host "\$($folder_object.path)" -ForegroundColor Blue -NoNewline
                    Write-Host "\$($folder_object.name)" -ForegroundColor Blue -NoNewline
                    Write-Host " Skiping ..." -ForegroundColor Yellow 
                    " "
                } catch {
                    $location
                    $location | New-Folder -Name $folder.Name
                }
            }
        }
    }
    end {
        # Disconnect VIServer if connection was stablished by this function.
        if ($disconnect) {
           # Disconnect-VIServer -Confirm:$false    
        }
    }
}