#!/bin/sh
# Tests ship-loop.sh (the wrapper's refusals) and ship-gate.sh (the merge gate) with a
# fake gh and a fake claude. Used by check.sh.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
TMP=$(mktemp -d)
BIN="$TMP/bin"
mkdir -p "$BIN"

# A fake gh: answers the few API calls the scripts make from FAKE_* variables.
cat >"$BIN/gh" <<'EOF'
#!/bin/sh
[ -n "${FAKE_FAIL:-}" ] && case "$*" in *"$FAKE_FAIL"*) exit 1 ;; esac
case "$*" in
"api user"*) echo "$FAKE_LOGIN" ;;
*"/issues/"*) printf '%s\n' "$FAKE_ISSUE" ;;
*"contents/.shipkit/autonomy.yml"*) [ -n "${FAKE_AUTONOMY:-}" ] || exit 1; printf '%s\n' "$FAKE_AUTONOMY" ;;
*"contents/AGENTS.md"*) printf '%s\n' "${FAKE_AGENTS:-}" ;;
*"/pulls/"*"/files"*) printf '%s\n' "$FAKE_FILES" ;;
*"/pulls/"*) printf '%s\n' "$FAKE_PR" ;;
*"/rules/branches/"*) printf '%s\n' "$FAKE_REQUIRED" ;;
*"/check-runs"*) printf '%s\n' "$FAKE_CHECKS" ;;
*"/status"*) printf '%s\n' "$FAKE_STATUSES" ;;
"api repos/"*) echo main ;;
*) echo "fake gh: unexpected: $*" >&2; exit 1 ;;
esac
EOF
# A fake claude: records that it ran, and with which mode.
cat >"$BIN/claude" <<'EOF'
#!/bin/sh
echo "ran mode=$SHIPKIT_LOOP_MODE hand_over=$SHIPKIT_LOOP_HAND_OVER" >>"$FAKE_RAN"
EOF
chmod +x "$BIN/gh" "$BIN/claude"
export PATH="$BIN:$PATH"

pass() { echo "ok    $1"; }
bad() { echo "FAIL: $1"; fail=1; }

# ---------- ship-loop.sh ----------
REPO_DIR="$TMP/repo"
git init -q "$REPO_DIR"
git -C "$REPO_DIR" remote add origin https://github.com/o/r.git
export SHIPKIT_LOOP_CONF="$TMP/loop.conf" SHIPKIT_LOOP_STATE="$TMP/state" SHIPKIT_LOOP_INTERVAL=1
export FAKE_RAN="$TMP/ran"

setup() { # fresh settings, state and fakes for each case
	rm -rf "$TMP/state" "$FAKE_RAN"
	printf 'owner=me\nbot=me-bot\nmax_mode=dry-run\ncontrol_issue=7\nhand_over=design merge\nminutes=1\n' >"$SHIPKIT_LOOP_CONF"
	export FAKE_LOGIN=me-bot FAKE_ISSUE="open	shipkit:control" FAKE_AUTONOMY="mode: auto" FAKE_FAIL=""
}
loop() { # loop <name> <want exit> <want "ran" or "not run"> [want mode]
	sh "$ROOT/scripts/ship-loop.sh" o/r "$REPO_DIR" 2>/dev/null
	got=$?
	if [ -f "$FAKE_RAN" ]; then ran=ran; else ran="not run"; fi
	if [ "$got" != "$2" ] || [ "$ran" != "$3" ]; then
		bad "loop: $1 (exit $got, $ran; want exit $2, $3)"
	elif [ -n "${4:-}" ] && ! grep -q "mode=$4 " "$FAKE_RAN"; then
		bad "loop: $1 (ran with $(cat "$FAKE_RAN"), want mode $4)"
	else
		pass "loop: $1"
	fi
}

