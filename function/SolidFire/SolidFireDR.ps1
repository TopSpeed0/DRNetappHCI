# # Connect to a solidfire Netapp ( HCI ) Cluster
# function Connect-DrHCI {
#     param (
#         $Target,
#         $SFCredential
#     )
#     try { 
#         $com = Connect-SFCluster -Target $Destination_MVIP -Credential $SFCredential
#     }
#     catch { write-host "        Cant Connect $Target" -ForegroundColor Red -BackgroundColor Black }
#     if (!($null -eq $com )) {
#         Write-Host "you are Connected to:$((Get-SFClusterInfo).name) " -ForegroundColor Green
#     }
# }
# ####################################################################################################################################


# get the volume Pair configuration #
function Get-DrSFVolumePair {
    param (
        $Datastore,
        $ifFailedbreak,
        $SFConnection
    ) foreach ($Datastore in $Datastore) { 
        $SFVolumePair = Get-SFVolumePair -SFConnection $SFConnection | Where-Object { $_.name -match $Datastore }
        if ( ($SFVolumePair.Status -eq "active" ) -and ( $SFVolumePair.Access -eq "replicationTarget") ) { 
            Write-host "        $($SFVolumePair.name) Status:$($SFVolumePair.Status) and 'replication Access' Set to:$($SFVolumePair.Access) we are good to go !" -f Green
        }
        else {
            Write-host "        $($SFVolumePair.name) Status:$($SFVolumePair.Status) and 'replication Access' Set to:$($SFVolumePair.Access) Volume Pair need to be active/replicationTarget" -f Red
            #pause
            if ($ifFailedbreak -eq $true ) { break }
        }
    }
}
####################################################################################################################################


# remove access group from a volume  ( remove a set of host that are maped to an IQN initiators Groups called Access Group )
function Remove-DrHciVolAccessGroup {
    param (
        $SolidFireVolume,
        $AccessGroup,
        $SFCredential,
        $cluster,
        $timeout
    )
    try {
        $SFVolumeAccessGroup = Get-SFVolumeAccessGroup -Name $AccessGroup -SFConnection $SFCredential 
    }
    catch {
        $msgError = $_.Exception.Message
        Write-Host "        SFVolumeAccessGroup: $SFVolumeAccessGroup is: $msgError " -ForegroundColor Red
    }
    # Try
    try {
        $SFVolumeID = Get-SFVolume -Name $SolidFireVolume  -SFConnection $SFCredential 
    }
    catch {
        $msgError = $_.Exception.Message
        Write-Host "SFVolumeID: $SFVolumeID is: $msgError " -ForegroundColor Red
    }
    
    # Try to remove the maped from Access Group 
    try {
        Remove-SFVolumeFromVolumeAccessGroup -VolumeAccessGroupID $SFVolumeAccessGroup.VolumeAccessGroupID -VolumeID $SFVolumeID.VolumeID  -SFConnection $SFCredential  -Confirm:$false -ErrorAction Stop | out-null
    }
    catch {
        $SFVolumeFromVolumeAccessGroupFailed = 'Failed'
    }
    finally {
        if ($SFVolumeFromVolumeAccessGroupFailed -ne 'Failed') {
            Write-host "        SolidFire: $SolidFireVolume (HCI) Volume removed from AccessGroup: $AccessGroup MVIP:$Target " -f Yellow
            if ($null -ne $cluster)
            {Set-DrRescanHBA -cluster $cluster -timeout $timeout}  
        }
        if ($SFVolumeFromVolumeAccessGroupFailed -eq 'Failed') {
            Write-Host "        Failed or allready removed VolumeAccessGroupID $($SFVolumeAccessGroup.VolumeAccessGroupID) VolumeID $($SFVolumeID.VolumeID) from AccessGroup: $AccessGroup" -ForegroundColor Red
        }
    }
}
####################################################################################################################################


# configure the Replicated Volume Pair as a Relication Target ( volume will be relicated and will not be accessible to any host)
function Set-DrHciVolAccess {    
    param (
        $SolidFireVolume,
        $SFCredential,
        $Access
    )
    foreach ($volume in $SolidFireVolume) {
        try {
            Get-SFVolume -name $volume -SFConnection $SFCredential | Set-SFVolume -Access $Access -Confirm:$false -SFConnection $SFCredential | out-null
        }
        catch {
            $msgError = $_.Exception.Message
            Write-Host "SolidFireVolume: $volume  is: $msgError " -ForegroundColor Red
            break
        } finally {
            if ( $null -eq $msgError) {
                Write-host "        SolidFire: $volume (HCI) Volume Access Set to: $Access on:$($SFConnection.name) " -f Yellow
                
            } else {
                Write-Host "        Failed to Set SFVolume:$volume as Access:$Access " -ForegroundColor Red
            }
        }
    }
}
####################################################################################################################################


