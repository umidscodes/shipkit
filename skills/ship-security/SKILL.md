---
name: ship-security
description: Security review by the Security Reviewer agent - either one pull request (blocking Security APPROVE / REQUEST_CHANGES, for PRs touching network, crypto, secrets, external input, dependencies or CI) or a whole-repo sweep with scanners (gitleaks, govulncheck, gosec, npm audit, pip-audit) that files tickets or private security advisories. Use for a security check of a PR, a periodic sweep, or to set up the weekly sweep routine.
argument-hint: <PR number> | sweep | schedule
---

# /ship-security <PR number | sweep | schedule>

## `/ship-security <n>` — one pull request

Spawn the **ship-security-reviewer** agent in PR mode on PR `<n>`. When it reports,
show the user the verdict, the scanners that ran (and those that weren't installed),
and the findings, most severe first, with the link to its comment.

A critical or high finding blocks the merge (gate 3) until it's fixed, or until the
human explicitly accepts the risk in this conversation. If they accept it, comment on
the PR with their decision, in their words. Medium and low findings that the PR doesn't
fix become `security` tickets.

## `/ship-security sweep` — the whole repository

Spawn the **ship-security-reviewer** agent in sweep mode on the default branch. Show
the user its table. For critical or high findings in a public repo, the details are in
a draft security advisory (only maintainers can see it) or only in the agent's report.
Never paste them into a public issue, PR or commit message. Ask the human how to
handle each one: a fix ticket written without exploit details, or a fix done privately
first.

## `/ship-security schedule` — the weekly sweep

The weekly sweep is a Claude Code routine (`/schedule`), so no machine of yours has to
be on. Routines run in a cloud sandbox where your installed shipkit skills aren't
available, so the routine reads the role from the shipkit repo directly. Help the
human create it with `/schedule`:

- **When:** weekly, at a quiet time (for example Monday 09:00 local).
- **Repository:** this repo.
- **Prompt:**
  ```
  Clone https://github.com/umidscodes/shipkit into a temporary directory and read
  roles/ship-security-reviewer/prompt.md. Act as that Security Reviewer in sweep
  mode on this repository's default branch. You may install the scanners it lists
  inside this sandbox. File results exactly as the role says: critical or high
  findings only as draft security advisories, never as public issues. End with the
  results table.
  ```

After creating it, run it once by hand and check its output: GitHub access works,
the scanners ran, and nothing sensitive went into a public issue. Then let it run
weekly.

## Which PRs get a security review

During `/ship-feature` the conductor runs this on every PR that:

- is labelled `risk:high` or `security`, or
- changes the attack surface: network or transport code, crypto, keys or passphrases,
  parsing of input from outside (network, files, clipboard, env), process execution,
  file paths built from input, dependency manifests (`go.mod`, `package.json`,
  `requirements*.txt`, lockfiles), CI workflows, or release configuration, or
- touches a path listed under `## Security` in the project's `AGENTS.md`.
