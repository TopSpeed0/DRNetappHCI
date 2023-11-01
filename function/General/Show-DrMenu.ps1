function Show-DrMenu {
    $Title = "- DR Scenario ©  "
    Clear-Host
    Write-Host '       	┌─────────────────────────────────────────────────────────────────┐' -f red
    Write-Host '       	│      By Yitzhak Bohadana, 2021-23                       │' -f red
    Write-Host '       	│      ╔══════════════════════════════════════════════════╗       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *««««* ' -f Green -nonewline; Write-Host "│   $Title"                   -f Cyan -nonewline; Write-Host '   '       -nonewline         ; Write-Host ' │' -nonewline -F Cyan                 ; Write-Host ' *»»»»* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *««««* ' -f Green -nonewline; Write-Host "│ 1: Press '1' TestFaildover . "  -f Cyan -nonewline; Write-Host '  │'         -NoNewline -F Cyan ; Write-Host ' *»»»»* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *««««* ' -f Green -nonewline; Write-Host "│ 2: Press '2' FailedOver . "     -f Cyan -nonewline; Write-Host '     │'      -NoNewline -F Cyan ; Write-Host ' *»»»»* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *««««* ' -f Green -nonewline; Write-Host "│ 3: Press '3' CleanUP . "        -f Cyan -nonewline; Write-Host '        │'   -NoNewline -F Cyan ; Write-Host ' *»»»»* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *Beta* ' -f Green -nonewline; Write-Host "│ 4: Press '4' RealDR . "         -f Cyan -nonewline; Write-Host '         │'  -NoNewline -F Cyan ; Write-Host ' *Beta* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *ALFA* ' -f Green -nonewline; Write-Host "│ 5: Press '5' RevertDirection ." -f Cyan -nonewline; Write-Host ' │'          -NoNewline -F Cyan ; Write-Host ' *ALFA* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *ALFA* ' -f Green -nonewline; Write-Host "│ 5: Press '6' Migrate VM FA2B ." -f Cyan -nonewline; Write-Host ' │'          -NoNewline -F Cyan ; Write-Host ' *ALFA* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *SOON* ' -f Green -nonewline; Write-Host "│ 5: Press '8' Build Config file." -f Cyan -nonewline; Write-Host '│'          -NoNewline -F Cyan ; Write-Host ' *SOON* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ║'-f red -NoNewline ;Write-Host ' *««««* ' -f Green -nonewline; Write-Host "│ Q: Press 'Q' to quit ."           -f Cyan -nonewline;Write-Host '         │' -NoNewline -F Cyan ; Write-Host ' *»»»»* ' -f Green -nonewline ;Write-Host '║       │' -f red
    Write-Host '       	│      ╚══════════════════════════════════════════════════╝       │' -f red
    Write-Host '       	│                                                                 │' -f red
    Write-Host '       	└─────────────────────────────────────────────────────────────────┘' -f red
}

function Start-Sleep {
    param (
        $seconds,
        $message,
        $titel
    )
    if ($null -eq $message) {$message="Delying next Proccess...."}
    if ($null -eq $seconds) {$seconds=5}
    if ($null -eq $titel) {$titel="Timeout Count:"}
    $doneDT = (Get-Date).AddSeconds($seconds)
    while($doneDT -gt (Get-Date)) {
        $secondsLeft = $doneDT.Subtract((Get-Date)).TotalSeconds
        $Secs = ($seconds - $secondsLeft) / $seconds * 100
        Write-Progress -Activity "        $titel" -Status "$message :$([math]::Round($Secs))% ." -SecondsRemaining $secondsLeft -PercentComplete $Secs
        [System.Threading.Thread]::Sleep(500)
    }
    [System.Threading.Thread]::Sleep(500)
Write-Progress -Activity "        $titel" -Status "End of: $message Finished 100% ." -SecondsRemaining 0 -Completed
}
#Show-DrTable $DrVMs 

function pause{ $null = Read-Host '        Press Any Key or Enter to continue...' }
