# test direction of DR base of configuration and vs vmware datastore connection, if the datastore marked as destination is connected then it is the new Source sins the dr is moving the datastore
# to be mounted on the destination sins it allready mounted then the marked location as destination must be the Source
function Get-DrActiveDatastore {
    param (
        $DatastoreMountInfo,
        $Datastores
    )
    $SwapIsTrue = $null
    #   Sorting the datastores uniq datastore
    $tempds = @()
    $DatastoreMountInfoFilterd = $DatastoreMountInfo | select-object Datastore,NAA -uniq
    # $DatastoreMountInfoFilterd
    # $DatastoreMountInfo = $DatastoreMountInfo | select-object Datastore,VMHost,Lun,Mounted,State,NAA,Path,DisplayName -uniq
    
    ## CASE 1 when the Source profided in FailoverFromSite is Valid
    #   testing device on the FailoverFromSite
    if ($Datastores.count -eq 1) {
        $ReplicatedDatastores = ($DatastoreMountInfoFilterd | Where-Object { $_.datastore -eq $Datastores})
    }
    if ($Datastores.count -gt 1) {
        foreach ( $ds in $Datastores) {
            $tempds += ($DatastoreMountInfoFilterd | Where-Object { $_.datastore -eq $ds})
        }
        $ReplicatedDatastores = $tempds
    }
            # Test logic $ReplicatedDatastores = $null
            if ( $ReplicatedDatastores.count -eq 0 ) 
            {
                Write-host "        $Datastores is not Found in this Vcenter on the Datastore lists, this can be a result of the Datastore is not Active or other issues" -ForegroundColor Yellow
                $SwapIsTrue = $true
            } else {
                # When source tested to be valid as a Source, make sure all the Datastore are replicated and not just one or less the count from resources.datastore
                if ( $ReplicatedDatastores.count -eq $Datastores.count ){
                    $Source = $FailoverFromSite
                    $SwapIsTrue = $false
                    # set the destintation base on the curent Source in case of a valid source
                    if ( $Source -eq "Source"){ $Destination="Destination"}
                    if ( $Source -eq "Destination"){ $Destination="Source" }
                } elseif ($ReplicatedDatastores.count -ne $Datastores.count ) {
                    Write-host "        Only $($ReplicatedDatastores.Datastore) is Found in this Vcenter on the Datastore lists, mix configuration detected, next step will detect what DS is active on Storage" -ForegroundColor Red
                }
            }
    ## CASE 2 when the Source profided in FailoverFromSite is faulty and dose not have any of the resources.datastore mounted in this curent Vcenter
    #   testing device on the FailoverFromSite
        #  if the Source is Null that mean the Volume is not mounted in the Vcneter there for swap needed
        if (  $SwapIsTrue -eq $true )
        {
                if ($FailoverFromSite -eq "Source") {
                    # FailoverFromSite is Source in test for the true Source . if Source dsReplicated is empty, no Source Datastore is in this site and we need to swap direction
                    
                    # marking what was swap
                    $Swap = "Destination"
                    # Source will become new Destination and not the Source as we was sure it holding the Active Data
                    $Destination =  "Source"
                    $Source = "Destination"
                }
                if ($FailoverFromSite -eq "Destination") {
                    # FailoverFromSite is Source in test for the true Source . if Source dsReplicated is empty, no Source Datastore is in this site and we need to swap direction
                    
                    # marking what was swap
                    $Swap = "Source" 
                    # Destination will become new Destination and not the Source as we was sure it holding the Active Data
                    $Destination = "Destination"
                    $Source =  "Source"
                }
        }
    # END of cases ###########################################################################################################################################################

    # set the curent HCI stating Test for the next replication test on the real active Data
    if ( $SwapIsTrue -eq  $false ) {
        Write-host "        INFO: No Swap is needed. Correct Direction of Failover. Failover from Active Site:$Source to Passive Site:$Destination" -f Green
        $FailoverFromSite =  $FailoverFromSite
    } 
    if ( $SwapIsTrue -eq  $true ) {
        Write-host "        INFO: Swap is needed Wrong for Direction of Failover, Change Site Direction to Active:$Source to Passive:$Destination" -f Red
        $FailoverFromSite = $Swap
    }
    $global:FailoverFromSite = $FailoverFromSite  
    $global:Destination = $Destination
    $global:SwapIsTrue
    return $ReplicatedDatastores
}

# Compering VMware Connected Datastores NAA to the Solidfire Volume with the Same NAA to match them for consistency test NAADeviceID
function Test-NAAeqDirection {
    param (
        $DrScsiNAADeviceID,
        $DatastoreMountInfo
    )
   $DataStoreCount= 0
   $ReplicatedSFVolume = @()
   foreach  ($device in $DrScsiNAADeviceID) {
       if (( $device.NAA -in $DatastoreMountInfo.NAA) -and ($device.direction -eq "Source") ) {
            $ReplicatedSFVolume += $DatastoreMountInfo | ? {$_.NAA -eq $device.NAA}
            $DataStoreCount++
       }
   } 
   return $ReplicatedSFVolume 
}