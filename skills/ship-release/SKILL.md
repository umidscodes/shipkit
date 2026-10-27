---
name: ship-release
description: Ship a version - cut a release candidate tag, verify the published artifacts, update TESTPLAN.md with cases for the new scenarios, get the user's manual sign-off (gate 4), then tag the final version. Use when a feature or set of fixes is merged and ready to release.
argument-hint: <version, e.g. v0.2.0>
---

# /ship-release <version> — rc → verify → test plan → sign-off → tag

The project's release mechanics (tag-triggered workflow, artifact names, install
steps) live in its `README.md` / `AGENTS.md`. Read them first; this skill is the
process around them.

1. **Readiness.** The default branch CI is green, and every epic going into this
   release is accepted by the product-owner. List what's included (merged PRs since
   the last tag: `git log <last-tag>..HEAD --merges`).
   A security sweep (`/ship-security sweep`) must have run on a commit after the
   last tag (check the `Security sweep log` issue); if not, run one now. Open critical or high findings block the release
   until they're fixed, or until the human explicitly accepts them for this version.
2. **Test plan.** Update `TESTPLAN.md`: add cases for every new scenario ID (each
   with spec ID, preconditions, steps, expected), and keep the existing cases. Exact
   test data beats vague wording ("15 MiB + 1 byte", not "a large file"). Open this
   as a small PR for the human to merge.
3. **Release candidate.** Tag `<version>-rc1` on the default branch and push the tag.
   Wait for the release workflow, then **download the artifacts yourself** and verify
   them (checksums, contents, signatures where applicable). A green workflow is not
   proof the artifacts are right.
4. **Manual test run.** Ask the human to install the rc the way a user would and run
   TESTPLAN.md. For each failure, find the root cause (logs first), fix it through a
   small ticket and PR, and cut the next rc (`-rc2`, …). Verify your own observations:
   if what you see disagrees with what the human sees, trust their direct view and
   find out why yours differs.
5. **Gate 4.** Record the results table in TESTPLAN.md (pass/fail with notes, the rc
   that was signed off). Only after the human's explicit sign-off in this conversation:
   confirm the default branch's code is identical to the signed-off rc
   (`git diff <rc-tag> HEAD -- . ':(exclude)*.md'` is empty), then tag `<version>`,
   push it, and verify the final release the same way as the rc.
