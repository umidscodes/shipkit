---
name: ship-review
description: QA and code-design review of one pull request against its ticket, SPEC.md scenarios and the feature's design by the Reviewer agent - reruns checks, scenario-ID traceability, test honesty, a mutation check, invariants, interfaces, simplicity - posting an APPROVE / REQUEST_CHANGES comment. Use to review any PR, including ones written by humans.
argument-hint: <PR number>
---

# /ship-review <n>

Spawn the **ship-reviewer** agent on PR `<n>`. When it reports, show the user the verdict,
the mutation-check result, whether the PR follows the design, and the findings, most severe first, with the link to the
review comment it posted.

The review is advice for the human, who decides whether to merge (gate 3).

For a PR that touches the attack surface, also run `/ship-security <n>`. For a large
PR (over about 150 changed lines), also run `/ship-debloat <n>`.
