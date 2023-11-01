# Connect  VMware vSphere vCenter
function Connect-DrVC {
    param (
        $Cluster,
        $VMwareCredential
    )
    try { 
        Connect-VIServer $Cluster -Credential $VMwareCredential | Out-Null # -Verbose 
    }
    catch { write-host "        Cant Connect $Cluster" -ForegroundColor Red -BackgroundColor Black }
}
####################################################################################################################################

function New-DrVM {
    param (
        $VMFilePath,
        $VMHost,
        $VMname,
        $VMfolder,
        $VC
    )
    try {
        # Try to register the VM Clean first time
        New-VM -VMFilePath $VMFilePath -location $VMfolder -VMHost $VMHost -Name $VMname -ErrorAction Stop | out-null
    }
    catch {
        # Error
        $VM_RegisterationStatus = $_.Exception.Message

        # Try to register VM outside Configured Location
        New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname -ErrorAction SilentlyContinue | out-null

        # Test if Vm was Register without location
        $TestVMReg = get-VM $VMname -Server $VC -ErrorAction SilentlyContinue 

        # Test Loop for VM
        if ($TestVMReg.name -eq $VMname) {
            if ($null -ne $VMfolder) { 
                # try to move the VM back to the original location
                Write-host "        please Create Folder:$VMfolder on VC:$VC"
                pause
                Move-VM -VM $VMname -InventoryLocation $VMfolder | out-null
                $VMwarr = $true
            }
        }
        if ([string]::IsNullOrEmpty($TestVMReg)) {
            Write-host "        Failed to Register VM with Message:$($VM_RegisterationStatus)" -ForegroundColor Red
        }            
        elseif (!([string]::IsNullOrEmpty($TestVMReg))) {
            Write-host "        Register New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname Registerd with a Warning outside Configured Folder" -ForegroundColor Yellow
        }
    }
    finally {
        if ( ($VMwarr -ne $true) -and (!([string]::IsNullOrEmpty($TestVMReg))) ) {
            Write-host "        Register New-VM -VMFilePath $VMFilePath -location $VMfolder -VMHost $VMHost -Name $VMname Succseful Registerd" -ForegroundColor Green
        } 
    }
}
##################################################################################################################################################################################

# Connect and Disconnect VMware vSphere vCenter
function Disconnect-DrVC {
    param (
        $DisconnectVC,
        $ReconectVC,
        $VMwareCredential,
        $reconect
    )
    # $DisconnectVC = $config.resources.vc.Destination ; $ReconectVC = $config.resources.VC.Source ; $VMwareCredential = $VMwareCredential ; $reconect = $true
    if ( $global:DefaultVIServers.name -contains $DisconnectVC ) {
        try {
            write-host "        disconnecting from VC" -f Yellow
            Disconnect-VIServer $DisconnectVC -Confirm:$false -ErrorAction SilentlyContinue
            $global:DefaultVIServers | Disconnect-VIServer -Confirm:$false
        }
        catch {
            write-host "        allready Disconected VC" -f Yellow
        }
    }
    if ($reconect -eq $true) {
        connect-DrVC -cluster $ReconectVC -VMwareCredential $VMwareCredential
    }
    Write-Host "        You are connected to: $global:DefaultVIServers.name" -ForegroundColor cyan 
    #pause
}
####################################################################################################################################


# Get VMs simpale way
function Get-DrVM {
    param (
        $Datastore,
        $VC
    )
    try {
        Get-vm -Datastore $Datastore -Server $VC
    }
    catch {
        write-host "        Cant get any VMs" -ForegroundColor Red -BackgroundColor Black 
    }
}
####################################################################################################################################


