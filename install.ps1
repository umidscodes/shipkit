# Installs shipkit for your user so Claude Code and omp can use it in every project.
#   powershell -ExecutionPolicy Bypass -File install.ps1             # install / update
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall  # remove
#
# Safety: shipkit only ever replaces or removes files it installed itself. Skills get a
# .shipkit marker file, agents end with a marker comment. Anything else with the same
# name is left alone and reported.
param([switch]$Uninstall, [string]$Prefix = $HOME)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false) # no BOM: tools read the frontmatter
$mark = "<!-- installed by shipkit -->"

$claudeAgents = Join-Path $Prefix ".claude\agents"
$claudeSkills = Join-Path $Prefix ".claude\skills"
$ompAgents = Join-Path $Prefix ".omp\agent\agents"
$ompSkills = Join-Path $Prefix ".omp\agent\skills"
$kitHome = Join-Path $Prefix ".shipkit"

$roles = Get-ChildItem (Join-Path $root "roles") -Directory
$skills = Get-ChildItem (Join-Path $root "skills") -Directory
$script:skipped = 0

function Write-Text($path, $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), $utf8)
}
function Read-Text($path) { [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }
function Test-OursAgent($path) { -not (Test-Path $path) -or (Read-Text $path).Contains($mark) }
function Test-OursSkill($path) { -not (Test-Path $path) -or (Test-Path (Join-Path $path ".shipkit")) }
function Skip($path) { Write-Host "SKIP   $path (exists and isn't shipkit's; left untouched)"; $script:skipped++ }

if ($Uninstall) {
    foreach ($r in $roles) {
        foreach ($f in (Join-Path $claudeAgents "$($r.Name).md"), (Join-Path $ompAgents "$($r.Name).md")) {
            if ((Test-Path $f) -and (Read-Text $f).Contains($mark)) { Remove-Item $f }
        }
    }
    foreach ($s in $skills) {
        foreach ($d in (Join-Path $claudeSkills $s.Name), (Join-Path $ompSkills $s.Name)) {
            if (Test-Path (Join-Path $d ".shipkit")) { Remove-Item -Recurse $d }
        }
    }
    Remove-Item -Recurse $kitHome -ErrorAction SilentlyContinue
    Write-Host "shipkit removed (only files it installed)."
    exit 0
}

foreach ($r in $roles) {
    $prompt = Read-Text (Join-Path $r.FullName "prompt.md")
    foreach ($t in @(@{ Header = "claude.yml"; Dir = $claudeAgents }, @{ Header = "omp.yml"; Dir = $ompAgents })) {
        $out = Join-Path $t.Dir "$($r.Name).md"
        if (-not (Test-OursAgent $out)) { Skip $out; continue }
        $header = (Read-Text (Join-Path $r.FullName $t.Header)).TrimEnd()
        Write-Text $out "---`n$header`n---`n`n$($prompt.TrimEnd())`n`n$mark`n"
    }
    Write-Text (Join-Path $kitHome "roles\$($r.Name).md") $prompt
    Write-Host "agent  $($r.Name)"
}

foreach ($s in $skills) {
    foreach ($dest in @($claudeSkills, $ompSkills)) {
        $target = Join-Path $dest $s.Name
        if (-not (Test-OursSkill $target)) { Skip $target; continue }
        Remove-Item -Recurse $target -ErrorAction SilentlyContinue
        Get-ChildItem $s.FullName -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($s.FullName.Length).TrimStart('\')
            Write-Text (Join-Path $target $rel) (Read-Text $_.FullName)
        }
        Write-Text (Join-Path $target ".shipkit") "installed by shipkit; safe to delete with install.ps1 -Uninstall`n"
    }
    Write-Host "skill  /$($s.Name)"
}

foreach ($f in Get-ChildItem (Join-Path $root "scripts") -File | Where-Object { $_.Name -like "setup-labels.*" -or $_.Name -like "ship-watch.*" }) {
    Write-Text (Join-Path $kitHome "scripts\$($f.Name)") (Read-Text $f.FullName)
}

Write-Host ""
if ($script:skipped -gt 0) { Write-Host "Note: $($script:skipped) item(s) skipped to protect files shipkit didn't create." }
Write-Host "Installed for Claude Code (~/.claude) and omp (~/.omp/agent), prompts in ~/.shipkit."
Write-Host "In a repo, run once:  powershell -File ~/.shipkit/scripts/setup-labels.ps1"
Write-Host "Then start a feature: /ship-feature <idea>   (omp: /skill:ship-feature <idea>)"
