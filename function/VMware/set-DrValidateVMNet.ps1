# i nevered used that in the end dont know if it is any good ! mark for DEL
function set-DrValidateVMNet {
    param (
        $VMlist,
        $config,
        $sourceVC,
        $DestinationVC,
        $timeout
    )

    # $VMlist = $VMlist ; $sourceVC = $config.resources.vc.source  ; $DestinationVC = $config.resources.vc.Destination

    # Disconect and Reconect to Source $config.resources.VC.Source
    Disconnect-DrVC -DisconnectVC $config.resources.vc.Destination -ReconectVC $config.resources.VC.Source -VMwareCredential $VMwareCredential -reconect $true

    Write-host "        Test network Mapping from vCenter: $sourceVC to $DestinationVC >" -f Yellow
    # Set-TableSpace $VMlist

    $myVDPortGroup = @()
    foreach ($VM in $VMlist ) { 
        #
        $myVDPortGroup += Get-VDPortgroup -Server $sourceVC -Name $VM.PortGroup 
    }
    #
    $myVDPortGroup = $myVDPortGroup | Select-Object name -Unique
    #
    if ($null -eq $myVDPortGroup ) {
        # Skip VM , this VM is not in Curent Database
    }
    else {

        # Disconect and Reconect to Destination $config.resources.vc.Destination
        Disconnect-DrVC -DisconnectVC  $config.resources.VC.Source -ReconectVC $config.resources.vc.Destination -VMwareCredential $VMwareCredential -reconect $true
        foreach ($VDPortGroup in $myVDPortGroup) {
            try {   
                Get-VDPortgroup $VDPortGroup.name
            }
            catch {
                $ErrorNetworkAdapte = $_.Exception.Message
                Write-host "        Network Mapping from source to Destination is not Set on $VDPortGroup.name ERR: $ErrorNetworkAdapte" 
            }
        }
    }
}