# Start Virtual Machine and finish VMQuestion 
function Start-DrVm { 
    param (
        $DatastoreName,
        $Timeout,
        $VMlist,
        $WaitForReplications
    )
    # set general timeout
    if ($null -eq $Timeout ) { $Timeout = 10 }

    # test for VMlist first are not empty 
    if ($VMlist) {
        # import vm list from VMlist global ver with the Start VMs preferences 
        $VMlistTostarts = $VMlist | ? { $_.PowerState -eq 'PoweredOn' }
        
        # test for VMlist PoweredOn first are not empty 
        if ($VMlistTostarts) {
            foreach ($Datastore in $DatastoreName) {
                $VMsTemp = $null
                $VMstartError = $null
                # filter VMs per datastore name form the PoweredOn list
                $VMlistTostart = $VMlistTostarts | ? { $_.DestinationDataStore -eq $Datastore }
                # Start VM
                if ($VMlistTostart) {
                    # test get vm PoweredOn from list
                    try {
                        $VMsTemp = $VMlistTostart | % { get-vm -Name $_.name -datastore $Datastore  }
                    }
                    catch {
                        Write-host "        ERROR: Faild to load VMs with an Error: $($_.Exception.Message), Please Start Over and Roll back !" -f Red
                        pause
                        # break
                    }
                }
                else {
                    # all VMs are PoweredOff
                    Write-host "        INFO: all VMs are set to stay PoweredOff" -ForegroundColor Yellow
                }
                if ($WaitForReplications -eq $true) {
                    Start-Sleep $Timeout
                    #call-SFreplication
                }
                if ($VMsTemp) {
                    foreach ($VM in $VMsTemp) {
                        Try {
                            # Write-host
                            $VM | Start-VM -RunAsync -ErrorAction Stop
                            Start-Sleep $Timeout
                        }
                        catch {
                            $VMstartError = $_.Exception.Message
                            Write-Host "        cant Start VM:$($VM.name) Error:$VMstartError"
                        }
                        if ( $null -eq $VMstartError) {
                            $VMQuestion = $null
                            Start-Sleep -seconds $Timeout
                            # #pause
                            $VMQuestion = $VM | Get-VMQuestion
                            if ( $null -eq $VMQuestion ) {
                                Write-host "        Finish or non Question for VM:$($VM.name) " -ForegroundColor Green
                            }
                            else {
                                Try {
                                    $VMQuestion | Set-VMQuestion -DefaultOption -Confirm:$false -ErrorAction Stop
                                }
                                catch {
                                    $VMQuestion = $_.Exception.Message
                                    write-host "        Cant answer qustion for VM:$($VM.name) Question:$VMQuestion"
                                } 
                            } 
                        } 
                    }
                }
            }
        }
        else {
            Write-host "        INFO: ALL VMs set to be PoweredOFF, start VMs manualy if realy needed !" -f Yellow
            pause
        }
    }
    else {
        Write-host "        ERROR: No VMs PoweredOn/PoweredOFF preferences can be extracted without VMlist var, please start VMs manualy !" -f Red
        pause
    }
    # Running on all Datastores in DatastoreName list 
}
####################################################################################################################################

