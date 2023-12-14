# Starting Commands and logs
$CWD = [Environment]::CurrentDirectory
Set-Location $CWD
Start-Transcript -Path C:\temp\$(Get-Random).log

# Module imports
Set-PowerCLIConfiguration -Scope AllUsers -ParticipateInCEIP $false -Confirm:$false | out-null
# Clear last Load of the HciVMwareDR if we implement a fix
if (get-Module HciVMwareDR) { remove-module -Name HciVMwareDR -Force -ErrorAction Stop }
Import-Module HciVMwareDR -ErrorAction Stop
Import-Module SolidFire.Core
import-module VMware.VimAutomation.Core -Force -SkipEditionCheck -ErrorAction Stop| out-null

# Configuration Files remark the one you need
# Prod
# $global:config = Get-Content .\Config-p.json | ConvertFrom-Json
# test
# $global:config = Get-Content .\Config-t.json | ConvertFrom-Json
$global:config = Get-Content .\Config-DR.json| ConvertFrom-Json

####################################################################
#
# Main Credentia for VMware and Solidfire

if ( !( Test-Path (get-item -path $($config.VMware.keyFile) -ErrorAction SilentlyContinue)) -or !( Test-Path (get-item -path $($config.VMware.pswdFile) -ErrorAction SilentlyContinue )) ) {
    Write-Host "        No Password File Set for VMware, Setting new Encrypted Password"
    Set-EncryptedPswd -keyFile $($config.VMware.keyFile) -pswdFile $($config.VMware.pswdFile)
}

if ( !( Test-Path (get-item -path $($config.SolidFire.keyFileSolid) -ErrorAction SilentlyContinue )) -or !( Test-Path (get-item -path $($config.SolidFire.pswdFileSolid) -ErrorAction SilentlyContinue )) ) {
    Write-Host "        No Password File Set for SolidFire, Setting new Encrypted Password"
    Set-EncryptedPswd -keyFile $($config.SolidFire.keyFileSolid) -pswdFile $($config.SolidFire.pswdFileSolid)
}


# VMware Credential
$VMwareEncryptedPswd = Get-Content -Path $config.VMware.pswdFile | ConvertTo-SecureString -Key (Get-Content -Path $config.VMware.keyFile)
$global:VMwareCredential = New-Object System.Management.Automation.PSCredential($config.VMware.user, $VMwareEncryptedPswd)

# SolidFire Credential
$SoldiFireEncryptedPswd = Get-Content -Path $config.SolidFire.pswdFileSolid | ConvertTo-SecureString -Key (Get-Content -Path $config.SolidFire.keyFileSolid)
$global:SFCredential = New-Object System.Management.Automation.PSCredential($config.SolidFire.SolidUser, $SoldiFireEncryptedPswd)
####################################################################

# remove last VMs Configuration or load it
$RemoveConfig = Get-YesNo -MessageboxTitle "Remove VMlist Config" -Messageboxbody "Remove last VMlist Config File ?, NO: Will try to load last config"
if ( $RemoveConfig -eq 'Yes') {Remove-Item .\VMlist.json -Force -ErrorAction SilentlyContinue}
if ( $RemoveConfig -eq 'No') {
    if ($null -eq $global:VMlist){
        try {
            Write-Host "        Reloading Last VMlist Config" -f Green 
            $global:VMlist = Get-Content .\VMlist.json | ConvertFrom-Json
            pause
        }
        catch {
            Write-Error "        FAILED: to load last Config: ERROR Message:$($_.Exception.Message)"
        }
    } else {
        Write-Host "        Last VMlist Config allready loadded" -f Green 
    }
}
####################################################################
# Menu 
Clear-Host
function Menu {
    do {
        Show-DrMenu
        $defaultscenario = "q"
        Write-Host "                                                                               "
        Write-Host "        Select scenario , or press <enter> to accept the default is 'Q' to quit" -ForegroundColor Yellow
        Write-Host "        default is $($defaultscenario)" -ForegroundColor Yellow -NoNewline ; Write-Host ":" -NoNewline
        $scenario = Read-Host
        If ($scenario -eq "") {
            $scenario = $defaultscenario
        }
        # switch Case
        switch ($scenario) 
        {
            # 1 TestFaildover
            '1' {
                .\Scripts\TestFaildover.ps1 -config $global:config -VMwareCredential $VMwareCredential -SFCredential $SFCredential
            }
            # 2 FailedOver
            '2' {
                .\Scripts\FailedOver.ps1 -config $global:config -VMwareCredential $VMwareCredential -SFCredential $SFCredential -FailoverFromSite (get-DrDirectionFromHost)
            }
            # 3 CleanUP
            '3' {
                .\Scripts\CleanUP.ps1 -config $global:config -VMwareCredential $VMwareCredential -SFCredential $SFCredential
            }
            # 4 DR
            '4' {
                .\Scripts\DR.ps1
            }
            # 5 Migrate VM
            '5' {
                .\Scripts\MigrateVM.ps1
            }
        }
    } until ($scenario -eq 'q')
}
Menu
