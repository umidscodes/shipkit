---
name: ship-debloat
description: Find what can be deleted, via the Debloater agent - either one pull request (Debloat LEAN / TRIM: what it adds beyond its ticket) or an audit of code and agent context (AGENTS.md, CLAUDE.md, design docs, skills) for dead code, duplication, needless abstractions and stale rules, filing small debloat tickets for the crew. Use after an epic, on a large PR, or whenever the codebase or agent docs feel heavy.
argument-hint: <PR number> | audit [since <tag> | all]
---

# /ship-debloat <PR number | audit [since <tag> | all]>

## `/ship-debloat <n>` — one pull request

Spawn the **ship-debloater** agent in PR mode on PR `<n>`. Show the user the verdict
and the cuts, biggest first, with the link to its comment.

During `/ship-feature` this runs automatically on PRs over about 150 changed lines.
`TRIM` counts like `REQUEST_CHANGES`: its cuts go into the same fix round as the
reviewer's findings, and the two-rounds-then-ask-the-human limit covers both.

## `/ship-debloat audit` — code and agent context

Spawn the **ship-debloater** agent in audit mode:

- `audit` (default): what changed since the last tag (`git describe --tags --abbrev=0`).
- `audit since <tag>`: since that tag.
- `audit all`: the whole repo.

When it reports, show the user the ticket table (at most 8 tickets, ranked) and the
"looked at and kept" list. Debloat tickets are `status:proposed` like any other: they
become `status:ready` only when the human approves them. Most are `risk:low`, so
they're good candidates for the local model.

`/ship-feature` runs `audit since <last tag>` after the product owner accepts an epic.
The tickets go into the next cycle; they never block the release.
