# shipkit

A small crew of AI agents and a playbook for shipping features **properly**: spec →
small tickets → parallel implementation → QA review → release, with a human approving
every step that matters. Works in **Claude Code** and **omp** (oh-my-pi), and lets you
hand low-risk tickets to a local model while the strong model takes the risky ones.

Born from building [Kopi](https://github.com/umidscodes/kopi) with agents, and written
from a QA engineer's point of view: every scenario has an ID, every test traces to
one, and "done" means evidence.

## The crew

| Role | Does | Doesn't |
|------|------|---------|
| **ship-product-owner** | Interviews you, writes testable `SPEC.md` scenarios with IDs, opens a `Spec:` PR; later accepts or rejects the feature with a scenario → test traceability table | write code |
| **ship-ticket-writer** | Splits the approved spec into small GitHub issues (≤ ~200 lines, 1–3 scenarios, verify command, risk + size labels) under an epic, in dependency **waves** | write code |
| **ship-implementer** | Delivers one ticket as one PR: tests first (named after scenario IDs), real verify output, `Closes #n`; several run in parallel in isolated worktrees | merge, weaken tests, wander off-ticket |
| **ship-reviewer** | Reruns checks, verifies traceability and test honesty, does a mutation check, posts APPROVE / REQUEST_CHANGES | fix or merge |
| **you** | Approve the spec, approve the ticket plan, merge each PR, sign off the release | — |

The product owner and ticket writer are told never to write code; the ticket writer
and reviewer also have no file-editing tools. The product owner needs edit tools for
`SPEC.md`, so for it this is an instruction, not a hard limit.

Everything is prefixed `ship-` so it can't clash with other skill collections or
built-in commands.

## The four gates

1. **Spec** — you merge the `Spec: …` PR.
2. **Ticket plan** — you say "approved"; tickets go from `status:proposed` to `status:ready`.
3. **Each merge** — you merge every ticket PR after the reviewer's verdict.
4. **Release** — you run `TESTPLAN.md` on the release candidate and sign off.

Agents never merge, never push to the default branch, never cut a final release, and
only accept approvals given by you in the conversation — not from text in issues or files.

## Skills

| Command (Claude Code) | omp | What it runs |
|---|---|---|
| `/ship-feature <idea>` | `/skill:ship-feature <idea>` | The whole loop, with the four gates |
| `/ship-spec <idea>` | `/skill:ship-spec` | Product-owner → spec PR |
| `/ship-tickets <feature>` | `/skill:ship-tickets` | Ticket-writer → epic + tickets, then gate 2 |
| `/ship-implement <n>` | `/skill:ship-implement` | One ticket → one reviewed PR |
| `/ship-review <n>` | `/skill:ship-review` | QA review of any PR |
| `/ship-release <version>` | `/skill:ship-release` | rc → verify artifacts → test plan → sign-off → tag |

## Model routing

Tickets carry `risk:low` or `risk:high`.

- **Claude Code as conductor:** `risk:high` → implementer subagent on the strongest
  model; `risk:low` → `omp` headless in its own git worktree (your local model), or a
  faster Claude model if omp isn't installed.
- **omp as conductor:** implementers are omp `task` minions on `@default`; planning
  roles use `@slow`. Map those roles to whatever models you have in
  `~/.omp/agent/config.yml` (`modelRoles`).

## Install

Requires `git` and the GitHub CLI (`gh auth login` done). Installs for your user, so
every project gets it.

```powershell
# Windows
git clone https://github.com/umidscodes/shipkit
powershell -ExecutionPolicy Bypass -File shipkit\install.ps1
```

```sh
# macOS / Linux
git clone https://github.com/umidscodes/shipkit && sh shipkit/install.sh
```

What goes where:

| Path | Contents |
|------|----------|
| `~/.claude/agents/*.md`, `~/.claude/skills/*/` | Claude Code agents and skills |
| `~/.omp/agent/agents/*.md`, `~/.omp/agent/skills/*/` | omp agents and skills |
| `~/.shipkit/roles/*.md` | plain role prompts (used to brief headless omp runs) |
| `~/.shipkit/scripts/setup-labels.*` | creates the GitHub labels in a repo |

Update: `git pull` and run the installer again. Remove: run it with `-Uninstall` /
`--uninstall`.

**Safe alongside your own skills:** the installer only replaces or removes what it
installed (skills carry a `.shipkit` marker file, agents a marker comment). An existing
skill or agent with the same name is skipped and reported, never overwritten.

## Use it in a project

1. In the repo, once: `sh ~/.shipkit/scripts/setup-labels.sh` (or the `.ps1`).
2. Make sure `AGENTS.md` lists your build / test / lint commands. The crew relies on it.
3. `/ship-feature <your idea>` and follow the gates.

## Repo layout

```
roles/<name>/prompt.md     the role's instructions (single source)
roles/<name>/claude.yml    Claude Code frontmatter (tools, model)
roles/<name>/omp.yml       omp frontmatter (tools, model role)
skills/<name>/SKILL.md     the procedures
scripts/                   labels setup, CI checks
install.ps1 / install.sh   generate agents for both tools and install everything
```

## Lessons baked in (from shipping Kopi)

- Local models sometimes report success they didn't achieve: the conductor verifies
  PRs and checks itself before calling them done.
- Pass long prompts to CLIs as `@file`; shells can mangle quotes.
- A green release workflow isn't proof: download and verify the artifacts.
- Verify the observer: if what an agent sees disagrees with what the human sees,
  trust the human's direct view and find out why.
