#!/bin/sh
# Installs shipkit for your user so Claude Code and omp can use it in every project.
#   sh install.sh               # install / update
#   sh install.sh --uninstall   # remove
# PREFIX defaults to $HOME (tests set it to a temp dir).
set -eu
ROOT=$(cd "$(dirname "$0")" && pwd)
PREFIX=${PREFIX:-$HOME}
CLAUDE_AGENTS="$PREFIX/.claude/agents"
CLAUDE_SKILLS="$PREFIX/.claude/skills"
OMP_AGENTS="$PREFIX/.omp/agent/agents"
OMP_SKILLS="$PREFIX/.omp/agent/skills"
KIT="$PREFIX/.shipkit"

if [ "${1:-}" = "--uninstall" ]; then
	for r in "$ROOT"/roles/*/; do
		n=$(basename "$r")
		rm -f "$CLAUDE_AGENTS/$n.md" "$OMP_AGENTS/$n.md"
	done
	for s in "$ROOT"/skills/*/; do
		n=$(basename "$s")
		rm -rf "$CLAUDE_SKILLS/$n" "$OMP_SKILLS/$n"
	done
	rm -rf "$KIT"
	echo "shipkit removed."
	exit 0
fi

mkdir -p "$CLAUDE_AGENTS" "$CLAUDE_SKILLS" "$OMP_AGENTS" "$OMP_SKILLS" "$KIT/roles" "$KIT/scripts"

agent() { # agent <role dir> <header file> <dest dir>
	{
		echo "---"
		cat "$1/$2"
		echo "---"
		echo
		cat "$1/prompt.md"
	} | tr -d '\r' >"$3/$(basename "$1").md"
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
		rm -rf "${dest:?}/$n"
		cp -R "$s" "$dest/$n"
	done
	echo "skill  /$n"
done

cp "$ROOT"/scripts/setup-labels.* "$KIT/scripts/"
chmod +x "$KIT/scripts/setup-labels.sh"

echo
echo "Installed for Claude Code (~/.claude) and omp (~/.omp/agent), prompts in ~/.shipkit."
echo "In a repo, run once:  sh ~/.shipkit/scripts/setup-labels.sh"
echo "Then start a feature: /feature <idea>   (omp: /skill:feature <idea>)"