setup; loop "runs with the stricter of local and repo mode" 0 ran dry-run
setup; export FAKE_AUTONOMY=""; loop "no autonomy file means off" 0 "not run"
setup; export FAKE_AUTONOMY="mode: off"; loop "repo mode off" 0 "not run"
setup; sed -i.bak 's/max_mode=dry-run/max_mode=auto/' "$SHIPKIT_LOOP_CONF"; loop "auto only when both allow it" 0 ran auto
setup; export FAKE_AUTONOMY="mode: banana"; loop "unknown mode means off" 0 "not run"
setup; export FAKE_LOGIN=me; loop "refuses to run as the owner" 4 "not run"
setup; export FAKE_FAIL="api user"; loop "refuses when gh isn't logged in" 4 "not run"
setup; export FAKE_ISSUE="open	shipkit:control,shipkit:stop"; loop "kill switch stops it" 0 "not run"
setup; export FAKE_FAIL="/issues/"; loop "unreadable control issue refuses" 4 "not run"
setup; export FAKE_ISSUE="closed	shipkit:control"; loop "closed control issue refuses" 4 "not run"
setup; printf 'owner=me\nbot=me\ncontrol_issue=7\n' >"$SHIPKIT_LOOP_CONF"; loop "owner and bot must differ" 4 "not run"
setup; printf 'owner=me\nbot=me-bot\ncontrol_issue=7\nhand_over=spec\n' >"$SHIPKIT_LOOP_CONF"; loop "spec can't be handed over" 4 "not run"
setup; rm -f "$SHIPKIT_LOOP_CONF"; loop "no settings file refuses" 4 "not run"
setup; mkdir -p "$TMP/state/lock"; loop "a fresh lock means another run" 0 "not run"
setup; git -C "$REPO_DIR" remote set-url origin https://github.com/o/other.git; loop "wrong origin refuses" 4 "not run"
git -C "$REPO_DIR" remote set-url origin https://github.com/o/r.git
setup; loop "first run records the .git fingerprint" 0 ran
rm -f "$FAKE_RAN"; git -C "$REPO_DIR" config core.fsmonitor "echo planted"
loop "changed .git config refuses the next run" 4 "not run"
git -C "$REPO_DIR" config --unset core.fsmonitor
rm -f "$FAKE_RAN"; git -C "$REPO_DIR" config branch.t1-x.remote origin
loop "branch entries from pushes don't count" 0 ran

# ---------- ship-gate.sh ----------
SHA=0123456789abcdef0123456789abcdef01234567
gsetup() {
	export FAKE_PR="me-bot	o/r	o/r	$SHA	open	main	ticket"
	export FAKE_FILES="internal/x.go"
	export FAKE_AGENTS=""
	export FAKE_REQUIRED="test (macos-latest)"
	export FAKE_CHECKS="test (macos-latest)	success"
	export FAKE_STATUSES="shipkit/review	success"
	export FAKE_FAIL=""
}
gate() { # gate <name> <want exit>
	out=$(sh "$ROOT/scripts/ship-gate.sh" o/r 5 "$SHA" me-bot 2>&1)
	got=$?
	if [ "$got" = "$2" ]; then pass "gate: $1"; else bad "gate: $1 (exit $got: $out; want $2)"; fi
}

gsetup; gate "a reviewed crew PR with green checks may merge" 0
gsetup; FAKE_PR="stranger	o/r	o/r	$SHA	open	main	ticket"; gate "a PR the crew didn't open is held" 1
gsetup; FAKE_PR="me-bot	fork/r	o/r	$SHA	open	main	ticket"; gate "a fork PR is held" 1
gsetup; FAKE_PR="me-bot	o/r	o/r	ffff456789abcdef0123456789abcdef01234567	open	main	ticket"; gate "a moved head is held" 1
gsetup; FAKE_PR="me-bot	o/r	o/r	$SHA	open	main	ticket,shipkit:held"; gate "a held label holds" 1
gsetup; FAKE_FILES=".github/workflows/ci.yml"; gate "a workflow change is held" 1
gsetup; FAKE_FILES="internal/x.go
.GitHub/x.yml"; gate "protected paths match case-insensitively" 1
gsetup; FAKE_FILES="AGENTS.md"; gate "AGENTS.md is held" 1
gsetup; FAKE_FILES="scripts/check.sh"; gate "the check script is held" 1
gsetup; FAKE_FILES="go.sum"; gate "dependency changes are held" 1
gsetup; FAKE_FILES="internal/crypto/key.go"; FAKE_AGENTS="# A
## Protected paths
- \`internal/crypto/*\` (keys)
## Other
- \`internal/*\`"; gate "AGENTS.md protected paths are held" 1
gsetup; FAKE_FILES="cmd/x.go"; FAKE_AGENTS="## Protected paths
- \`internal/crypto/*\`"; gate "paths outside the AGENTS.md list pass" 0
gsetup; FAKE_REQUIRED=""; gate "no required checks is held" 1
gsetup; FAKE_CHECKS="test (macos-latest)	failure"; gate "a failed check is held" 1
gsetup; FAKE_CHECKS="test (macos-latest)	in_progress"; gate "a running check waits" 3
gsetup; FAKE_CHECKS=""; gate "a required check that hasn't started waits" 3
gsetup; FAKE_STATUSES=""; gate "no review status is held" 1
gsetup; FAKE_STATUSES="shipkit/review	failure"; gate "a failed review status is held" 1
gsetup; FAKE_FAIL="/files"; gate "unreadable files is an error" 2
gsetup; out=$(sh "$ROOT/scripts/ship-gate.sh" o/r 5 abc me-bot 2>&1); [ $? = 2 ] && pass "gate: a short sha is refused" || bad "gate: a short sha is refused"

rm -rf "$TMP"
exit $fail