# Add Datastore to VC
function New-DrDatastore {
    param (
        $cluster,
        $DestinationVolumelable,
        $SourceVolumelable,
        $VMHost,
        $unBound,
        $NAA
    )
    if ($null -eq $unBound) {
        write-host "        did not found any UnresolvedVmfsVolumes with matching NAA:$NAA "
        ##pause 
        break
    }
    else {
        foreach ($new in $unBound) {
            if ( $SourceVolumelable -eq $new.VmfsLabel) {
                $extPaths = @()
                $Extents = $new.Extent;
                $extPaths = $extPaths + $Extents.DevicePath
                $curentNAA = ($extPaths.split("naa.")).split(':')[1] 
                if ($null -eq $curentNAA) {   
                    Write-Error -Message "Could not Find $NAA! "
                }
                else {
                    write-host "        Found new Disk with NAA.$curentNAA" -ForegroundColor Blue
                    # #pause
            
                    if ($NAA -match $curentNAA ) {
                        $res = New-Object VMware.Vim.HostUnresolvedVmfsResignatureSpec
                        $res.ExtentDevicePath = $extPaths
                        #write-host "        Adding new VMFS Datastore with $($new.VmfsLabel) continue ?" -ForegroundColor Yellow
                        write-host "        Adding new VMFS Datastore with $($new.VmfsLabel)" -ForegroundColor Yellow
                        #pause
                        try { 
                            $dsView.ResignatureUnresolvedVmfsVolume($res) 
                        }
                        catch {
                            write-host "        Adding new VMFS Datastore with $($new.VmfsLabel) Failed" -ForegroundColor Red 
                        }
                        # Find and rename new datastore.
                        try {
                            $NewDatastore = Get-Datastore -VmHost $VMHost | Where-Object { $_.Name -like "snap-*$SourceVolumelable" }
                            if ($null -eq $NewDatastore) {
                                break
                            }
                            else {
                                Set-Datastore $NewDatastore -Name $DestinationVolumelable
                            }
                        }
                        catch {
                            Write-Error -MessageBOX "did not detect snap $SourceVolumelable"
                        }
                    }

                }
                $NewDatastoreTemp = get-datastore -Host $VMHost -Name $DestinationVolumelable
                if ($DestinationVolumelable -eq $NewDatastoreTemp.Name) {
                    Write-Host "        New Datasrote: $($NewDatastoreTemp.Name) was Create and Spoted on: $VMHost" -ForegroundColor Green
                    #pause
                    $NewDatastoreTemp
                }
            }
            else {
                # Allready added this VMFS
                # $new.VmfsLabel
                # Write-Host "        Skip: $($new.VmfsLabel) NewDevices: $($unBound.VmfsLabel)" -ForegroundColor Blue
            }
        }
    }
}
####################################################################################################################################

