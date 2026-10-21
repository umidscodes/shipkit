# Tests ship-watch.ps1 with tiny limits. Used by CI on Windows.
$ErrorActionPreference = "Stop"
$watch = Join-Path $PSScriptRoot "ship-watch.ps1"
$tmp = Join-Path ([IO.Path]::GetTempPath()) ("shipwatch-" + [guid]::NewGuid())
New-Item -ItemType Directory $tmp | Out-Null
& git -C $tmp init -q
& git -C $tmp -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
$log = "$tmp.log"
$script:fail = 0

function Expect($name, $want, $max, $stall, $script) {
    $ErrorActionPreference = "Continue"
    # Call it in-process: an -Arguments array can't cross a powershell.exe -File boundary.
    & $watch -Worktree $tmp -Log $log -Interval 1 -Max $max -Stall $stall `
        -Command "powershell" -Arguments @("-NoProfile", "-Command", $script) 2>$null
    $got = $LASTEXITCODE
    if ($got -eq $want) { Write-Host "ok    watch: $name" }
    else { Write-Host "FAIL: watch: $name exited $got, want $want"; $script:fail = 1 }
}

Expect "succeeding command" 0 20 5 "Set-Content '$tmp\f' a; Start-Sleep 2"
Expect "failing command" 1 20 5 "exit 7"
Expect "idle command stalls" 2 30 3 "Start-Sleep 30"
Expect "rewriting the same content is a stall" 2 30 3 "while (`$true) { Set-Content '$tmp\loop' same; Start-Sleep 1 }"
Expect "steady progress runs until the time limit" 3 5 3 "`$i = 0; while (`$true) { `$i++; Set-Content '$tmp\count' `$i; Start-Sleep 1 }"
if (-not (Select-String -Path $log -Pattern "ship-watch: timed out" -Quiet)) {
    Write-Host "FAIL: watch: log has no summary line"; $script:fail = 1
}

Remove-Item -Recurse -Force $tmp, $log -ErrorAction SilentlyContinue
exit $script:fail
