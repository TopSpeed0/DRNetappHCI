# Echo Config for testing
param (
    # import Config json file form Main
    $config,
    $VMwareCredential,
    $SFCredential,
    $FailoverFromSite
)
if ( $null -eq $FailoverFromSite ) {
    $FailoverFromSite = "Source"
}
#       making Sure the Globale Config and Credential Stay obsolete
        $global:config = $config
        $global:VMwareCredential = $VMwareCredential
        $global:SFCredential = $SFCredential
        $global:FailoverFromSite = $FailoverFromSite

        Write-Host "        Config: overview" -ForegroundColor Yellow
        Show-DrTable $config.resources.VC
        Show-DrTable $config.resources.Datacenter
        Show-DrTable $config.resources.MVIP
        Show-DrTable $config.resources.datastore
        pause

        ##############################################################################################################

#   Connect to Source VMware vSphere vCenter on the Source Site.
    Connect-DrVC -cluster $config.resources.VC.$FailoverFromSite -VMwareCredential $VMwareCredential
    
#   get All Datastore Information on Selected Cluster
    $DatastoreMountInfo = Get-DatastoreMountInfo -vserver $config.resources.VC.$FailoverFromSite -Cluster $config.resources.cluster.$FailoverFromSite -vendor "Solidfir"

#   Test Direction of faildover before running $DatastoreMountInfo | select-object Datastore  -uniq
    if ( $null -ne $DatastoreMountInfo) { $null } else { break }

#   Testing the Datastores in the Config file are connected to the Active Site, if the amount is not eq or it is not active will try to swap direction, yet we can have one datastore active.
#   and one datasore as a replication destenation and this test is not conclusive, if if test come back null it will swap the direction, but if the result is not eq it will count on Get-DrScsiNAADeviceID to detect the not source device
    $dsReplicatedtest = Get-DrActiveDatastore -DatastoreMountInfo $DatastoreMountInfo -Datastores $config.resources.datastore.$FailoverFromSite
    $dsReplicatedtest = $dsReplicatedtest | Select-Object Datastore,NAA
#   Connect to HCI SolidFire Cluster on Site A and remove the Access Group for Complite cut off
    $SFFailoverFromSite = (Connect-SFCluster -Target $config.resources.MVIP.$FailoverFromSite -Credential $SFCredential)

#   Save Solidfire Device ID Device ID
    $global:DrScsiNAADeviceID = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.$FailoverFromSite -SFConnection $SFFailoverFromSite

#   Testing if one of the the datastores are not Source mark as Source ( Active on the site ), if so will stope the progrem,
    $err=0;foreach ($ds in $DrScsiNAADeviceID) { if ($ds.direction -ne 'Source') {
         Write-Error "        $($ds.SFVolume) is not Source, please fix the Config file you have a mix configuration of Source and Destination on the same site";$err++;pause} }
    if ($err -ge 1){Write-Error "        about to close the progrem fix config and restart.";pause;break}

#   Compering VMware Connected Datastores NAA to the Solidfire Volume with the Same NAA to match them for consistency test NAADeviceID
    $global:ReplicatedSFVolume = Test-NAAeqDirection -DrScsiNAADeviceID $DrScsiNAADeviceID -DatastoreMountInfo $dsReplicatedtest
    pause

