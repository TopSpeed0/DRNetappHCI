function Export-VMFolderStructure {
    <#
    .SYNOPSIS
    Exports a csv file with all VM folders and their paths.

    .DESCRIPTION
    With Export-VMFolderStructure you can get a csv file with the full path of all VMware vCenter's VM folders in order to recreate them in another vCenter Server.

    .PARAMETER Path
    Full path of the .csv file. Example: C:\Export\export.csv
    
    .PARAMETER Datacenter
    Datacenter name. If no datacenter specified and there's only one datacenter we use it.

    .PARAMETER Server
    IP or DNS name of the VIServer. If already connected to a VIServer this parameter will be ignored.

    .EXAMPLE
    Export-VMFolderStructure -Path C:\Export\export.csv -Datacenter "Datacenter test" -Server 192.168.111.111

    .NOTES
    Name: Export-VMFolderStructure
    Author: Marc Meseguer
    Moded: Yitzhak Bohadana
    Version 1.0.1
        - Initial release.
    #>
    [CmdletBinding()]
    param (
        # Path to the file to export
        [Parameter(Mandatory = $true)]
        [ValidateScript({ Test-Path (Split-Path $_) -PathType Container })]
        [string]$Path,
        # Datacenter name. If no datacenter specified and there's only one datacenter we use it.
        [string]$Datacenter,
        # IP or DNS name of the VIServer. If already connected to a VIServer this parameter will be ignored.
        [string]$Server
    )
        
    begin {
        # Initialize disconnect flag.
        $disconnect = $false

        # Promt Host About Exporting the VMs Folder Structure
        if ((Get-YesNo -MessageboxTitle "Export-VMFolderStructure" -Messageboxbody "You are about to Export the VMs Folder Structure ?") -eq 'No') { 
            Write-host "        You desided to not export VMfolders" -NoNewline
            pause
            $DontExport = $true 
        } 
        else {
            Write-host "        Export the VMs Folder Structure" -ForegroundColor Green
        }

        # If not connected to VIServer and no server is specified drop error.
        if (!$global:defaultviserver -and !$Server) {
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
        if (!$Datacenter -and (Get-Datacenter).Count -ne 1) {
            Write-Error "If there's more than one datacenter you have to select one." -ErrorAction Stop
        }

    }
    process {
        if (!($DontExport -eq $true)) { 
            # Declaration of special folder to not process them.
            $fexceptions = "Datacenters", "vm", "network", "datastore", "host"
        
            # Initialize collection of paths
            $folder_collection = New-Object System.Collections.ArrayList

            # Get all "VM" folders that are not in exceptions.
            if ($Datacenter) {
                $folders = Get-Datacenter $Datacenter | Get-Folder -Type VM | Where-Object { $_.Name -notin $fexceptions }
            }
            else {
                $folders = Get-Folder -Type VM | Where-Object { $_.Name -notin $fexceptions }
            }
            # Loop through folders.
            ForEach ($folder in $folders) {
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
                    $fpath = $fpath.Substring(0, $fpath.Length - 1)
                }
                # Set properties
                $folder_properties = @{
                    Name = $folder.Name
                    Path = $fpath
                }
                # Create object
                $folder_object = New-Object -TypeName PSObject -Property $folder_properties
                # Add object to collection
                $folder_collection.Add($folder_object) | Out-Null
            }
        }
    }
        
    end {
        # Disconnect VIServer if connection was stablished by this function.
        if ($disconnect) {
            Disconnect-VIServer -Confirm:$false    
        }
        if (!($DontExport -eq $true)) { 
            # Export sorted collection of paths (for a correct recreation of folders).
            $folder_collection | Sort-Object -Property Path | Export-Csv -Path $Path -NoTypeInformation -Encoding unicode
        }
    }
}
