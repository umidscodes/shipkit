# Installs shipkit for your user so Claude Code and omp can use it in every project.
#   powershell -ExecutionPolicy Bypass -File install.ps1             # install / update
#   powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall  # remove
param([switch]$Uninstall, [string]$Prefix = $HOME)

$ErrorActionPreference = "Stop"
$root = $PSScriptRoot
$utf8 = New-Object System.Text.UTF8Encoding($false) # no BOM: tools read the frontmatter

$claudeAgents = Join-Path $Prefix ".claude\agents"
$claudeSkills = Join-Path $Prefix ".claude\skills"
$ompAgents = Join-Path $Prefix ".omp\agent\agents"
$ompSkills = Join-Path $Prefix ".omp\agent\skills"
$kitHome = Join-Path $Prefix ".shipkit"

$roles = Get-ChildItem (Join-Path $root "roles") -Directory
$skills = Get-ChildItem (Join-Path $root "skills") -Directory

function Write-Text($path, $text) {
    New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
    [IO.File]::WriteAllText($path, ($text -replace "`r`n", "`n"), $utf8)
}

function Read-Text($path) { [IO.File]::ReadAllText($path) -replace "`r`n", "`n" }

if ($Uninstall) {
    foreach ($r in $roles) {
        Remove-Item (Join-Path $claudeAgents "$($r.Name).md"), (Join-Path $ompAgents "$($r.Name).md") -ErrorAction SilentlyContinue
    }
    foreach ($s in $skills) {
        Remove-Item -Recurse (Join-Path $claudeSkills $s.Name), (Join-Path $ompSkills $s.Name) -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse $kitHome -ErrorAction SilentlyContinue
    Write-Host "shipkit removed."
    exit 0
}

foreach ($r in $roles) {
    $prompt = Read-Text (Join-Path $r.FullName "prompt.md")
    foreach ($t in @(@{ Header = "claude.yml"; Dir = $claudeAgents }, @{ Header = "omp.yml"; Dir = $ompAgents })) {
        $header = (Read-Text (Join-Path $r.FullName $t.Header)).TrimEnd()
        Write-Text (Join-Path $t.Dir "$($r.Name).md") "---`n$header`n---`n`n$prompt"
    }
    Write-Text (Join-Path $kitHome "roles\$($r.Name).md") $prompt
    Write-Host "agent  $($r.Name)"
}

foreach ($s in $skills) {
    foreach ($dest in @($claudeSkills, $ompSkills)) {
        $target = Join-Path $dest $s.Name
        Remove-Item -Recurse $target -ErrorAction SilentlyContinue
        Get-ChildItem $s.FullName -Recurse -File | ForEach-Object {
            $rel = $_.FullName.Substring($s.FullName.Length).TrimStart('\')
            Write-Text (Join-Path $target $rel) (Read-Text $_.FullName)
        }
    }
    Write-Host "skill  /$($s.Name)"
}

foreach ($f in Get-ChildItem (Join-Path $root "scripts") -File -Filter "setup-labels.*") {
    Write-Text (Join-Path $kitHome "scripts\$($f.Name)") (Read-Text $f.FullName)
}

Write-Host ""
Write-Host "Installed for Claude Code (~/.claude) and omp (~/.omp/agent), prompts in ~/.shipkit."
Write-Host "In a repo, run once:  powershell -File ~/.shipkit/scripts/setup-labels.ps1"
Write-Host "Then start a feature: /feature <idea>   (omp: /skill:feature <idea>)"