#   Cross refarance HCI SFvolume pair with VMware Datasore
    if ($ReplicatedSFVolume.count -eq $DrScsiNAADeviceID.count) {
        write-host "        Failover from Active Site: $FailoverFromSite To passive Site: $Destination Verfied !" -ForegroundColor Blue  
    } else {
#   will try to swap direction if 1o1 or a per of 2,2 3,3 etc are not in the same place but if it not even it will be brate before entering this list 
    $compare = $false
#   Swapping the site
    Write-Host "        swaping to  Correct Active Site: $FailoverFromSite > passive Site: $Destination !" -ForegroundColor Yellow

#   Connect to Source VMware vSphere vCenter on the Source Site.
    Connect-DrVC -cluster $config.resources.VC.$FailoverFromSite -VMwareCredential $VMwareCredential

#   get All Datastore Information on Selected Cluster
    $DatastoreMountInfo = Get-DatastoreMountInfo -vserver $config.resources.VC.$FailoverFromSite -Cluster $config.resources.cluster.$FailoverFromSite -vendor "Solidfir"

#   Test Direction of faildover before running $DatastoreMountInfo | select-object Datastore  -uniq
    if ( $null -ne $DatastoreMountInfo) { $null } else { break }

#   doing a second test for the swap site. | Testing the Datastores in the Config file are connected to the Active 
    Get-DrActiveDatastore -DatastoreMountInfo $DatastoreMountInfo -Datastores $config.resources.datastore.$FailoverFromSite
    Pause

#   Connect to HCI SolidFire Cluster on Site A 
    $SFFailoverFromSite = (Connect-SFCluster -Target $config.resources.MVIP.$FailoverFromSite -Credential $SFCredential)

#   Save Solidfire Device ID Device ID
    $global:DrScsiNAADeviceID = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.$FailoverFromSite -SFConnection $SFFailoverFromSite

#   Test that we are running on the Sorce
    Test-NAAeqDirection -DrScsiNAADeviceID $DrScsiNAADeviceID -DatastoreMountInfo $DatastoreMountInfo
    pause
} 
# End of verfication 

#   Mount datastore on all VMhost in case of an not fully connected
    foreach ($Device in $ReplicatedSFVolume) {
        if ( $Device.Mounted -eq $false) {
            get-datastore $Device.Datastore | Invoke-AttachDatastore
            get-datastore $Device.Datastore | Mount-Datastore
            pause
        }
    }

#   teset for that Mounted Datastore and Replicated datastore are match
    $ReplicatedSFVolume = $ReplicatedSFVolume | Select-Object Datastore,NAA
    if (!(compare-Object $dsReplicatedtest.NAA $ReplicatedSFVolume.NAA)) {
        write-host "        All direction tested and Verfied, Ready for Failover !" -ForegroundColor Green
        Show-DrTable ($DrScsiNAADeviceID | Select-Object SFVolume,direction)
        $compare = $null 
        pause
    } else { $compare = 'bad' }

#   Starting DR you may want to pause here
    pause