# set access to  a volume  ( maped the Volume  to an IQN initiators Groups called Access Group )
function Set-DrHciVolAccessGroup { 
    param (
        $SolidFireVolume,
        $AccessGroup,
        $SFCredential
    )
    $SFVolumeToVolumeAccessGroup = $null
    $SFVolumeAccessGroup = Get-SFVolumeAccessGroup -Name $AccessGroup -SFConnection $SFCredential
    foreach ($volume in $SolidFireVolume) { 
        try {
            Get-SFVolume -Name $Volume -SFConnection $SFCredential | Add-SFVolumeToVolumeAccessGroup -VolumeAccessGroupID $SFVolumeAccessGroup.VolumeAccessGroupID -SFConnection $SFCredential -ErrorAction Stop
        }
        catch {
            $SFVolumeToVolumeAccessGroup = $_.Exception.Message
        }
        finally {
            if (!( $null -eq $SFVolumeToVolumeAccessGroup )) {
                Write-Host "        Failed to Add SFVolume:$Volume to AccessGroup: $AccessGroup with Message:$SFVolumeToVolumeAccessGroup  " -ForegroundColor Red
            } else {
                Write-host "        SolidFire: $Volume (HCI) Volume Set to be mounted to AccessGroup: $AccessGroup on:$($SFConnection.name) " -f Yellow
            }
        }
    }
}
####################################################################################################################################
function Get-DrScsiNAADeviceID {
    param (
        $Datastore,
        $SFConnection
    )
    $DrScsiNAADeviceID = @()
    foreach ( $volume in $Datastore )
    {   
        $SFVolumePair = Get-SFVolumePair -SFConnection $SFConnection | Where-Object { $_.name -match $volume }
        if ( ($SFVolumePair.Status -eq "active" ) -and ( $SFVolumePair.Access -eq "replicationTarget") ) { 
            Write-host "        $($SFVolumePair.name) Status:$($SFVolumePair.Status) and replication Access:$($SFVolumePair.Access) | This Site is the Destination Replication Site" -ForegroundColor Blue    
            # Destination
            $direction = "Destination"
        }
        if ( ($SFVolumePair.Status -eq "active" ) -and ( $SFVolumePair.Access -eq "readWrite") ) { 
            Write-host "        $($SFVolumePair.name) Status:$($SFVolumePair.Status) and replication Access:$($SFVolumePair.Access) | This Site is the Source Replication Site" -ForegroundColor green
            # Source
            $direction = "Source"
        }
        $DrScsiNAADeviceID += New-Object psobject -property @{
        "SFVolume" = $volume
        "NAA" = (Get-SFVolume -Name $volume -SFConnection $SFConnection).ScsiNAADeviceID
        "Status" = $SFVolumePair.Status
        "Access" = $SFVolumePair.Access
        "direction" = $direction
        }
    }
    $DrScsiNAADeviceID
}
####################################################################################################################################
function Get-DrSFreplicationStatus {
    param (
        # $config.resources.Datastore
        $Datastore,
        $SFCredential,
        $SnapshotName,
        $timeout
    )
    foreach ($volume in $Datastore) {
        $SFVolumeDestination = $volume
        do {
            # get the Volume pair from the curent Destination !
            $SFVolumePairStatus = ( Get-SFVolumePair -SFConnection $SFCredential | Where-Object {$_.name -eq $SFVolumeDestination})
            $SFVolumeSnapshot = Get-SFSnapshot -SFConnection $SFCredential -SnapshotName $SnapshotName -Target $SFVolumeDestination | Where-Object {$_.VolumeName -eq  $SFVolumeDestination }
            Write-host "        Waiting for Snapshot to replicate on:$SFVolumeDestination or Cluster: $($SFCredential.name)" -ForegroundColor DarkYellow
            Start-Sleep -seconds $timeout
        } until ($SFVolumeSnapshot )
        if ( $SFVolumePairStatus.Status -ne 'active' ) {
            Write-Progress -Activity "Replicate Pair" -Status "Replicate Pair" -CurrentOperation $SFVolumePairStatus.Status # //TODO
        }
    }
}
# Get-DrSFreplicationStatus -Datastore $config.resources.Datastore.$Destination -SnapshotName 'Failover' -timeout 5 -SFDestination $SFDestination

