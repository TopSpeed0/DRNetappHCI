# Echo Config for testing
param (
    # import Config json file form Main
    $config,
    $VMwareCredential,
    $SFCredential
)

#       making Sure the Globale Config and Credential Stay obsolete
        $global:config = $config
        $global:VMwareCredential = $VMwareCredential
        $global:SFCredential = $SFCredential

        # Defind Site Direction
        if (!$Activesite) { 
                $Activesite  = (Read-host "        After successfully Failover or TestFailed Over the Active Site is the:Destination Type: Destination " )
            if (!$Activesite){
                $Activesite  = "Destination"
            } 
        }
        if (!$PassiveSite){
            $PassiveSite = (Read-host "        After successfully Failover or TestFailed Over the Passive Site Site is the:source Type: source ")
            if (!$PassiveSite){
                $PassiveSite = "source"
            }
        }
        Write-Host "        Activesite:$Activesite PassiveSite:$PassiveSite Selected !" -ForegroundColor DarkYellow
        
        # Testing Conniction to both site
        try 
        { 
            $SFActivesite = (Connect-SFCluster -Target $config.resources.MVIP.$Activesite -Credential $SFCredential)
        } catch
        {
            $SFconnectionError = $_.Exception.Message
            write-host "        Connection to Solidfire:$($config.resources.MVIP.$Activesite) Failed with an ERROR:$SFconnectionError"
        }
        try 
        { 
            $SFPassiveSite = (Connect-SFCluster -Target $config.resources.MVIP.$PassiveSite -Credential $SFCredential)
        } catch
        {
            $SFconnectionError = $_.Exception.Message
            write-host "        Connection to Solidfire:$($config.resources.MVIP.$PassiveSite) Failed with an ERROR:$SFconnectionError"
        }
        ##############################################################################################################

# Import Last Operation Run
# $last = Read-host -Prompt "        get-last VMlist Y/N"
# if ($last -eq 'Y' ) { try { $VMlist = Get-Content .\VMlist.json | ConvertFrom-Json } catch { $VMlist = $null } }

# Show Cleanup Menu
$defaultscenarioCleanup = "All"
Write-Host "                                                                               "
Write-Host "        Select scenario Type: ALL ( Will VMs/VMFS/HCI ), or press <enter> to accept the default All Cleanup." -ForegroundColor Yellow
Write-Host "        Select scenario Type: HCI ( will Clean only HCI )." -ForegroundColor Yellow
Write-Host "        Select scenario Type: VMFS ( will Clean only VMWare VMFS )." -ForegroundColor Yellow
Write-Host "        Select scenario Type: VMs ( Will Only ReRegister Lost VMs from Source)." -ForegroundColor Yellow
Write-Host "        default is $($defaultscenarioCleanup)" -ForegroundColor Yellow -NoNewline ; Write-Host ":" -NoNewline

# Read host Selection and set default scenario
$scenarioCl = Read-Host
If ($scenarioCl -eq "") {
    $scenarioCl = $defaultscenarioCleanup
}