if ($null -eq $compare) 
{       
            $Source = $FailoverFromSite
            # $Destination = 'Destination'
        #   SolidFire Connection
            $SFSource = (Connect-SFCluster -Target $config.resources.MVIP.$Source  -Credential $SFCredential)
            $SFDestination = (Connect-SFCluster -Target $config.resources.MVIP.$Destination -Credential $SFCredential)

        #   Connect to HCI SolidFire Cluster on Site $Destination and remove the Access Group for Complite cut off
            try { Connect-SFCluster -Target $config.resources.MVIP.$Source  -Credential $SFCredential | out-null
            } catch { write-host "        Cant Connect $($config.resources.MVIP.$Source)" -ForegroundColor Red -BackgroundColor Black  }
            try { Connect-SFCluster -Target $config.resources.MVIP.$Destination  -Credential $SFCredential | out-null
            } catch { write-host "        Cant Connect $($config.resources.MVIP.$Destination)" -ForegroundColor Red -BackgroundColor Black  }
            if ($SFSource) {Write-host "        Connection test is OK:" -f Green -NoNewline ; Disconnect-SFCluster -Target $config.resources.MVIP.$Source}
            if ($SFDestination) {Write-host "        Connection test is OK:" -f Green -NoNewline ; Disconnect-SFCluster -Target $config.resources.MVIP.$Destination}

        #   Get-SFVolumePair Status before starting any Task
            Get-DrSFVolumePair -Datastore $config.resources.Datastore.$Destination -ifFailedbreak $true -SFConnection $SFDestination
            pause

        #   Connect to Source VMware vSphere vCenter on the Source Site.
            Connect-DrVC -cluster $config.resources.VC.$Source -VMwareCredential $VMwareCredential

        #   Export Source Datacenter VM Folder Structure
            write-host "        Export VM folder"-NoNewline -f DarkGreen
            Export-VMFolderStructure -Datacenter $($config.resources.Datacenter.$Source) -Path .\$($config.resources.Datacenter.$Source).csv

        #   List VMs that wil Move over to Site B from Site A via DataStore Pir
            FilterVMinDS -Datastore $config.resources.Datastore -Failover Failover -siteDirection $FailoverFromSite
            pause

        #   Create Snapshot before Stoping and Unregistering the VM
            New-DrSFsnapshot -datastores $config.resources.Datastore.$Source -SFCredential $SFSource -Snapshotname "Before_Unregister_and_Stop_VM" 

        #   Stop and unregister VMs on Site A for the Move of the curent VMs //TODO HERE
            Remove-DrVM -VMlist $VMlist -VC $config.resources.VC.$Source -timeout 30

        #   Set Destination VMDatastore in MaintenanceMode
            Set-DrDSMaintenanceMode -datastore $config.resources.Datastore.$Source -timeout 5
            pause

        #   Create Snapshot before disconecting the VMFS
            New-DrSFsnapshot -datastores $config.resources.Datastore.$Source -SFCredential $SFSource -Snapshotname "Failover" 

        #   Get SFvolume Pair Replication Status on $SFDestination
            Get-DrSFreplicationStatus -Datastore $config.resources.Datastore.$Destination -SnapshotName 'Failover' -timeout 5 -SFCredential $SFDestination

        #   Configure Volume Access to ReadOnly so the Current Active datastore will be protected during the VMware Removal 
        # //TODO: need to find a way to delete the datastore without removing the VMFS lable 
        #    Set-DrHciVolAccess -SFCredential $SFSource -SolidFireVolume $config.resources.Datastore.$Source -Access "readWrite"

        #   !!! unmount and Remove DR Datastore form Source VC !!!
            Invoke-CleanVMwareDatastore -VC $config.resources.vc.$Source -Datastore $config.resources.Datastore.$Source -delete $true

        #   Remove SolidFire Netapp HCI Access Group from the AccessGroup | and rescan the VMware Cluster
            Remove-DrHciVolAccessGroup -SFCredential $SFSource -AccessGroup $config.resources.AccessGroup.$Source -SolidFireVolume $config.resources.Datastore.$Source -cluster $config.resources.Cluster.$Source -timeout 10
        
        #   Save Device ID
            $global:DrScsiNAADeviceID = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.$Destination -SFConnection $SFDestination

        #   Mark HCI volume RW
            Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.$Destination -Access $config.readWrite.Access -SFCredential $SFDestination
            pause

        #   Restore SFvolume to Failover snapshots 
            Invoke-DrSFRollbackToSnapshot -SFvolumes $config.resources.Datastore.$Destination -SFCredential $SFDestination -snapshot "Failover" -logpiriod 1
            
        #   Map HCI volume to Cluster
            Set-DrHciVolAccessGroup -SolidFireVolume $config.resources.Datastore.$Destination -AccessGroup $config.resources.AccessGroup.$Destination -SFCredential $SFDestination

        #   Connect to Destination VMware vSphere vCenter on the Source Site.
            Disconnect-DrVC -DisconnectVC  $config.resources.VC.$Source -ReconectVC $config.resources.vc.$Destination -VMwareCredential $VMwareCredential -reconect $true

        #   Import Source Datacenter VM Folder Structure
            Import-VMFolderStructure -Datacenter $($config.resources.Datacenter.$Destination) -Path .\$($config.resources.Datacenter.$Source).csv

        #   Rescan and Connect to the Relication Datastore on the Destination VMware Cluster //TODO fix this to resg
            Write-Host "       make sure Solid fire HCI was replicated and snapshot was restore." -NoNewline -ForegroundColor Yellow
            pause
            Connect-DrReplDatastore -Cluster $config.resources.Cluster.$Destination -datastore $config.resources.Datastore -NAA $DrScsiNAADeviceID -timeout 35 -Destination $Destination -source $source

        #   Map VMfolders
            $Global:folder_collection = invoke-DrVMfolderMapping -Datacenter $config.resources.datacenter.$Destination

        #   Register VM can failed some time due to missing Datastore on some host rescan before can proceed TODO if powershell drop re run $global:VMlist = Get-Content .\VMlist.json | ConvertFrom-Json
            Register-DrVM -VMlist $VMlist -Datastore $config.resources.Datastore.$Destination -cluster $config.resources.Cluster.$Destination `
            -safetyoff $true -reregister $false -VC $config.resources.vc.$Destination -folder_collection $folder_collection
            Start-Sleep -seconds 3
        
        # if failed then ReReregister VM in the Source SourceVC        
        # Invoke-DrRegisterVM -VMlist $VMlist -folder_collection $folder_collection -Cluster $config.resources.Cluster.$Destination -VC $config.resources.vc.$Destination -Datastore $config.resources.Datastore.$Destination  -timeout 6

        #   Fix Network Adapter
            Set-DrVMNetwork -VMs $VMlist -VC $config.resources.vc.$Destination -DatastoreName $config.resources.Datastore.$Destination -test $False
            Start-Sleep -seconds 3
     
        #   Start VMs
            Start-DrVm -DatastoreName $config.resources.Datastore.$Destination -WaitForReplications $false -Timeout 5 -VMlist $VMlist
        
        # //TODO need to add verification of data validiation etc such as Datastore,VMs,Validiation of Application
        #   Remove SFSnapshot of last failover Destination // TODO fix connection base on global connection to SF
            Write-Host "       Please Make sure the VMs are up and Applications are ok before Deliting the Snapshots of Failover and Migration" -NoNewline -ForegroundColor Yellow
            pause
            Remove-DrSFsnapshot -SFCredential $SFDestination -datastores $config.resources.Datastore.$Destination -Snapshotname "Failover"
            Remove-DrSFsnapshot -SFCredential $SFDestination -datastores $config.resources.Datastore.$Destination -Snapshotname "Before_Unregister_and_Stop_VM"
            Remove-DrSFsnapshot -SFCredential $SFSource -datastores $config.resources.Datastore.$Source -Snapshotname "Failover"
            Remove-DrSFsnapshot -SFCredential $SFSource -datastores $config.resources.Datastore.$Source -Snapshotname "Before_Unregister_and_Stop_VM"

        # here //TODO Create a function for removing the SFVolumePairing
        #   Remove Volume Pair to make so a new Volume Pair can be created
        foreach ($volume in ($config.resources.Datastore ) ) {
            #Start-SFVolumePairing
            $SFVolumeSource = ($volume).$Source 
            $SFVolumeDestination =  ($volume).$Destination

            $SFVolumeSource = ( Get-SFVolume -name $SFVolumeSource -SFConnection $SFSource)
            $SFVolumeDestination = ( Get-SFVolume -name $SFVolumeDestination -SFConnection $SFDestination)

            $SFVolumeSource | Remove-SFVolumePair -Confirm:$False -SFConnection $SFSource
            $SFVolumeDestination  | Remove-SFVolumePair -Confirm:$False -SFConnection $SFDestination
        } # // 

        #   Mark HCI volume replicationTarget
            Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.$Source -Access $config.replicationTarget.Access -SFCredential $SFSource

        #   Recreate Volume pair from Source to Dest
        Write-Host "       Please Make sure the HCI and the enviroment are Ready to Recreate Volume pair from Source to Dest" -NoNewline -ForegroundColor Yellow
        pause
        foreach ($volume in ($config.resources.Datastore ) ) {
            #Start-SFVolumePairing
            $SwapSourceSFVolume = ($volume).$Destination 
            $SwapDestinationSFVolume = ($volume).$Source 
            $SwapSFSource = $SFDestination
            $SFSourceDestination =  $SFSource
            $SwapSourceSFVolume = ( Get-SFVolume -name $SwapSourceSFVolume  -SFConnection  $SwapSFSource)
            $SwapDestinationSFVolume = ( Get-SFVolume -name $SwapDestinationSFVolume -SFConnection $SFSourceDestination )
            Start-SFVolumePairing -VolumeID $SwapSourceSFVolume.VolumeID -Mode Async -SFConnection  $SwapSFSource | `
            Complete-SFVolumePairing -VolumeID  $SwapDestinationSFVolume.VolumeID  -SFConnection  $SFSourceDestination
        }
        # // TODO need to test of SFVolumePairing verification.
} else { 
    Write-host "        Cant Failover !" -ForegroundColor Red
    break 
}
exit