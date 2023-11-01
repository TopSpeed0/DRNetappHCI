
function Invoke-Verification {
    param (
        $VMlist
    )
    $MovedVMs = ($VMlist | Select-Object DestinationDataStore -Unique) | % { Get-DrVM -Datastore $PSItem.DestinationDataStore -VC $global:DefaultVIServers.name }
    if ($MovedVMs) {
        Write-Host "         Successfully Finished Test Failedover`r`n         this is the list of VMs:`r`n" -ForegroundColor Yellow
        Write-Host "        ┌──────────────────────────────────────────────────────────────┐" -ForegroundColor Blue
        Show-DrTable $MovedVMs
        Write-Host "        └──────────────────────────────────────────────────────────────┘"-ForegroundColor Blue
        pause
    }
    else {
        Write-Host "          Finished Test Failedover with an Failure, Run CleanUp and fix the Issue. " -ForegroundColor Green
        pause
    }
}
