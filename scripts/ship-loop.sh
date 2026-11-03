#!/bin/sh
# Starts one /ship-loop iteration, but only when the checks that must never depend on
# an LLM's judgement pass. Run it from a scheduler (launchd/cron), as the bot's OS user.
#
#   sh ship-loop.sh <owner/repo> <repo folder>
#
# Settings come from a local file the crew can't edit (never from the repo):
#   ~/.shipkit/loop/<owner>_<repo>.conf   (or $SHIPKIT_LOOP_CONF)
#     owner=umidscodes         # the human; their actions are the only approvals
#     bot=umidscodes-bot       # the GitHub login this must run as
#     max_mode=dry-run         # ceiling: off | dry-run | auto
#     control_issue=48         # the pinned control issue (kill switch, digest)
#     hand_over=               # gates handed to the crew: any of "design merge"
#     minutes=45               # time limit for one iteration
#
# The repo's .shipkit/autonomy.yml (read from the default branch) can only lower the
# mode. Spec and release approval are never handed over.
#
# Before starting it checks, and refuses on any doubt:
#   - another iteration isn't running (atomic lock)
#   - gh is logged in as the bot, not as the owner
#   - the folder's origin is the repo
#   - the repo's .git config and hooks haven't changed since the last run
#   - the control issue is readable, open, and not labelled shipkit:stop
# Exit codes: 0 ran or nothing to do (stopped, off, already running), 1 the iteration
# failed, 2 stalled, 3 timed out, 4 refused (a check failed: the owner should look),
# 64 usage error.
set -u

[ $# -eq 2 ] || { echo "usage: ship-loop.sh <owner/repo> <repo folder>" >&2; exit 64; }
REPO=$1 DIR=$2
HERE=$(cd "$(dirname "$0")" && pwd)
NAME=$(printf '%s' "$REPO" | tr '/' '_')
CONF=${SHIPKIT_LOOP_CONF:-$HOME/.shipkit/loop/$NAME.conf}
STATE=${SHIPKIT_LOOP_STATE:-$HOME/.shipkit/loop/$NAME}
mkdir -p "$STATE"
LOG="$STATE/loop.log"

say() { echo "ship-loop: $*" | tee -a "$LOG" >&2; }
refuse() { say "refused: $*"; exit 4; }

conf() { # conf <key>: the value of key= in the settings file
	sed -n "s/^$1=//p" "$CONF" 2>/dev/null | head -1 | sed 's/[[:space:]]*#.*//; s/[[:space:]]*$//'
}
rank() { case "$1" in auto) echo 2 ;; dry-run) echo 1 ;; *) echo 0 ;; esac; }

[ -f "$CONF" ] || refuse "no settings file $CONF"
OWNER=$(conf owner) BOT=$(conf bot) MAX_MODE=$(conf max_mode) CONTROL=$(conf control_issue)
HAND_OVER=$(conf hand_over) MINUTES=$(conf minutes)
[ -n "$OWNER" ] && [ -n "$BOT" ] && [ -n "$CONTROL" ] || refuse "$CONF needs owner, bot and control_issue"
[ "$OWNER" != "$BOT" ] || refuse "owner and bot must be different accounts"
case "$CONTROL" in *[!0-9]* | "") refuse "control_issue must be an issue number" ;; esac
case "${MINUTES:=45}" in *[!0-9]* | "" | 0) refuse "minutes must be a positive number" ;; esac
for g in $HAND_OVER; do
	case "$g" in design | merge) ;; *) refuse "hand_over may only list design and merge, not '$g'" ;; esac
done

# One iteration at a time. mkdir is atomic; a lock older than twice the limit is stale.
LOCK="$STATE/lock"
if ! mkdir "$LOCK" 2>/dev/null; then
	if [ -n "$(find "$LOCK" -maxdepth 0 -mmin +$((MINUTES * 2)) 2>/dev/null)" ]; then
		rm -rf "$LOCK"
		mkdir "$LOCK" 2>/dev/null || { say "another iteration took the lock"; exit 0; }
		say "removed a stale lock"
	else
		say "another iteration is running"
		exit 0
	fi
