---
name: review-pr
description: QA-style review of one pull request against its ticket and SPEC.md scenarios by the Reviewer agent - reruns checks, scenario-ID traceability, test honesty, a mutation check - posting an APPROVE / REQUEST_CHANGES comment. Use to review any PR, including ones written by humans.
argument-hint: <PR number>
---

# /review-pr <n>

Spawn the **reviewer** agent on PR `<n>`. When it reports, show the user the verdict,
the mutation-check result and the findings, most severe first, with the link to the
review comment it posted.

The review is advice for the human, who decides whether to merge (gate 3).
