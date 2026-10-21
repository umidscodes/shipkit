# Runs an agent command (e.g. headless omp) in a git worktree and stops it when it
# stalls or runs too long, so a looping local model can't burn hours unnoticed.
#
#   & ship-watch.ps1 -Worktree DIR [-Log FILE] [-Max SECONDS] [-Stall SECONDS]
#       [-Interval SECONDS] -Command omp -Arguments @("-p", "--no-session", ...)
#   (call it with & from PowerShell: an array can't be passed through powershell -File)
#
# Progress = the worktree's content changes: a new commit, or a different set of
# changes (tracked diff plus untracked files' contents). Rewriting the same content
# over and over is NOT progress, which is how agent loops usually look from outside.
#
# Exit codes: 0 command succeeded, 1 command failed, 2 stalled (no progress for -Stall
# seconds), 3 timed out (-Max seconds), 64 usage error.
# The last line of the log is a summary: "ship-watch: <result> after <n>s".
param(
    [Parameter(Mandatory = $true)][string]$Worktree,
    [Parameter(Mandatory = $true)][string]$Command,
    [string[]]$Arguments = @(),
    [string]$Log = "",
    [int]$Max = 2400,
    [int]$Stall = 900,
    [int]$Interval = 30
)

$git = (Get-Command git -ErrorAction SilentlyContinue)
if (-not $git) { Write-Error "ship-watch: git not found"; exit 64 }
& git -C $Worktree rev-parse --git-dir *> $null
if ($LASTEXITCODE -ne 0) { Write-Error "ship-watch: $Worktree is not a git worktree"; exit 64 }
if (-not $Log) { $Log = "$Worktree.watch.log" }
$errLog = "$Log.stderr"

function Get-Fingerprint {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine((& git -C $Worktree rev-parse HEAD 2>$null) -join "`n")
    [void]$sb.AppendLine((& git -C $Worktree diff HEAD 2>$null) -join "`n")
    foreach ($f in (& git -C $Worktree ls-files --others --exclude-standard 2>$null)) {
        [void]$sb.AppendLine($f)
        $p = Join-Path $Worktree $f
        if (Test-Path -LiteralPath $p -PathType Leaf) {
            [void]$sb.AppendLine([Convert]::ToBase64String([IO.File]::ReadAllBytes($p)))
        }
    }
    $sha = [Security.Cryptography.SHA256]::Create()
    [BitConverter]::ToString($sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($sb.ToString())))
}

function Finish([int]$code, [string]$result, [int]$elapsed) {
    $line = "ship-watch: $result after ${elapsed}s"
    if (Test-Path $errLog) { Get-Content $errLog | Add-Content $Log; Remove-Item $errLog }
    Add-Content $Log $line
    [Console]::Error.WriteLine($line)
    exit $code
}

function Stop-Tree($p) {
    # omp and shells spawn children: kill the whole tree.
    & taskkill /T /F /PID $p.Id *> $null
    $p.WaitForExit(5000) | Out-Null
}

$startArgs = @{ FilePath = $Command; PassThru = $true; NoNewWindow = $true
    RedirectStandardOutput = $Log; RedirectStandardError = $errLog }
# Start-Process joins arguments with spaces and doesn't quote them, so quote any
# argument with spaces or quotes ourselves (paths like "C:\My Repo\...").
$quoted = foreach ($a in $Arguments) {
    if ($a -match '[\s"]') { '"' + ($a -replace '"', '\"') + '"' } else { $a }
}
if ($Arguments.Count -gt 0) { $startArgs.ArgumentList = $quoted }
$proc = Start-Process @startArgs
$null = $proc.Handle # without this, Windows PowerShell 5.1 can report ExitCode as empty
$start = Get-Date
$last = Get-Fingerprint
$lastChange = $start

while ($true) {
    Start-Sleep -Seconds $Interval
    $now = Get-Date
    $elapsed = [int]($now - $start).TotalSeconds
    if ($proc.HasExited) {
        $proc.WaitForExit()
        if ($proc.ExitCode -eq 0) { Finish 0 "finished" $elapsed }
        Finish 1 "command failed (exit $($proc.ExitCode))" $elapsed
    }
    $fp = Get-Fingerprint
    if ($fp -ne $last) { $last = $fp; $lastChange = $now }
    if ($elapsed -ge $Max) { Stop-Tree $proc; Finish 3 "timed out (limit ${Max}s)" $elapsed }
    if (($now - $lastChange).TotalSeconds -ge $Stall) {
        Stop-Tree $proc; Finish 2 "stalled (no new changes for ${Stall}s)" $elapsed
    }
}