# Register Virtual machine form last get vm with a replace Source to Destination if needed
function Register-DrVM {
    param (
        $VC,
        $VMlist,
        $Cluster,
        $Datastore,
        $reregister,
        $folder_collection,
        # was test well i dont know why i select Test here but it basicly a Flag to start the loop, so i change it to -safetyoff $true
        # it was for debuging in a a multifunction, basicly a leftover of old code this need to be remove in the futre.
        $safetyoff
    )

    # $VMlist = $VMlist 
    # $Datastore = $config.resources.Datastore 
    # $cluster = $config.resources.Cluster.Destination
    # $cluster = $config.resources.Cluster.Source
    # $test = $true 
    # $reregister = $false 
    # $VC = $config.resources.vc.Destination

    # Start of main Loop for Register VMs
    if ($safetyoff -eq $true) {
        $cluster = Get-Cluster $Cluster
        $VMHost = Get-Cluster $cluster | Get-HAPrimaryVMHost
        foreach ($VM in $VMlist) {
            $SourceDatastore = $VM.DataStore
            if ($null -eq $VM.DestinationDataStore) {
                $DestinationDatastore = ($Datastore | ? { $_.Source -eq $VM.DataStore }).Destination
            }
            else {
                $DestinationDatastore = $VM.DestinationDataStore
            }
            
            # General VM Configuration
            $VMname = $VM.Name

            # Try to get the maped folder for the current VM before registering it.
            try {
                # here is a few test i run before getting the correct Command for geting the UNIC folder ID and save it as a obj.
                # $VMfolder = get-folder $VM.Folder -Server $VC -ErrorAction Stop
                #$VMfolder = get-folder -id (($folder_collection | ? { $_.Reletivepath -in $VM.Reletivepath}).FolderID) -Server $VC -ErrorAction Stop
                #foreach ( $VM in $VMlist ) { get-folder -id (($folder_collection | ? { $_.Reletivepath -in $VM.Reletivepath }).FolderID) -Server $VC -ErrorAction Stop }
                $VMfolder = get-folder -id (($folder_collection | ? { $_.Reletivepath -in $VM.Reletivepath }).FolderID) -Server $VC -ErrorAction Stop
            }
            catch {
                Write-Host "        Cant Find VMfolder" -f Red
                $VMFoldersBox = get-folder -Type VM -Server $VC | ? { $_.UID -match $VC }
                $selectedVM = show-DrBox -ArryList $VMFoldersBox -MessageBOX "Select VMfolder for VMs Registration" -testBox "Select VMfolder for: $($VM.Name)" # 
                # $VMfolder = Read-Host "        provide VMfolder Name for Register the VMs"
                $VMfolder = get-folder $selectedVM -Server $VC -ErrorAction SilentlyContinue
            }
            # if failed to get VMfolder stop the proccess ...
            if ($null -eq $VMfolder) { Write-Error "        Failed to Get VMFolder, Stop the Proccess and Run cleanup "; Start-Sleep 20; break }

            if ($reregister -eq $false) {
                # if registering the VM after Failedover to Destination side the name of the Datastore need to be replaced 
                $VMFilePath = ($VM.VMFilePath).Replace("$SourceDatastore", "$DestinationDatastore") #
                $SingleDS = $DestinationDatastore
            }
            else { 
                $VMFilePath = $VM.VMFilePath 
                $SingleDS = $SourceDatastore
            }
            $CurentVM = $null
            $CurentVM = get-VM -Datastore $SingleDS -Name $VMname -Server $VC -ErrorAction SilentlyContinue
            if ($null -eq $CurentVM ) {
                try { 
                    # write-host "        New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname "  -ForegroundColor Yellow
                    # New-VM -VMFilePath $VMFilePath  -VMHost $VMHost -Name $VMname | out-null
                    # Move-VM -VM $VMname -InventoryLocation $VMfolder | out-null
                    New-DrVM -VMFilePath $VMFilePath -VMHost $VMHost -VMName $VMname -VMfolder $VMfolder -VC $VC
                }
                catch {
                    $count = 1
                    $index = ($cluster | Get-VMHost).count
                    do {
                        $VMhostTemp = ($cluster | Get-VMHost | Get-Random)
                        try {
                            # write-host "        New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname " -ForegroundColor Yellow
                            # New-VM -VMFilePath $VMFilePath -VMHost $VMhostTemp -Name $VMname | out-null
                            # Move-VM -VM $VMname -InventoryLocation $VMfolder | out-null
                            New-DrVM -VMFilePath $VMFilePath -VMHost $VMHost -VMName $VMname -VMfolder $VMfolder -VC $VC
                        }
                        catch {
                            $NewVMFilePathERROR = $_.Exception.Message
                            Write-Error "        Faild to Register after second Try on $VMhostTemp with ERROR: $NewVMFilePathERROR"
                        }
                        $count++
                    } while ($index -eq $count ) 
                }
            }
            else {
                Write-Host "        Curent VM: $VMname Allready Exist in Datastore: $SingleDS on Server: $VC" -f Yellow
            }
        }
    }
    # End of main Loop for Register VMs  
}
####################################################################################################################################