# Menu switch All,HCI,VMFS,VMs
switch ($scenarioCl) 
{
    'All' 
    {
        # Stop and unregister VMs on Site A for the Move of the curent VMs
        $global:RemoveVMsresult = Get-YesNo -MessageboxTitle "Start and register VMs ?" -Messageboxbody "are you sure you wish to Start reregister VMs ?"

        # Reconect DestinationVC 
        Disconnect-DrVC -DisconnectVC  $config.resources.VC.$PassiveSite -ReconectVC $config.resources.vc.$Activesite  -VMwareCredential $VMwareCredential -reconect $true

        # if $VMlist is lost or null failed run will ask for new VM list 
        if ( $null -eq $VMlist ) 
        { 
            FilterVMinDS -Datastore $config.resources.Datastore -Failover TestFailover -siteDirection $Activesite 
        }
        
        # Unregister VMs from DestinationVC
        Remove-DrVM -VMlist $VMlist -VC $config.resources.VC.$Activesite -timeout 5
   
        # Set Destination VMDatastore in MaintenanceMode
        Set-DrDSMaintenanceMode -datastore $config.resources.Datastore.$Activesite -timeout 5

        # Disconect and Reconect to PassiveSite $config.resources.VC.$PassiveSite
        Disconnect-DrVC -DisconnectVC $config.resources.vc.$Activesite -ReconectVC $config.resources.VC.$PassiveSite -VMwareCredential $VMwareCredential -reconect $true

        #   Get current folder for VM registration on the same location of VMfolders
        $Global:folder_collection = Invoke-DrVMfolderMapping -Datacenter $config.resources.datacenter.$PassiveSite

        # Reconnect the Datastores 
        if ($null -eq $RestoreDatastoreConnections )
        {
            $global:RestoreDatastoreConnections = Get-YesNo -MessageboxTitle "Is Datastore Are missing ?" -Messageboxbody "Do you wish to reconnect the Datastore on the passive VC"
        }

        # If need to reconnect the Datastore on the passive site then do.
        if ($RestoreDatastoreConnections -eq 'Yes') 
        { 
            
            # Configure Volume Access to the Current Passive datastore so they can reconnect to the passive vcenter
            Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.$PassiveSite -Access $config.readWrite.Access -SFCredential $SFPassiveSite

            # Map HCI volume to Cluster
            Set-DrHciVolAccessGroup -SolidFireVolume $config.resources.Datastore.$PassiveSite -AccessGroup $config.resources.AccessGroup.$PassiveSite -SFCredential $SFPassiveSite
        
            # Restore SFvolume to Failover snapshots 
            foreach ( $Snap in ($config.resources.Datastore.$PassiveSite | Get-SFVolume | get-SFSnapshot | ? {$_.name -eq "Failover"}) ) { 
                $Snap | Invoke-SFRollbackToSnapshot -SaveCurrentState:$false -Confirm:$false -SFConnection $SFPassiveSite
            }

            # Get Datastore Mount Info
            $DatastoreMountInfo = Get-DatastoreMountInfo -vserver $config.resources.VC.$PassiveSite -Cluster $config.resources.cluster.$PassiveSite -vendor "Solidfir"

            # foreach Datastore in DatastoreMountInfo ver if there is a device NNA that is not mounted on all host it will attach and Mounted it ( some time after exposing new lun some lun will not be mounted on all VMhosts)
            foreach ($Device in $DatastoreMountInfo) 
            {
                if ( $Device.Mounted -eq $false) 
                {
                    get-datastore $Device.Datastore | Invoke-AttachDatastore
                    get-datastore $Device.Datastore | Mount-Datastore
                    pause
                }
            }
            
            # verfied all Datastores are back in place.
            $DatastoreMountInfo = Get-DatastoreMountInfo -vserver $config.resources.VC.$PassiveSite -Cluster $config.resources.cluster.$PassiveSite -vendor "Solidfir"
            foreach ($Device in $DatastoreMountInfo) 
            {
                if ( $Device.Mounted -eq $false) 
                { 
                    Write-host "        some datastores are not mounted: $($Device.Datastore),($Device.DisplayName)"
                     pause
                }
            }

            # Save Device ID
            $PassiveSiteNAA = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.$PassiveSite -SFConnection $SFPassiveSite
            
            # Rescan and Connect to the Relication Datastore on the Destination VMware Cluster
            Connect-DrReplDatastore -Cluster $config.resources.Cluster.$PassiveSite -datastore $config.resources.Datastore -Destination $PassiveSite -NAA $PassiveSiteNAA -timeout 35 
            
            # ReReregister VM in the Source PassiveSite VC        
            Invoke-DrRegisterVM -VMlist $VMlist -folder_collection $folder_collection -Cluster $config.resources.Cluster.$PassiveSite -VC $config.resources.VC.$PassiveSite -Datastore $config.resources.Datastore.$PassiveSite  -timeout 6 -reregister $false
        
        } else 
        {
            # ReReregister VM in the Source SourceVC 
            Invoke-DrRegisterVM -VMlist $VMlist -folder_collection $folder_collection -Cluster $config.resources.Cluster.$PassiveSite -VC $config.resources.VC.$PassiveSite -Datastore $config.resources.Datastore.$PassiveSite  -timeout 6 -reregister $True
            #pause
        }
        
        # Start VM if VMs was not ask to stop and remove they are up on the source site so no need to start them
        if ($RemoveVMsresult -eq 'Yes') 
        {
            Start-DrVm -DatastoreName $config.resources.Datastore.$PassiveSite -WaitForReplications $false 
        }
        
        # Reconect DestinationVC 
        Disconnect-DrVC -DisconnectVC  $config.resources.VC.$PassiveSite -ReconectVC $config.resources.vc.$Activesite  -VMwareCredential $VMwareCredential -reconect $true

        # unmount and Remove DR Datastore form DestinationVC
        Invoke-CleanVMwareDatastore -VC $config.resources.vc.$Activesite -Datastore $config.resources.Datastore.$Activesite -delete $false 
        
        # Remove SolidFire Netapp HCI Access Group from the AccessGroup
        Remove-DrHciVolAccessGroup -SFCredential $SFActivesite -SolidFireVolume $config.resources.Datastore.$Activesite -AccessGroup $config.resources.AccessGroup.$Activesite

        # Configure Volume Access to the Current Passive datastore so they can reconnect to the passive vcenter
        Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.$Activesite -Access $config.replicationTarget.Access -SFCredential $SFActivesite
        Write-Host "        Finish CleanUP HCI Storage"
        ##pause

        # Remove SFSnapshot of last failover 
        foreach ( $Snap in ($config.resources.Datastore.$Activesite | Get-SFVolume  -SFConnection $SFActivesite | get-SFSnapshot -SFConnection $SFActivesite | ? {$_.name -eq "Failover"}) ) 
        { 
            $Snap | Remove-SFSnapshot -Confirm:$false -SFConnection $SFActivesite
        }
        foreach ( $Snap in ($config.resources.Datastore.$PassiveSite | Get-SFVolume -SFConnection $SFPassiveSite | get-SFSnapshot -SFConnection $SFPassiveSite | ? {$_.name -eq "Failover"}) ) 
        { 
            $Snap | Remove-SFSnapshot -Confirm:$false -SFConnection $SFPassiveSite
        }

        # Finish MSG
        Write-Host "        Finish CleanUP All"
        ##pause
    }
    'HCI' 
    {
        # Remove SolidFire Netapp HCI Access Group from the AccessGroup
          Remove-DrHciVolAccessGroup -SFCredential $SFActivesite -SolidFireVolume $config.resources.Datastore.$Activesite -AccessGroup $config.resources.AccessGroup.$Activesite

        # Configure Volume Access to the Current Passive datastore so they can reconnect to the passive vcenter
          Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.$Activesite -Access $config.replicationTarget.Access -SFCredential $SFActivesite 
        
        # Finish MSG
        Write-Host "        Finish CleanUP HCI Storage"
        ##pause
    }
    'VMFS' 
    { 
        # Reconect DestinationVC Datastore
        Disconnect-DrVC -DisconnectVC  $config.resources.VC.$PassiveSite -ReconectVC $config.resources.vc.$Activesite  -VMwareCredential $VMwareCredential -reconect $true

        # unmount and Remove DR Datastore form DestinationVC
        Invoke-CleanVMwareDatastore -VC $config.resources.vc.$Activesite -Datastore $config.resources.Datastore.$Activesite -delete $false 

        # Finish MSG
        Write-Host "        Finish VMFS"
        ##pause
    }
    'VMs' 
    {
        # Stop and unregister VMs on Site A for the Move of the curent VMs
        $global:RemoveVMsresult = Get-YesNo -MessageboxTitle "Start and register VMs ?" -Messageboxbody "are you sure you wish to Start reregister VMs ?"

        # Disconect and Reconect to Destenation
        Disconnect-DrVC -DisconnectVC $config.resources.vc.$Activesite -ReconectVC $config.resources.VC.$PassiveSite -VMwareCredential $VMwareCredential -reconect $true

        #   Map VMfolders
        $Global:folder_collection = Invoke-DrVMfolderMapping -Datacenter $config.resources.datacenter.$PassiveSite

        # Start VM if VMs was not ask to stop and remove they are up on the source site so no need to start them
        if ($RemoveVMsresult -eq 'Yes') 
        { 
            # ReReregister VM in the Source SourceVC        
            Invoke-DrRegisterVM -VMlist $VMlist -folder_collection $folder_collection -Cluster $config.resources.Cluster.$PassiveSite -VC $config.resources.VC.$PassiveSite -Datastore $config.resources.Datastore.$PassiveSite -timeout 6 -reregister $global:RemoveVMsresult
            
            # Start VM
            Start-DrVm -DatastoreName $config.resources.Datastore.$PassiveSite -WaitForReplications $false 
        }
        # Finish MSG
        Write-Host "        Finish CleanUP VMs"
        ##pause
    }
}
pause
Menu