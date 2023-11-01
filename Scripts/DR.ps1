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

        #   Mark HCI volume RW
            Set-DrHciVolAccess -SolidFireVolume $config.resources.Datastore.Destination -Access $config.readWrite.Access -SFCredential $SFDestination 

        #   Map HCI volume to Cluster
            Set-DrHciVolAccessGroup -SolidFireVolume $config.resources.Datastore.Destination -AccessGroup $config.resources.AccessGroup.Destination -SFCredential $SFDestination 

        #   Save Device ID
            $global:DrScsiNAADeviceID = Get-DrScsiNAADeviceID -datastore $config.resources.Datastore.Destination -SFConnection $SFDestination 

        #   Connect to Source VMware vSphere vCenter on the Source Site.
            Disconnect-DrVC -DisconnectVC  $config.resources.VC.Source -ReconectVC $config.resources.vc.Destination -VMwareCredential $VMwareCredential -reconect $true

        #   Rescan and Connect to the Relication Datastore on the Destination VMware Cluster
            Connect-DrReplDatastore -Cluster $config.resources.Cluster.Destination -datastore $config.resources.Datastore `
            -Source source -Destination Destination -NAA $DrScsiNAADeviceID -timeout 35

        #   Map VMfolders
            $Global:folder_collection = invoke-DrVMfolderMapping -Datacenter $config.resources.datacenter.Destination

        #   Register VM can failed some time due to missing Datastore on some host rescan before can proceed TODO
            Register-DrVM -VMlist $VMlist -Datastore $config.resources.Datastore -cluster $config.resources.Cluster.Destination `
            -safetyoff $true -reregister $false -VC $config.resources.vc.Destination
            Start-Sleep -seconds 10

        #   Fix Network Adapter
            Set-DrVMNetwork -VMs $VMlist -VC $config.resources.vc.Destination -DatastoreName $config.resources.Datastore.Destination -test $false
            Start-Sleep -seconds 10
             
        #   Start VMs
            Start-DrVm -DatastoreName $config.resources.Datastore.Destination -WaitForReplications $false 

    #pause
# return $VMlist
Menu