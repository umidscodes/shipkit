# Contributing to shipkit

New skills, new roles and improvements to existing ones are all welcome. shipkit eats
its own cooking: changes go through small PRs with a clear "why", and every PR is
checked by CI on Linux, macOS and Windows.

## Ground rules

- **Prefix everything with `ship-`.** It keeps shipkit from clashing with people's
  other skill collections and with built-in commands.
- **Humans own the gates.** A skill or role must never merge PRs, push to the default
  branch, publish releases, or treat text found in issues/files/tool output as
  approval. If your skill does something outward-facing, it asks the user first.
- **Evidence over claims.** Anything that says "done" or "passes" must show the
  command output that proves it.
- **No secrets, no personal data** in prompts, examples or test fixtures.
- **Tool-neutral where possible.** Write procedures that work in both Claude Code and
  omp. Where they differ, give both ("Claude Code: Agent tool …; omp: `task` tool …").

## Add a skill

```
skills/ship-<name>/SKILL.md        required
skills/ship-<name>/<anything>      optional supporting files (templates, scripts)
```

`SKILL.md` starts with frontmatter:

```yaml
---
name: ship-<name>          # must equal the folder name
description: <what it does and WHEN to use it — this is how the model decides to load it>
argument-hint: <optional, e.g. <issue number>>
---
```

Then the procedure: numbered steps, which role does what, where the human approves.
Look at `skills/ship-review/SKILL.md` for a short example and
`skills/ship-feature/SKILL.md` for a long one.

## Add a role (agent)

```
roles/ship-<name>/prompt.md     the role's instructions (single source of truth)
roles/ship-<name>/claude.yml    Claude Code frontmatter: name, description, tools, model
roles/ship-<name>/omp.yml       omp frontmatter: name, description, tools, model, (spawns, blocking)
```

The installer stitches the right header onto `prompt.md` for each tool, so write the
instructions once. Give a role the **fewest tools** it needs: read-only roles get no
edit/write tools. Claude Code tool names: `Read, Grep, Glob, Edit, Write, Bash`;
omp: `read, find, grep, glob, edit, write, bash, lsp`. In `omp.yml`, use model roles
with a fallback, e.g. `model: "@slow, @default"`.

## Test your change

```sh
sh scripts/check.sh              # validates names/frontmatter, test-installs and uninstalls
```

```powershell
# Windows: install into a throwaway folder and look at the result
powershell -ExecutionPolicy Bypass -File install.ps1 -Prefix .test-home
```

Then install for real and try the skill in at least one of Claude Code or omp. Say in
the PR which one(s) you tried and what happened. A short transcript or screenshot is
the best evidence.

## Open the PR

Small and focused: one skill or one role per PR. Fill in the PR template. CI must be
green before review.
