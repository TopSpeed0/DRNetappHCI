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

        # $SFSource = (Connect-SFCluster -Target $config.resources.MVIP.$Source  -Credential $SFCredential)
        $SFDestination = (Connect-SFCluster -Target $config.resources.MVIP.Destination -Credential $SFCredential)
        #$SFSource = (Connect-SFCluster -Target $config.resources.MVIP.Source -Credential $SFCredential)

        ##############################################################################################################

        #   Get-SFVolumePair Status before starting any Task
            Get-DrSFVolumePair -Datastore $config.resources.Datastore.Destination -ifFailedbreak $true -SFConnection $SFDestination 
            #Get-DrSFVolumePair -Datastore $config.resources.Datastore.Source -ifFailedbreak $true -SFConnection $SFSource

        #   Connect to Source VMware vSphere vCenter on the Source Site.
            # Connect-DrVC -cluster $config.resources.VC.Source -VMwareCredential $VMwareCredential
            Disconnect-DrVC -DisconnectVC $config.resources.VC.Destination -ReconectVC $config.resources.VC.Source -VMwareCredential $VMwareCredential -reconect $true

        #   Export  Source Datacenter VM Folder Structure
            Export-VMFolderStructure -Datacenter $($config.resources.Datacenter.Source) -Path .\$($config.resources.Datacenter.Source).csv

        #   Select VMs that wil Move over to Site B from Site A via DataStore Pir
            FilterVMinDS -Datastore $config.resources.Datastore -Failover TestFailover -siteDirection "Source" -DestinationDatacenter $($config.resources.Datacenter.Destination) -SourceDatacenter $($config.resources.Datacenter.Source)

        #   Stop and unregister VMs on Site A for the Move of the curent VMs
            $global:RemoveVMsresult = Get-YesNo -MessageboxTitle "Stop and unregister VMs" -Messageboxbody "are you sure you wish to Stop and Unregister this VMs ?"
            if ($RemoveVMsresult -eq 'Yes') { Remove-DrVM -VMlist $VMlist -VC $config.resources.VC.Source -timeout 5 ; Start-Sleep -seconds 10} 

        #   Mark HCI volume RW
            Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.Destination -Access $config.readWrite.Access -SFCredential $SFDestination 

        #   Map HCI volume to Cluster
            Set-DrHciVolAccessGroup -SolidFireVolume $config.resources.Datastore.Destination -AccessGroup $config.resources.AccessGroup.Destination -SFCredential $SFDestination 

        #   Save Device ID
            $global:DrScsiNAADeviceID = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.Destination -SFConnection $SFDestination 

        #   Disconect and Reconect to Destination $config.resources.vc.Destination
            Disconnect-DrVC -DisconnectVC  $config.resources.VC.Source -ReconectVC $config.resources.vc.Destination -VMwareCredential $VMwareCredential -reconect $true
        
        #   Import Source Datacenter VM Folder Structure
            Import-VMFolderStructure -Datacenter $($config.resources.Datacenter.Destination) -Path .\$($config.resources.Datacenter.Source).csv

        #   Rescan and Connect to the Relication Datastore on the Destination VMware Cluster
            Connect-DrReplDatastore -Cluster $config.resources.Cluster.Destination -datastore $config.resources.Datastore `
            -Destination Destination -source source -NAA $DrScsiNAADeviceID -timeout 5

        #   Map VMfolders
            $Global:folder_collection = invoke-DrVMfolderMapping -Datacenter $config.resources.datacenter.Destination

        #   Register VM can failed some time due to missing Datastore on some host rescan before can proceed TODO
            Register-DrVM -VMlist $VMlist -Datastore $config.resources.Datastore -cluster $config.resources.Cluster.Destination `
            -safetyoff $true -reregister $false -VC $config.resources.vc.Destination -folder_collection $folder_collection
            Start-Sleep -seconds 10

        #   Fix Network Adapter
            Set-DrVMNetwork -VMs $VMlist -VC $config.resources.vc.Destination -DatastoreName $config.resources.Datastore.Destination -test $true
            Start-Sleep -seconds 10
             
        #   Start VMs
            Start-DrVm -DatastoreName $config.resources.Datastore.Destination -WaitForReplications $false
        
        #   Verfiying that the move has finished 
            Invoke-Verification $VMlist
    #pause
# return $VMlist
Menu