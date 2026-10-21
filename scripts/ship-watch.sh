#!/bin/sh
# Runs an agent command (e.g. headless omp) in a git worktree and stops it when it
# stalls or runs too long, so a looping local model can't burn hours unnoticed.
#
#   sh ship-watch.sh --worktree DIR [--log FILE] [--max SECONDS] [--stall SECONDS]
#                    [--interval SECONDS] -- command [args...]
#
# Progress = the worktree's content changes: a new commit, or a different set of
# changes (tracked diff plus untracked files' contents). Rewriting the same content
# over and over is NOT progress, which is how agent loops usually look from outside.
#
# Exit codes: 0 command succeeded, 1 command failed, 2 stalled (no progress for
# --stall seconds), 3 timed out (--max seconds), 64 usage error.
# The last line of the log is a summary: "ship-watch: <result> after <n>s".
set -u

usage() { echo "usage: ship-watch.sh --worktree DIR [--log FILE] [--max S] [--stall S] [--interval S] -- cmd..." >&2; exit 64; }

WT="" LOG="" MAX=2400 STALL=900 INTERVAL=30
while [ $# -gt 0 ]; do
	case "$1" in
	--worktree) WT=$2; shift 2 ;;
	--log) LOG=$2; shift 2 ;;
	--max) MAX=$2; shift 2 ;;
	--stall) STALL=$2; shift 2 ;;
	--interval) INTERVAL=$2; shift 2 ;;
	--) shift; break ;;
	*) usage ;;
	esac
done
[ -n "$WT" ] && [ $# -gt 0 ] || usage
git -C "$WT" rev-parse --git-dir >/dev/null 2>&1 || { echo "ship-watch: $WT is not a git worktree" >&2; exit 64; }
[ -n "$LOG" ] || LOG="$WT.watch.log"

fingerprint() {
	{
		git -C "$WT" rev-parse HEAD 2>/dev/null
		git -C "$WT" diff HEAD 2>/dev/null
		git -C "$WT" ls-files --others --exclude-standard 2>/dev/null | while IFS= read -r f; do
			echo "$f"; cat "$WT/$f" 2>/dev/null
		done
	} | cksum
}

finish() { # finish <exit code> <result word>
	echo "ship-watch: $2 after ${elapsed}s" | tee -a "$LOG" >&2
	exit "$1"
}

stop_cmd() {
	kill "$pid" 2>/dev/null
	sleep 2
	kill -9 "$pid" 2>/dev/null
	wait "$pid" 2>/dev/null
}

"$@" >>"$LOG" 2>&1 &
pid=$!
start=$(date +%s)
last=$(fingerprint)
last_change=$start
elapsed=0

while :; do
	sleep "$INTERVAL"
	now=$(date +%s)
	elapsed=$((now - start))
	if ! kill -0 "$pid" 2>/dev/null; then
		wait "$pid"
		code=$?
		[ "$code" = 0 ] && finish 0 "finished" || finish 1 "command failed (exit $code)"
	fi
	fp=$(fingerprint)
	if [ "$fp" != "$last" ]; then
		last=$fp
		last_change=$now
	fi
	if [ "$elapsed" -ge "$MAX" ]; then
		stop_cmd
		finish 3 "timed out (limit ${MAX}s)"
	fi
	if [ $((now - last_change)) -ge "$STALL" ]; then
		stop_cmd
		finish 2 "stalled (no new changes for ${STALL}s)"
	fi
done
