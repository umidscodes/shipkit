#!/bin/sh
# The mechanical merge gate for /ship-loop: decides whether a crew PR may be merged
# at a given commit, by checks a prompt can't talk its way around.
#
#   sh ship-gate.sh <owner/repo> <pr number> <reviewed sha> <bot login>
#
# Merge only when it prints "OK" and exits 0. Then merge with
# `gh pr merge <n> --merge --match-head-commit <reviewed sha>` (never --admin or --auto).
#
# Exit codes: 0 OK (may merge), 1 HOLD (owner decides; the reason is printed),
# 3 WAIT (checks still running; try again later), 2 error (treat as HOLD), 64 usage.
set -u
set -f # patterns below are matched with case, never expanded against files

[ $# -eq 4 ] || { echo "usage: ship-gate.sh <owner/repo> <pr> <reviewed sha> <bot login>" >&2; exit 64; }
REPO=$1 PR=$2 SHA=$3 BOT=$4

hold() { echo "HOLD: $*"; exit 1; }
wait_() { echo "WAIT: $*"; exit 3; }
err() { echo "ERROR: $*"; exit 2; }

case "$SHA" in
*[!0-9a-f]* | "") err "reviewed sha must be a full lowercase hex sha" ;;
esac
[ ${#SHA} -eq 40 ] || err "reviewed sha must be 40 characters"

# Statuses the crew's own reviews set on the reviewed commit. Each must be "success".
REVIEW_CONTEXTS=${SHIPKIT_REVIEW_CONTEXTS:-shipkit/review}

# 1. Who opened it, from where, and what its head is now.
pr=$(gh api "repos/$REPO/pulls/$PR" --jq '[.user.login, (.head.repo.full_name // "" | tostring), .base.repo.full_name, .head.sha, .state, .base.ref, ([.labels[].name] | join(","))] | @tsv') ||
	err "cannot read PR #$PR"
author=$(printf '%s' "$pr" | cut -f1)
head_repo=$(printf '%s' "$pr" | cut -f2)
base_repo=$(printf '%s' "$pr" | cut -f3)
head=$(printf '%s' "$pr" | cut -f4)
state=$(printf '%s' "$pr" | cut -f5)
base=$(printf '%s' "$pr" | cut -f6)
labels=$(printf '%s' "$pr" | cut -f7)

[ "$state" = open ] || hold "PR #$PR is $state"
[ "$author" = "$BOT" ] || hold "PR #$PR was opened by $author, not the crew ($BOT)"
[ "$head_repo" = "$base_repo" ] || hold "PR #$PR comes from another repository ($head_repo)"
[ "$head" = "$SHA" ] || hold "PR #$PR head is $head, not the reviewed commit $SHA"
case ",$labels," in *,shipkit:held,*) hold "PR #$PR carries shipkit:held" ;; esac

default=$(gh api "repos/$REPO" --jq .default_branch) || err "cannot read the default branch"
[ "$base" = "$default" ] || hold "PR #$PR targets $base, not $default"

# 2. Protected paths. A fixed list, plus the project's own list in AGENTS.md.
#    Matching is case-insensitive (macOS file systems are), and renames count both names.
extra=$(gh api "repos/$REPO/contents/AGENTS.md?ref=$default" -H "Accept: application/vnd.github.raw" 2>/dev/null |
	awk '/^## /{on = ($0 ~ /^## Protected paths/)} on && /^- `/{sub(/^- `/, ""); sub(/`.*/, ""); print}' |
	tr 'A-Z' 'a-z')
files=$(gh api "repos/$REPO/pulls/$PR/files" --paginate --jq '.[] | .filename, (.previous_filename // empty)') ||
	err "cannot list the files of PR #$PR"
[ -n "$files" ] || hold "PR #$PR changes no files"

protected=""
for f in $(printf '%s\n' "$files" | tr 'A-Z' 'a-z'); do
	case "$f" in
	.github/* | .shipkit/* | codeowners | */codeowners | agents.md | claude.md | .claude/* | .omp/* | .mcp.json | \
		scripts/check.* | spec.md | roadmap.md | testplan.md | \
		go.mod | go.sum | package.json | package-lock.json | npm-shrinkwrap.json | pnpm-lock.yaml | yarn.lock | \
		requirements*.txt | poetry.lock | pyproject.toml | cargo.toml | cargo.lock)
		protected="$protected $f" ;;
	*)
		for pat in $extra; do
			# shellcheck disable=SC2254 # the pattern is meant to glob
			case "$f" in $pat) protected="$protected $f" ;; esac
		done ;;
	esac
done
[ -z "$protected" ] || hold "protected paths changed:$protected"

# 3. Required checks: the branch rules must name some, and each must have passed on
#    this exact commit. "Whatever ran is green" is not a gate.
required=$(gh api "repos/$REPO/rules/branches/$default" --jq '.[] | select(.type == "required_status_checks") | .parameters.required_status_checks[].context') ||
	err "cannot read the branch rules"
[ -n "$required" ] || hold "the default branch has no required status checks"

results=$( {
	gh api "repos/$REPO/commits/$SHA/check-runs" --paginate --jq '.check_runs[] | "\(.name)\t\(.conclusion // .status)"'
	gh api "repos/$REPO/commits/$SHA/status" --jq '.statuses[] | "\(.context)\t\(.state)"'
} ) || err "cannot read checks for $SHA"

need=$(printf '%s\n%s\n' "$required" "$(printf '%s\n' $REVIEW_CONTEXTS)")
pending=""
printf '%s\n' "$need" | while IFS= read -r ctx; do
	[ -n "$ctx" ] || continue
	got=$(printf '%s\n' "$results" | awk -F '\t' -v c="$ctx" '$1 == c {print $2}' | tail -1)
	echo "$ctx	${got:-missing}"
done >"${TMPDIR:-/tmp}/ship-gate.$$"
while IFS='	' read -r ctx got; do
	case "$got" in
	success) ;;
	queued | in_progress | pending | waiting | requested) pending="$pending $ctx" ;;
	missing) case " $REVIEW_CONTEXTS " in *" $ctx "*) rm -f "${TMPDIR:-/tmp}/ship-gate.$$"; hold "no $ctx status on $SHA" ;; *) pending="$pending $ctx" ;; esac ;;
	*) rm -f "${TMPDIR:-/tmp}/ship-gate.$$"; hold "$ctx is $got on $SHA" ;;
	esac
done <"${TMPDIR:-/tmp}/ship-gate.$$"
rm -f "${TMPDIR:-/tmp}/ship-gate.$$"
[ -z "$pending" ] || wait_ "still running on $SHA:$pending"

echo "OK: PR #$PR may merge at $SHA"
exit 0