fi
trap 'rm -rf "$LOCK"' EXIT
trap 'exit 130' INT TERM

login=$(gh api user --jq .login 2>/dev/null) || refuse "gh is not logged in"
[ "$login" = "$BOT" ] || refuse "gh is logged in as '$login', not the bot '$BOT'"

origin=$(git -C "$DIR" remote get-url origin 2>/dev/null) || refuse "$DIR is not a git checkout with an origin"
case "$origin" in
*"github.com/$REPO" | *"github.com/$REPO.git" | *"github.com:$REPO" | *"github.com:$REPO.git") ;;
*) refuse "$DIR's origin is $origin, not $REPO" ;;
esac

# Agent-written git config or hooks would run in the next git command on this host.
gitdir=$(git -C "$DIR" rev-parse --absolute-git-dir) || refuse "cannot find $DIR's .git"
gitprint() {
	{
		# branch.* entries are written by normal pushes and checkouts; they can't run code
		git config --file "$gitdir/config" --list | grep -v '^branch\.' | sort
		find "$gitdir/hooks" -type f ! -name '*.sample' 2>/dev/null | sort | while IFS= read -r h; do
			echo "$h"
			cat "$h"
		done
	} | cksum
}
now_print=$(gitprint)
if [ -f "$STATE/git-print" ]; then
	[ "$now_print" = "$(cat "$STATE/git-print")" ] ||
		refuse "$gitdir config or hooks changed since the last run; check them, then delete $STATE/git-print"
else
	echo "$now_print" >"$STATE/git-print"
fi

issue=$(gh api "repos/$REPO/issues/$CONTROL" --jq '"\(.state)\t\([.labels[].name] | join(","))"' 2>/dev/null) ||
	refuse "cannot read control issue #$CONTROL"
case "$(printf '%s' "$issue" | cut -f1)" in open) ;; *) refuse "control issue #$CONTROL is not open" ;; esac
case ",$(printf '%s' "$issue" | cut -f2)," in *,shipkit:stop,*)
	say "stopped: control issue #$CONTROL has shipkit:stop"
	exit 0 ;;
esac

repo_mode=$(gh api "repos/$REPO/contents/.shipkit/autonomy.yml" -H "Accept: application/vnd.github.raw" 2>/dev/null |
	sed -n 's/^mode:[[:space:]]*//p' | head -1 | sed 's/[[:space:]]*#.*//; s/["'\'']//g; s/[[:space:]]*$//')
mode=$MAX_MODE
[ "$(rank "$repo_mode")" -lt "$(rank "$mode")" ] && mode=$repo_mode
mode=$(case "$(rank "$mode")" in 2) echo auto ;; 1) echo dry-run ;; *) echo off ;; esac)
if [ "$mode" = off ]; then
	say "off (local ceiling '$MAX_MODE', repo '${repo_mode:-none}')"
	exit 0
fi

say "starting an iteration: mode $mode, hand_over '${HAND_OVER}'"
SHIPKIT_LOOP_MODE=$mode SHIPKIT_LOOP_OWNER=$OWNER SHIPKIT_LOOP_BOT=$BOT \
	SHIPKIT_LOOP_CONTROL=$CONTROL SHIPKIT_LOOP_HAND_OVER=$HAND_OVER \
	SHIPKIT_LOOP_GATE="$HERE/ship-gate.sh" \
	GIT_CONFIG_PARAMETERS="'core.hooksPath=/dev/null' 'core.fsmonitor=false'" \
	sh "$HERE/ship-watch.sh" --worktree "$DIR" --log "$LOG" \
	--max $((MINUTES * 60)) --stall $((MINUTES * 60)) --interval "${SHIPKIT_LOOP_INTERVAL:-30}" \
	-- ${SHIPKIT_CLAUDE:-claude} -p "/ship-loop $REPO"
code=$?
[ "$(gitprint)" = "$now_print" ] || say "warning: $gitdir config or hooks changed during this iteration"
exit $code
