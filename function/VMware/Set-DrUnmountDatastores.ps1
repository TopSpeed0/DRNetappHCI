function Set-DrUnmountDatastores {
    Param(
        # Specifies a vCenter server name.
        [Parameter(Position=0,mandatory=$true)]
        [string]$VIServer, 
        # Specifies a datastore folder name.
        [Parameter(Position=1,mandatory=$true)]
        [string]$DatastoreName
    )
    
	<#
	.SYNOPSIS
	A script to unmount and detach datastores from VMWare vCenter.  

	.DESCRIPTION
	This script unmounts datastores from vCenter if they are in maintenance mode, reside in the specified folder, and the name matches the specified regular expression.

	The VMware PowerCLI module is required and a connection to vCenter (Connect-VIServer) must be established before running the script. 

	.EXAMPLE
	Unmount-Datastores.ps1 -VIServer vcenter.domain.local -DatastoreName "Datastore" 
	This command will unmount and detach datastores in the vcenter.domain.local vCenter that with names that -eq Datastore.
	
	.LINK
	https://kb.vmware.com/s/article/2004605
	
	#>

	$MaintenanceModeDatastores = Get-Datastore -Name $DatastoreName -Server $ViServer | Where-Object {$_.State -eq "Maintenance" -And $_.Name -eq $DatastoreName}

	$UnMounted = @()
	foreach ($MaintenanceModeDatastore in $MaintenanceModeDatastores)
	{   
		$datastoreHostInfo = Get-VmHost -Server $viserver -Id ($MaintenanceModeDatastore.ExtensionData.Host.Key)
		$CanonicalName = $MaintenanceModeDatastore.ExtensionData.Info.Vmfs.Extent[0].Diskname
		Write-Host "        Processing $($MaintenanceModeDatastore)..." 
		foreach ($vmHost in $datastoreHostInfo)
		{
			$unmount = [PSCustomObject]@{
				Datastore = $MaintenanceModeDatastore.Name
				DsUuid = $MaintenanceModeDatastore.ExtensionData.info.Vmfs.uuid
				LunUuid = (Get-ScsiLun -Server $viserver -VmHost $vmHost | Where-Object {$_.CanonicalName -eq $CanonicalName}).ExtensionData.Uuid
				Host = $vmHost.name
				CanonicalName = $CanonicalName
				UnmountTime = $null             
				}

			$hostMountInfo = $MaintenanceModeDatastore.ExtensionData.Host | Where-Object {$_.Key -eq $VMHost.Id}
			if($hostMountInfo.MountInfo.Mounted -eq "True")
			{	
				# $color=@('gray','red','DarkGreen','DarkMagenta','Cyan','Blue','Yellow')
				# Write-Host "        Unmounting $($unmount.Datastore) from host $($VMHost.Name)" -ForegroundColor (Get-random $color)
				$hostStorageSystem = Get-View $VMHost.Extensiondata.ConfigManager.StorageSystem
				$hostSTorageSystem.UnmountVmfsVolume($unmount.DsUuid)
				# $hostStorageSystem.DetachScsiLun($unmount.LunUuid)
				
			} else {
				write-host "        $($unmount.Datastore) not mounted on $($VMhost.Name)"
			}
			$unmount.UnmountTime = Get-Date -Format "s"
			$UnMounted += $unmount
		}
		
	}
}
