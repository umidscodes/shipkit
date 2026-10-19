#!/bin/sh
# Installs shipkit for your user so Claude Code and omp can use it in every project.
#   sh install.sh               # install / update
#   sh install.sh --uninstall   # remove
# PREFIX defaults to $HOME (tests set it to a temp dir).
#
# Safety: shipkit only ever replaces or removes files it installed itself. Skills get a
# .shipkit marker file, agents end with a marker comment. Anything else with the same
# name is left alone and reported.
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-$HOME}
CLAUDE_AGENTS="$PREFIX/.claude/agents"
CLAUDE_SKILLS="$PREFIX/.claude/skills"
OMP_AGENTS="$PREFIX/.omp/agent/agents"
OMP_SKILLS="$PREFIX/.omp/agent/skills"
KIT="$PREFIX/.shipkit"
MARK="<!-- installed by shipkit -->"
skipped=0

ours_agent() { [ ! -e "$1" ] || grep -qF "$MARK" "$1"; }  # missing or ours
ours_skill() { [ ! -e "$1" ] && [ ! -L "$1" ] || [ -f "$1/.shipkit" ]; }
skip() { echo "SKIP   $1 (exists and isn't shipkit's; left untouched)"; skipped=$((skipped + 1)); }

if [ "${1:-}" = "--uninstall" ]; then
	for r in "$ROOT"/roles/*/; do
		n=$(basename "$r")
		for f in "$CLAUDE_AGENTS/$n.md" "$OMP_AGENTS/$n.md"; do
			[ -e "$f" ] && grep -qF "$MARK" "$f" && rm -f "$f"
		done
	done
	for s in "$ROOT"/skills/*/; do
		n=$(basename "$s")
		for d in "$CLAUDE_SKILLS/$n" "$OMP_SKILLS/$n"; do
			[ -f "$d/.shipkit" ] && rm -rf "$d"
		done
	done
	rm -rf "$KIT"
	echo "shipkit removed (only files it installed)."
	exit 0
fi

mkdir -p "$CLAUDE_AGENTS" "$CLAUDE_SKILLS" "$OMP_AGENTS" "$OMP_SKILLS" "$KIT/roles" "$KIT/scripts"

agent() { # agent <role dir> <header file> <dest dir>
	out="$3/$(basename "$1").md"
	if ! ours_agent "$out"; then skip "$out"; return; fi
	{
		echo "---"
		cat "$1/$2"
		echo "---"
		echo
		cat "$1/prompt.md"
		echo
		echo "$MARK"
	} | tr -d '\r' >"$out"
}

for r in "$ROOT"/roles/*/; do
	r=${r%/}
	agent "$r" claude.yml "$CLAUDE_AGENTS"
	agent "$r" omp.yml "$OMP_AGENTS"
	tr -d '\r' <"$r/prompt.md" >"$KIT/roles/$(basename "$r").md"
	echo "agent  $(basename "$r")"
done

for s in "$ROOT"/skills/*/; do
	s=${s%/}
	n=$(basename "$s")
	for dest in "$CLAUDE_SKILLS" "$OMP_SKILLS"; do
		if ! ours_skill "$dest/$n"; then skip "$dest/$n"; continue; fi
		rm -rf "${dest:?}/$n"
		cp -R "$s" "$dest/$n"
		echo "installed by shipkit; safe to delete with install.sh --uninstall" >"$dest/$n/.shipkit"
	done
	echo "skill  /$n"
done

cp "$ROOT"/scripts/setup-labels.* "$KIT/scripts/"
chmod +x "$KIT/scripts/setup-labels.sh"

echo
[ "$skipped" -gt 0 ] && echo "Note: $skipped item(s) skipped to protect files shipkit didn't create."
echo "Installed for Claude Code (~/.claude) and omp (~/.omp/agent), prompts in ~/.shipkit."
echo "In a repo, run once:  sh ~/.shipkit/scripts/setup-labels.sh"
echo "Then start a feature: /ship-feature <idea>   (omp: /skill:ship-feature <idea>)"
