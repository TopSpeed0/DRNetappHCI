function Get-DrDirectionFromHost {
    $x = "Source"
    Write-Host "        Please select Source Active Datatastore Source ( HRZ ) , Destination ( THC )." -ForegroundColor Yellow
    Write-Host "        default is $($x)" -ForegroundColor Yellow -NoNewline ; Write-Host ":" -NoNewline

    # Read host Selection and set default scenario
    $a = Read-Host
    If ($a -eq "") {
        $a = $x
    }
    switch ($a) {
        'Source' {$FailoverFromSite="Source"}
        'Destination' {$FailoverFromSite="Destination"}
    }
    return $FailoverFromSite
} 