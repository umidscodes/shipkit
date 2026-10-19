#!/bin/sh
# Validates the kit and test-installs it into a temp home. Used by CI.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
fail=0
err() { echo "FAIL: $*"; fail=1; }

field() { # field <file> <key>: value of "key:" in the file's frontmatter/header
	sed -n "s/^$2:[[:space:]]*//p" "$1" | head -1
}

for r in "$ROOT"/roles/*/; do
	n=$(basename "$r")
	for f in prompt.md claude.yml omp.yml; do
		[ -s "$r/$f" ] || err "role $n: missing $f"
	done
	for h in claude.yml omp.yml; do
		[ "$(field "$r/$h" name)" = "$n" ] || err "role $n: $h name must be '$n'"
		[ -n "$(field "$r/$h" description)" ] || err "role $n: $h needs a description"
	done
done

for s in "$ROOT"/skills/*/; do
	n=$(basename "$s")
	f="$s/SKILL.md"
	[ -s "$f" ] || { err "skill $n: missing SKILL.md"; continue; }
	[ "$(head -1 "$f")" = "---" ] || err "skill $n: SKILL.md must start with frontmatter"
	[ "$(field "$f" name)" = "$n" ] || err "skill $n: frontmatter name must be '$n'"
	[ -n "$(field "$f" description)" ] || err "skill $n: needs a description"
done

# Every agent a skill mentions must exist.
for a in $(grep -ohE '\*\*(product-owner|ticket-writer|implementer|reviewer)\*\*' "$ROOT"/skills/*/SKILL.md | tr -d '*' | sort -u); do
	[ -d "$ROOT/roles/$a" ] || err "skills mention agent '$a' but roles/$a doesn't exist"
done

TMP=$(mktemp -d)
PREFIX="$TMP" sh "$ROOT/install.sh" >/dev/null
for r in "$ROOT"/roles/*/; do
	n=$(basename "$r")
	for out in "$TMP/.claude/agents/$n.md" "$TMP/.omp/agent/agents/$n.md" "$TMP/.shipkit/roles/$n.md"; do
		[ -s "$out" ] || err "install: missing $out"
	done
	[ "$(head -1 "$TMP/.claude/agents/$n.md")" = "---" ] || err "install: $n agent lacks frontmatter"
done
for s in "$ROOT"/skills/*/; do
	n=$(basename "$s")
	[ -s "$TMP/.claude/skills/$n/SKILL.md" ] || err "install: missing claude skill $n"
	[ -s "$TMP/.omp/agent/skills/$n/SKILL.md" ] || err "install: missing omp skill $n"
done
PREFIX="$TMP" sh "$ROOT/install.sh" --uninstall >/dev/null
[ -z "$(find "$TMP" -type f)" ] || err "uninstall left files: $(find "$TMP" -type f | head -3)"
rm -rf "$TMP"

[ $fail = 0 ] && echo "shipkit check: OK"
exit $fail
