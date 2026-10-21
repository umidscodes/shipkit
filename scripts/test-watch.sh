#!/bin/sh
# Tests ship-watch.sh with tiny limits. Used by check.sh.
set -u
ROOT=$(cd "$(dirname "$0")/.." && pwd)
W="$ROOT/scripts/ship-watch.sh"
fail=0
TMP=$(mktemp -d)
git -C "$TMP" init -q
git -C "$TMP" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

expect() { # expect <name> <want exit> -- watch args...
	name=$1 want=$2; shift 3
	sh "$W" --worktree "$TMP" --log "$TMP/../watch-$$.log" --interval 1 "$@" 2>/dev/null
	got=$?
	if [ "$got" = "$want" ]; then echo "ok    watch: $name"; else echo "FAIL: watch: $name exited $got, want $want"; fail=1; fi
}

expect "succeeding command" 0 -- --stall 5 --max 20 -- sh -c 'echo a > "$0/f"; sleep 2' "$TMP"
expect "failing command" 1 -- --stall 5 --max 20 -- sh -c 'exit 7'
expect "idle command stalls" 2 -- --stall 3 --max 30 -- sleep 30
expect "rewriting the same content is a stall" 2 -- --stall 3 --max 30 -- \
	sh -c 'while :; do echo same > "$0/loop"; sleep 1; done' "$TMP"
expect "steady progress runs until the time limit" 3 -- --stall 3 --max 5 -- \
	sh -c 'i=0; while :; do i=$((i+1)); echo $i > "$0/count"; sleep 1; done' "$TMP"
grep -q "ship-watch: timed out" "$TMP/../watch-$$.log" || { echo "FAIL: watch: log has no summary line"; fail=1; }

rm -rf "$TMP" "$TMP/../watch-$$.log"
exit $fail
