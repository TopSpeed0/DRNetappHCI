# get the VMs from the Selected Datastore and Store there Configuration in a Globale Variable of VMlist for later useage 
function FilterVMinDS {
    param (
        $Datastore,
        $DestinationDatacenter,
        $SourceDatacenter,
        $Failover,
        $siteDirection
    )
$DrVMs = @()
$VMlist = @()

foreach ($ds in $Datastore) 
{
    # Get the VMs from the SourceDatastore with volume peer.
    $DrVM = Get-DrVM -Datastore $ds.$siteDirection -VC $global:DefaultVIServers.name
    # $DrVM
    #### **** fix here 07/06/2022    # Get-VDPortgroup -VM $_
    if ($siteDirection -eq "Source") {
        
        $DrVMs += $DrVM | Select-Object Name,ResourcePool,Folder,FolderId,DestFolderId,VApp,PowerState,`
        @{E = { $_.ExtensionData.Config.Files.VmPathName }; L = "VMFilePath" },`
        @{E = { Get-VMFolderPath $_.Folder.Id  }; L = "FullPath" },`
        @{E = { (Get-VMFolderPath $_.Folder.Id).replace("$SourceDatacenter","$DestinationDatacenter")  }; L = "DestinationFullPath" },`
        @{E = { (Get-VMFolderPath $_.Folder.Id).split('/vm')[1] }; L = "ReletivePath" },`
        @{E = { Get-VirtualPortGroup -VM $_ -ErrorAction SilentlyContinue }; L = "PortGroup" },`
        @{E = { $ds.Source }; L = "DataStore" }, @{E = { $ds.Destination }; L = "DestinationDataStore" }
        # @{E = { Get-VirtualPortGroup -VM $_ -ErrorAction SilentlyContinue }; L = "PortGroup" },`
    }
    if ($siteDirection -eq "Destination") {
        $DrVMs += $DrVM | Select-Object Name,ResourcePool,Folder,FolderId,DestFolderId,VApp,PowerState,`
        @{E = { $_.ExtensionData.Config.Files.VmPathName }; L = "VMFilePath" },`
        @{E = { Get-VMFolderPath $_.Folder.Id  }; L = "FullPath" },`
        @{E = { (Get-VMFolderPath $_.Folder.Id).replace("$DestinationDatacenter","$SourceDatacenter")  }; L = "DestinationFullPath" },`
        @{E = { (Get-VMFolderPath $_.Folder.Id).split('/vm')[1] }; L = "ReletivePath" },`
        @{E = { Get-VirtualPortGroup -VM $_ -ErrorAction SilentlyContinue }; L = "PortGroup"},`
        @{E = { $ds.Destination }; L = "DataStore" }, @{E = { $ds.Source }; L = "DestinationDataStore" }
        # @{E = { Get-VirtualPortGroup -VM $_ -ErrorAction SilentlyContinue }; L = "PortGroup"},`
    }

}

if ($Failover -eq "TestFailover") {
    
    # Gui Method
    $selectedVM = show-DrBox -ArryList $DrVMs.name -MessageBOX "Select VMs for DR test" -testBox "Select a VMs:" # 
   
    # grid Method
    # $selectedVM = Get-GridMenu -MessageboxTitle "Select VMs for DR test" -options $DrVMs.name
    foreach ( $vm in $selectedVM) {
        $VMlist +=  $DrVMs | ? { $_.name -match $vm  }  
    }
}
if ($Failover -eq "Failover") {
    $VMlist = $DrVMs
}
$Global:VMlist = $VMlist
$VMlist | ConvertTo-Json -Depth 1 | out-file .\VMlist.json -Force
}
####################################################################################################################################

# Connect the Relicated Pair Volume ( HCI netapp Solidfire volume ) on the Destination VMware vSphere vCenter 
function Connect-DrReplDatastore {
    param (
        $cluster,
        $datastores,
        $NAA,
        $timeout,
        $Destination,
        $source
    )
    $DatastoreList = @()
    $i = 0
    foreach ($ds in $datastores) {
        $DatastoreList += New-Object psobject -property @{
            "cluster" = $cluster
            "datastore" = $ds.$Destination
            "NAA" =  ($NAA | ? { $_.SFVolume -eq $($ds.$Destination)}).NAA
            "SourceDatastore" = $ds.$source
        }
        $i++
    }
    #$DatastoreList

    # Rescan-DrHBA
    Set-DrRescanHBA -cluster $cluster -timeout $timeout

    $cluster = Get-Cluster $Cluster
    $VMHost = $cluster | Get-VMHost | Sort-Object CpuUsageMhz | Select-Object -First 1
    
    #Create a list of unbound scsi devices
    $hostView = get-vmhost -name $VMHost | get-view
    $dsView = get-view $hostView.ConfigManager.DatastoreSystem
    $unBound = $dsView.QueryUnresolvedVmfsVolumes()
    $unBound = $unBound | Sort-Object VmfsLabel

    # register Avilable DR VMFS disks , SourceVolumelable and DestinationVolumelable name must be the same in HCI and VMware
    foreach ($Datastore in $DatastoreList) {
        $DrVMFSStatus = New-DrDatastore -cluster $cluster -DestinationVolumelable $datastore.datastore -SourceVolumelable $Datastore.SourceDatastore -NAA $Datastore.NAA -unBound $unBound -VMHost $VMHost
        if ( $DrVMFSStatus.name -eq $datastore.datastore ) {
            Write-Host "        Status is Ok Datastore was added" -f Green
            if ($null -eq $timeout) { $timeout = 3 }
            Start-Sleep -seconds $timeout
        }
        else {
            Write-host "        Failed to Add Datastore: $($datastore.datastore) Going Back to Menu for CleanUP"
            #pause
            Break
            # Menu
        }

        # test that DataStore is Active 
        $DestinationVMDatastoreStatus = get-datastore -name $datastore.datastore
        if ($null -eq $DestinationVMDatastoreStatus ) {
            Write-host "        Operation Failed go back to CleanUP" -f Red
            #pause
            Break
            # Menu
        }
    }
    #Rescan-DrHBA second time after ds rename
    Set-DrRescanHBA -cluster $cluster
}
####################################################################################################################################