####################################################################################################################################
function New-DrSFsnapshot {
    param (
        $datastores,
        $SFCredential,
        $Snapshotname
    )
    foreach ($volume in $datastores ) {
        $SFVolumeSource = $volume 
        # Create Snapshot
        $SFVolumeSource = ( Get-SFVolume -name $SFVolumeSource -SFConnection $SFCredential)
        $SFVolumeSource | New-SFSnapshot -Name $Snapshotname -EnableRemoteReplication -SFConnection $SFCredential | Out-Null
        Start-Sleep 1
        $newsnap = get-SFSnapshot -SnapshotName $Snapshotname -Target $SFVolumeSource -SFConnection $SFCredential
        Show-DrTable ($newsnap | Select-Object Name,VolumeName)
    }
}
####################################################################################################################################
function Remove-DrSFsnapshot {
    param (
        $datastores,
        $SFCredential,
        [string]$Snapshotname
    )
    foreach ($SFVolumeSource in $datastores ) {
        # get SFVolumeSource and Snapshot
        $SFVolumeSource = $SFVolumeSource | Get-SFVolume -SFConnection $SFCredential 
        $SFSnapshot = get-SFSnapshot -SFConnection $SFCredential | ? { $_.name -eq $Snapshotname }
        
        # if snapshot found start loolp
        if ($SFSnapshot) {
            try {
                # Try to remove the Snapshot from the provided SFVolumeSource
                $SFSnapshot | Remove-SFSnapshot -SFConnection $SFCredential -ErrorAction Stop | Out-Null
            } catch {
                # Error handling in case of a general Failure
                $SnapshotDeleteError = $_.Exception.Message
                Write-host "        DeleteSnapshot on Snapshot volume:$($snap.VolumeName) Failed:  " -ForegroundColor DarkYellow
            }

            # Test DeleteSnapshot API Call for discovering if the SolidFire was able to delete the last snapshot
            if (!($SnapshotDeleteError)) {
                # Setting date tile parameters
                $nd = (get-date).AddMinutes(-$logpiriod)
                $nd = (get-date $nd -Format 'dd/MM/yyyy hh:mm')
                Start-Sleep -seconds 1
                
                # Gathering Snapshot Event from API
                $SFevent = Get-SFEvent -SFConnection $SFCredential
                $SFevent = ($SFevent | ? { $_.Message -match 'DeleteSnapshot' })
                
                # Going throw each Event and pass it to Object and detecting $_.Details.success to $true.
                foreach ($l in $SFevent ) {
                    $DST = ((Get-CimInstance Win32_TimeZone).StandardHour)
                    $date = $($l.TimeOfReport.split('T')[0])
                    $time = $($l.TimeOfReport.split('T')[1].split('.')[0])
                    $ln = (get-date "$date $time").AddHours(+$DST)
                    $ln = get-date $ln -Format 'dd/MM/yyyy hh:mm'
                    
                    if ((get-date $ln) -ge (get-date $nd)) {
                        # examining on curent log for success True.
                        if ($l.Details.success -eq 'True') {
                            $MSG =  "        DeleteSnapshot on Snapshot volume:$($snap.VolumeName)" +
                            "success: $($l.Details.success)"
                            Write-host $MSG -ForegroundColor DarkYellow
                        }
                        if ($l.Details.success -ne 'True') { 
                            $MSG = "        DeleteSnapshot on Snapshot volume:$SFVolumeSource Failed to " +
                            "success: $($l.Details.success)"
                            Write-host $MSG -ForegroundColor Red
                            break
                        }
                    }
                }
            }
        } else {
            Write-host "        no Snapshot name $Snapshotname Found on volume:$SFVolumeSource" -ForegroundColor Red
        }
    }
}
# Remove-DrSFsnapshot -datastores $config.resources.Datastore.$Destination -SFCredential $SFDestination -Snapshotname 'Failover'

####################################################################################################################################

function Invoke-DrSFRollbackToSnapshot {
    param (
        # $config.resources.Datastore.$Destination
        $SFvolumes,
        $SFCredential,
        $snapshot,
        $logpiriod
    )

    $SFSnapVolumes = $SFvolumes | Get-SFVolume -SFConnection $SFCredential 
    $SFSnapshots = $SFSnapVolumes | get-SFSnapshot -SFConnection $SFCredential | ? { $_.name -eq $snapshot }
    foreach ( $Snap in $SFSnapshots ) { 
        $Snap | Invoke-SFRollbackToSnapshot -SaveCurrentState:$false -Confirm:$false -SFConnection $SFCredential
        # taking the current min of the task
        $nd = (get-date).AddMinutes(-$logpiriod)
        $nd = (get-date $nd -Format 'dd/MM/yyyy hh:mm')
        
        $SFevent = Get-SFEvent -SFConnection $SFCredential
        $SFevent = ($SFevent | ? { $_.Message -match 'RollbackToSnapshot' })
        sleep 1
        foreach ($l in $SFevent ){
            $DST = ((Get-CimInstance Win32_TimeZone).StandardHour)
            $date = $($l.TimeOfReport.split('T')[0])
            $time = $($l.TimeOfReport.split('T')[1].split('.')[0])
            $ln = (get-date "$date $time").AddHours(+$DST)
            $ln = get-date $ln -Format 'dd/MM/yyyy hh:mm'

            if ((get-date $ln) -ge (get-date $nd)) {
                # working on curent log
                if ($l.Details.success -eq 'True') {
                    Write-host "        RollbackToSnapshot on Snapshot:$($snap.name) on volume:$($snap.VolumeName) success: $($l.Details.success)" -ForegroundColor DarkYellow
                }
                if ($l.Details.success -ne 'True') { 
                    Write-host "        RollbackToSnapshot on Snapshot: $($Snap) Failed to success: $($l.Details.success)" -ForegroundColor Red
                    break
                }
            }
        }
    }
}