# Register Virtual machine by VM FilePath ( .VMX File ) - used for Recover the Virtual machines Configuration if needed ( have a BUG with VMware that my failed just change the esxi)
function Register-DrVMFilePath {
    param (
        $Cluster,
        $VC,
        $Datastores,
        $folder_collection
        #$VMFolder
    )
    # Before Starting this Masive Task
    Write-Host "        Are U ! Sure you wish to go and find any VMX file in the selected Datastore for VM registration !" -f Red
    Pause

    # General VM Configuration
    $VMHost = Get-Cluster $cluster | Get-HAPrimaryVMHost

    Write-Host "        Select Folder for Restore VMs" -f Red
    $VMFoldersBox = get-folder -Type VM -Server $VC | Where-Object { $_.UID -match $VC }
    # list all VMs Folders on datacenter
    $selectedVM = show-DrBox -ArryList $VMFoldersBox -MessageBOX "Select VMfolder for VMs Registration" -testBox "Select VMfolder:" # 
    # $VMfolder = Read-Host "        provide VMfolder Name for Register the VMs"
    $VMfolder = get-folder $selectedVM -Server $VC -ErrorAction SilentlyContinue
    
    # if failed to get VMfolder stop the proccess ...
    if ($null -eq $VMfolder) { Write-Error "        Failed to Get VMFolder, Stop the Proccess and Run cleanup "; Start-Sleep 20; break }

    # loop Datastores for unknow VMs VMX files
    foreach ($SingleDS in $Datastores) {

        $ds = Get-Datastore -Name $SingleDS -server $VC -Host $VMHost | ForEach-Object { Get-View $_.Id }
        $SearchSpec = New-Object VMware.Vim.HostDatastoreBrowserSearchSpec
        $SearchSpec.matchpattern = "*.vmx"
        $dsBrowser = Get-View $ds.browser
        $DatastorePath = "[" + $ds.Summary.Name + "]"
        write-host "        list Datastore $DatastorePath" 

        # Find all .VMX file paths in datastore, filtering out ones with .snapshot (useful for NetApp NFS)
        $SearchResult = $dsBrowser.SearchDatastoreSubFolders($DatastorePath, $SearchSpec) | ForEach-Object { $_.FolderPath + ($_.File | Select-Object Path).Path }

        foreach ($VMFilePath in $SearchResult ) {   
            $VMname = ($VMFilePath.Split("/")[1].trim(".vmx"))
            write-host "        New VM: $VMname Path for new VM:: $VMFilePath" 
            $CurentVM = $null
            $CurentVM = get-VM -Datastore $SingleDS -Name $VMname -Server $VC -ErrorAction SilentlyContinue
            if ($null -eq $CurentVM ) {
                try { 
                    # write-host "        New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname " -ForegroundColor Yellow
                    # New-VM -VMFilePath $VMFilePath  -VMHost $VMHost -Name $VMname | out-null
                    # Move-VM -VM $VMname -InventoryLocation $VMfolder | out-null
                    New-DrVM -VMFilePath $VMFilePath -VMHost $VMHost -VMName $VMname -VMfolder $VMfolder -VC $VC
                }
                catch {
                    $count = 1
                    $index = ($cluster | Get-VMHost).count
                    do {
                        $VMhostTemp = ($cluster | Get-VMHost | Get-Random)
                        try {
                            # write-host "        New-VM -VMFilePath $VMFilePath -VMHost $VMHost -Name $VMname " -ForegroundColor Yellow
                            # New-VM -VMFilePath $VMFilePath -VMHost $VMhostTemp -Name $VMname | out-null
                            # Move-VM -VM $VMname -InventoryLocation $VMfolder | out-null
                            New-DrVM -VMFilePath $VMFilePath -VMHost $VMHost -VMName $VMname -VMfolder $VMfolder -VC $VC
                        }
                        catch {
                            $NewVMFilePathERROR = $_.Exception.Message
                            Write-Error "        Faild to Register after second Try on $VMhostTemp with ERROR: $NewVMFilePathERROR"
                        }
                        $count++
                    } while ($index -eq $count ) 
                }    
            }
            else {
                Write-Host "        Curent VM: $VMname Allready Exist in Datastore: $SingleDS on Server: $VC" -f Yellow
            }
        }
    }
}
####################################################################################################################################
# Invoke-DrRegisterVM -VMlist $VMlist -folder_collection $folder_collection -Cluster $config.resources.Cluster.$PassiveSite -VC $config.resources.VC.$PassiveSite -Datastore $config.resources.Datastore.$PassiveSite -timeout 6

