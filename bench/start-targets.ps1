# Opens the external terminals measured by keylatency.ps1, each running cmd.exe with a
# short prompt on a cleared screen, titled so keylatency.ps1 -Title can find them.
param([string[]]$Targets = @('conhost', 'wt'))

$cmdArgs = '/q /k "prompt $G & title {0} & cls"'
foreach ($t in $Targets) {
    switch ($t) {
        'conhost' { Start-Process conhost.exe -ArgumentList ('cmd.exe ' + ($cmdArgs -f 'KLAT-CONHOST')) }
        'wt' { Start-Process wt.exe -ArgumentList ('-w new --title KLAT-WT --suppressApplicationTitle cmd.exe ' + ($cmdArgs -f 'KLAT-WT')) }
    }
}
