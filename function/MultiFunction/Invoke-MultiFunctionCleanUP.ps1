# Test Location
# this function will try to Register Virtual Machine if $VMlist is existing if not it will recover them from the location in the Datastore
function Invoke-DrRegisterVM {
    param (
        $VMlist,
        $Cluster,
        $VC,
        $Datastore,
        $reregister,
        $timeout
    )
    $ReRegSourceVMStatus = $null
    $ReRegSourceVMStatus = @()
    
    if ($null -eq $VMlist ) 
    {
        Write-host "        VMlist was not Run, Can't Register VM From option 1 if Option 3 run First " -ForegroundColor Red
        Write-host "        Can Recover VMs from Datastore Y/N: " -ForegroundColor Yellow -NoNewline
        $ReadHostTemp = Read-Host 
        if ($ReadHostTemp -eq "Y") 
        {
            foreach ($DS in $Datastore) 
            {
                # Before Starting this Masive Task
                Write-Host "        Are U ! Sure you wish to go and find any VMX file in the selected Datastore for VM registration !" -f Red
                Pause
                Register-DrVMFilePath -Cluster $Cluster -VC $VC -Datastores $DS -folder_collection $folder_collection
                Start-Sleep -seconds $timeout
                $ReRegSourceVMStatus += Get-DrVM -Datastore $DS -VC $VC
            }
        }
    } else {
        if ($null -eq $reregister ) { $reregister = $true }
        # foreach //TODO fix for failedover need tobe dynamic 
        Register-DrVM -VMlist $VMlist -cluster $Cluster -safetyoff $true -reregister $reregister -VC $VC -folder_collection $folder_collection
        Start-Sleep -seconds $timeout
        $ReRegSourceVMStatus = get-vm $VMlist.name

    }
    # Test final results
    if (!([string]::IsNullOrEmpty($ReRegSourceVMStatus))) {
        Write-host "        Virtual Machines was ReRegister at the source vCenter" -f green
    } else {
        Write-host "        Virtual machines failed to Register, with ERROR: Unable to access the virtual machine configuration: Invalid datastore path" -ForegroundColor Red
        Write-host "        this is a Bug usualy in VMware Run Options 3/VMs to try to reregister the VMs" -ForegroundColor Red
    }
}
####################################################################################################################################

# will do Rescan and disconect and delete the Selected Datastore
function Invoke-CleanVMwareDatastore {
    param (
        $VC,
        $Datastore,
        $delete,
        $timeout
    )
    foreach ($Datastore in $Datastore) {
        $DestinationVMDatastoreTable = get-datastore $Datastore -ErrorAction SilentlyContinue
        if (!([string]::IsNullOrEmpty($DestinationVMDatastoreTable)) ) {
            # commenct on the selected Datastore
            Write-host "        ----------- Selected Datastore ---------------" -f Green
            Set-TableSpace $DestinationVMDatastoreTable

            Set-DrUnmountDatastores -VIServer $VC -DatastoreName $Datastore -ErrorAction SilentlyContinue 
            Start-sleep 5
            Write-host "        Make Sure Datastore in Unmount in all ESXI before moving on" -f Yellow

            if ($delete -eq $true ) {
                try {
                    # Delete VMFS
                    get-datastore $Datastore | Get-VMhost -Server $VC | remove-datastore $Datastore -confirm:$false -ErrorAction SilentlyContinue | Out-Null
                }
                catch {
                    # out to null
                }
            }
            $DestinationVMDatastoreTableStage2 = get-datastore $Datastore -ErrorAction SilentlyContinue

            Start-Sleep -seconds $timeout
            if (([string]::IsNullOrEmpty($DestinationVMDatastoreTableStage2)) )
            {
                Write-host "        Datastore Disconnect and Remove of Datastore: $Datastore has finish" -f Green
            } else {
                Write-host "        Datastore Disconnect and Remove of Datastore: $Datastore stop or failed Remove it manually before continuing !!!. " -f Red
            }
            #
        } else {
            Write-host "        Datastore: $Datastore | not to be found. Disconnect or Delete manually before continuing " -f Red
            #pause
        }
    }
}
####################################################################################################################################