# Unregister the the Virtual machine form the Selected VMware vSphere Server from $VMlist
<#
https://www.improvescripting.com/powershell-function-begin-process-end-blocks-explained-with-examples/
https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_thread_jobs?view=powershell-7.3
https://github.com/PowerShell/Modules/issues/75
https://github.com/PowerShell/ThreadJob
https://stackoverflow.com/questions/67318541/my-powershell-script-doesnt-do-multi-thread-job-why
#>
function Remove-DrVM {
    param (
        $VMlist,
        $VC,
        $timeout,
        $remove
    )
    Begin {
        if ($null -eq $remove) { $remove = $true }
        Write-host "        Running on vCenter: $VC, VMs to Stop&Unregister >" -f Yellow
        $VMlistTemp = @()
        foreach ($vm in $VMlist) {
            Try { 
                $VMlistTemp += Get-VM -name $($vm.name) -Datastore $($vm.DataStore) -server $VC -ErrorAction stop 
            }
            catch {
                $missingVM = $vm.name
                Write-host "        VM: $missingVM is Missing Consider go Back to Cleanup"
            }
        }
    } 
    Process {
        $missingVMArry = @()
        if (!([string]::IsNullOrEmpty($VMlistTemp)) ) {
            if ($VMlist.count -eq $VMlistTemp.count) {
                Write-Host "        LIST:$VMlistTemp to remove" -f Green
            }
            else {
                $missingVMArry += $missingVM
            } 
            if (([string]::IsNullOrEmpty($missingVMArry))) {
                foreach ($vm in $VMlistTemp) {
                    $vm = get-vm $vm
                    $State = $null
                    $reTry = $null
                    try {
                        do {
                            if ($State -eq 'Success') { 
                                $PowereState = 'PoweredOff'
                                [System.Threading.Thread]::Sleep(5000)
                            }
                            else {
                                $PowereState = (get-vm $vm).PowerState
                                [System.Threading.Thread]::Sleep(50)
                            }
                            switch ($PowereState) {
                                'PoweredOn' {
                                    Write-host "        Trying to Stop/Unregister VM: $($vm.name) From VC: $VC" -ForegroundColor Green
                                    try { 
                                        if ( $wasSuspended -eq $true) {
                                            Write-host "        VM Was Suspended will give it a 3 to Sync"
                                            [System.Threading.Thread]::Sleep(3000) # 3sec
                                        }
                                        get-vm $vm | Shutdown-VMGuest -Confirm:$false -ErrorAction Stop
                                        [System.Threading.Thread]::Sleep(6000)
                                        $vm = get-vm $vm
                                        do {
                                            $State = (Get-Task | Where-Object { $_.name -eq 'ShutdownGuest' } | Select-Object -last 1).State
                                            [System.Threading.Thread]::Sleep(4000)
                                            if ($State -eq 'Success' ) { 
                                                Write-host "        Shutdown Guest VM: $($vm.name) is:$State " -ForegroundColor Green 
                                                $reTry = $null
                                            }
                                        } until ($State -eq 'Success' )
                                    }
                                    catch {
                                        Write-host "        Failed to Stop With ErrorMessage: $($_.Exception.Message) | on VM: $($vm.name) From VC: $VC do you wish to force it ?" -ForegroundColor red
                                        $YESno = Get-YesNo -MessageboxTitle "Force Shutdown on:$($vm.name)" -Messageboxbody " this VM:$($vm.name) failed to Shutdown-VMGuest"
                                        if ($YESno -eq "Yes") {
                                            Write-Host "        you are about to kill VM:$($vm.name) wish to continume ?"
                                            $vm | Stop-VM -RunAsync:$true -Confirm:$false -ErrorAction Stop
                                        }
                                        else {
                                            $reTry = $true
                                            Start-Sleep -seconds 15 -message " Failed to ShutdownGuest timeout for the next try in:" -titel "ShutdownGuest ReTry"
                                        }   
                                    }
                                    if ($null -eq $reTry) {
                                        $retryCount = 0
                                        do { 
                                            $PowereState = (get-vm $vm).PowerState
                                            [System.Threading.Thread]::Sleep(1000) 
                                            $retryCount++
                                        } until ($PowereState -eq 'PoweredOff' -or $retryCount -eq 120)
                                        if ($PowereState -eq 'PoweredOff') { Write-host "        VM:$($vm.name) was Succsefuly:$PowereState." -ForegroundColor Yellow }
                                        else {
                                            Write-host "        VM:$($vm.name) state is unknow Counter reach:$retryCount" -ForegroundColor red 
                                            $retryCount
                                        }
                                        [System.Threading.Thread]::Sleep(1000)
                                    } 
                                }
                                'Suspended' {
                                    Write-Host ("        VM:$($vm.name) is Suspended, will Try to resume and then:" + 
                                        "`r`n" + "        1: poweroff VM:$($vm.name)." +
                                        "`r`n" + "        2: remove VM:$($vm.name)."
                                    )  -ForegroundColor Yellow
                                    $vm = get-vm $vm
                                    while ($vm.PowerState -eq 'Suspended') {
                                        $vm = get-vm $vm
                                        try { 
                                            $vm | start-VM -Confirm:$false -ErrorAction Stop
                                        }
                                        catch {
                                            Write-Host "        VM is Resuming, VM:$($vm.name), the State:$($vm.PowerState)), will sleep 10s"
                                            # pause
                                            [System.Threading.Thread]::Sleep(50)
                                        }
                                    }
                                    $wasSuspended = $true
                                    do {
                                        $PowereState = (get-vm $vm).PowerState
                                        [System.Threading.Thread]::Sleep(1000) 
                                    } until ($PowereState = 'PoweredOn')
                                    Start-Sleep -seconds 2
                                }
                                'default' {
                                    Write-Host "        VM is State, VM:$($vm.name), is unknow or Invalid ERROR"
                                    pause
                                }
                            }
                            [System.Threading.Thread]::Sleep(1000)
                        } while ($PowereState)

                    }
                    catch {
                        $VMremoveError = $_.Exception.Message
                        Write-error "        Faile To Shutdown/PowerOff VM: $($vm.name) with ERROR: $VMremoveError | got to CleanUP"
                        Break
                    }
                }
                if ($remove -eq $true) {
                    if ($null -eq $VMremoveError) {
                        if ($VMlistTemp) {
                            Start-Sleep -seconds $timeout -titel "VMs Sync" -message "VMs PowerSate is Syncing in VC Please wait"
                            foreach ($vm in $VMlistTemp) {
                                $vm = get-vm $vm
                                #do { [System.Threading.Thread]::Sleep(200) } until ((get-job -name $vm.name).State -eq 'Completed')
                                if ( $vm.PowerState -eq 'PoweredOff' ) {
                                    Write-host "        Trying to Unregister VM: $($vm.name) From VC: $VC" -ForegroundColor Green
                                    try { 
                                        $vm | Remove-VM -Confirm:$false -ErrorAction Stop 
                                    }
                                    catch {
                                        Write-Host "        Please Remove VM:$($vm.name) Manualy before continume, Standby for User"
                                        pause
                                    }
                                    [System.Threading.Thread]::Sleep(200)
                                }
                            }
                        }
                    }
                }
            }
            else {
                Write-Host  "        VMs that Found:" ; $VMlistTemp
                Write-error "        VMs that was not Found: $missingVMArry " ; $missingVMArry
                Write-Host  "        go back to CleanUP" -f Yellow
                Break
            }
        }
        else {
            if (!$VMlist) { Write-Host "        unknow Error, VMlist is Empty" -f Red }
            Write-Host "        Fix VM Register issue Command Register-DrVMFilePath -Cluster <Cluster> -VC <VC> -Datastores <Datastore>" -f Blue
            pause
            $DoBreak = Get-YesNo -MessageboxTitle "Continume Cleanup" -Messageboxbody "Continume with removing the rest of the Resorces and Cleanup ?"
            if ( $DoBreak -eq 'Yes') { Break }
        }
    }
    End {
        Start-Sleep -seconds $timeout
    }
}
# Remove-DrVM -VMlist $VMlist -VC $config.resources.VC.$Source -timeout 5

