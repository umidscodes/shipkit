---
name: implement-ticket
description: Deliver one ready GitHub ticket as one small PR via an Implementer agent in an isolated worktree - tests first, real verify output, never weakens tests, never merges - then have the Reviewer check it. Use to build a single ticket.
argument-hint: <issue number>
---

# /implement-ticket <n> — one ticket → one reviewed PR

1. `gh issue view <n>`: it must be labelled `ticket` and `status:ready`, and every
   issue in its "Depends on" must be closed. Otherwise stop and say why.
2. Pick who implements by its risk label (same routing as `/feature` phase 3):
   `risk:high` → the **implementer** agent on the strongest model, isolated worktree;
   `risk:low` → omp headless if available, else the implementer agent.
3. When the implementer reports, verify it yourself: the PR exists, it says
   `Closes #<n>`, and the project's checks pass on its branch.
4. Spawn the **reviewer** agent on the PR and show the user its verdict.
5. **Gate 3:** if the verdict is APPROVE, tell the user it's ready to merge. Never
   merge it yourself. On REQUEST_CHANGES, run a fix round (max 2), then ask the user.
