#!/bin/sh
# Creates (or updates) the GitHub labels shipkit uses, in the current repo.
#   sh ~/.shipkit/scripts/setup-labels.sh [owner/repo]
set -eu
REPO=${1:+--repo $1}
label() { gh label create "$1" --color "$2" --description "$3" --force $REPO >/dev/null && echo "label  $1"; }
label "epic"               "5319e7" "A feature: links its tickets in waves"
label "ticket"             "1d76db" "One small, independently shippable change"
label "spec"               "0e8a16" "Spec change PR (merging = approval)"
label "design"             "0052cc" "Design PR (approved with the ticket plan at gate 2)"
label "env"                "006b75" "Development environment: tooling, checks, local setup"
label "security"           "b60205" "Security finding or hardening (from the security reviewer)"
label "debloat"            "fef2c0" "Removes code or agent context without changing behaviour"
label "status:proposed"    "d4c5f9" "Ticket written, waiting for plan approval"
label "status:ready"       "0e8a16" "Approved; can be picked up once dependencies close"
label "status:in-progress" "fbca04" "An implementer is working on it"
label "status:in-review"   "c5def5" "PR open, being reviewed"
label "status:blocked"     "b60205" "Needs a human decision (see latest comment)"
label "risk:low"           "c2e0c6" "Mechanical, well-specified: fine for a local/fast model"
label "risk:high"          "e99695" "Subtle (concurrency, security, OS, data): strongest model"
label "size:XS"            "ededed" "About 50 changed lines or fewer"
label "size:S"             "bfdadc" "About 200 changed lines or fewer"