####################################################################################################################################

# just set a Datastore in to a MaintenanceMode
function Set-DrDSMaintenanceMode {
    param (
        $Datastore,
        $timeout

    )
    foreach ( $Datastore in $Datastore ) {
        Get-Datastore -name $Datastore  | Set-Datastore -MaintenanceMode:$true
        Start-Sleep -seconds $timeout 
    }
}
####################################################################################################################################

# Rescan Storage HBA

function Set-DrRescanHBA {
    param (
        $cluster,
        $timeout
    )
    $cluster = Get-Cluster $cluster
    $VMHosts = $cluster | Get-VMHost 
    foreach ($VMHost in $VMHosts) {  
        try {
            $VMHost | Get-VMHostStorage -RescanAllHba | Out-Null
        }
        catch {
            { 1: throw $_.Exception.Message }
        }
    }
    Write-Host "        Finish Rescan HBA on $cluster :"
    if ($null -eq $timeout) { $timeout = 3 }
    Start-Sleep -seconds $timeout 
}
####################################################################################################################################

# Fix the VMware Virtual Machine Network NIC with the same network name from the Source to the Destination
function Set-DrVMNetwork {
    param (
        $VMs,
        $VC,
        $DatastoreName,
        $test
    )
    foreach ($VM in $VMs ) {
        foreach ( $Datastore in $DatastoreName ) {
            $myNetworkAdapters = Get-VM $VM.name -Datastore $Datastore -ErrorAction SilentlyContinue | Get-NetworkAdapter -Name "Network adapter 1" -ErrorAction SilentlyContinue
            $myVDPortGroup = Get-VDPortgroup -Server $VC -Name $VM.PortGroup
            if ($null -eq $myNetworkAdapters ) {
                # Skip VM , this VM is not in Curent Database
            }
            else {
                try {   
                    if ($test -eq $true) {
                        Set-NetworkAdapter -NetworkAdapter $myNetworkAdapters -Portgroup $myVDPortGroup -Confirm:$false -ErrorAction Stop
                        get-VM $VM.name | Get-NetworkAdapter | Set-NetworkAdapter -StartConnected:$false -Confirm:$false -ErrorAction Stop
                    }
                    if ($test -eq $False) {
                        Set-NetworkAdapter -NetworkAdapter $myNetworkAdapters -Portgroup $myVDPortGroup -Confirm:$false -ErrorAction Stop
                        
                    }
                }
                catch {
                    $ErrorNetworkAdapte = $_.Exception.Message
                    Write-host "        Setting Nic for VM:$($VM.name) Stop with ERROR: $ErrorNetworkAdapte FIX Nic to $($VM.PortGroup.name) before advancing"
                    #pause
                }
            }
        }
    }
}

####################################################################################################################################

function get-VMDatastoreList {
    param (
        $datastore,
        $CSVpath
        
    )

    # Buil the VMs per Storage
    $VMs = Get-Datastore $datastore | Get-VM 

    # defenition of list
    $VMs = $VMs | Select-Object Name, `
    @{N = "Datastore"; E = { [string]::Join(',', (Get-Datastore -Id $_.DatastoreIdList | Select-Object -ExpandProperty Name)) } }, `
    @{N = "Folder"; E = { $_.Folder.Name } } 

    #   export CSV 
    if ($null -eq $CSVpath ) {
        $VMs
    }
    else {
        $VMs
        $VMs | Export-Csv $CSVpath -NoTypeInformation
    }
}