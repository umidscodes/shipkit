# Creates (or updates) the GitHub labels shipkit uses, in the current repo.
#   powershell -ExecutionPolicy Bypass -File ~/.shipkit/scripts/setup-labels.ps1 [-Repo owner/repo]
param([string]$Repo)
$labels = @(
    @("epic", "5319e7", "A feature: links its tickets in waves"),
    @("ticket", "1d76db", "One small, independently shippable change"),
    @("spec", "0e8a16", "Spec change PR (merging = approval)"),
    @("design", "0052cc", "Design PR (approved with the ticket plan at gate 2)"),
    @("env", "006b75", "Development environment: tooling, checks, local setup"),
    @("security", "b60205", "Security finding or hardening (from the security reviewer)"),
    @("debloat", "fef2c0", "Removes code or agent context without changing behaviour"),
    @("status:proposed", "d4c5f9", "Ticket written, waiting for plan approval"),
    @("status:ready", "0e8a16", "Approved; can be picked up once dependencies close"),
    @("status:in-progress", "fbca04", "An implementer is working on it"),
    @("status:in-review", "c5def5", "PR open, being reviewed"),
    @("status:blocked", "b60205", "Needs a human decision (see latest comment)"),
    @("risk:low", "c2e0c6", "Mechanical, well-specified: fine for a local/fast model"),
    @("risk:high", "e99695", "Subtle (concurrency, security, OS, data): strongest model"),
    @("size:XS", "ededed", "About 50 changed lines or fewer"),
    @("size:S", "bfdadc", "About 200 changed lines or fewer")
)
foreach ($l in $labels) {
    $ghArgs = @("label", "create", $l[0], "--color", $l[1], "--description", $l[2], "--force")
    if ($Repo) { $ghArgs += @("--repo", $Repo) }
    & gh @ghArgs | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Host "label  $($l[0])" } else { Write-Warning "failed: $($l[0])" }
}
