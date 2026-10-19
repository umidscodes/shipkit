---
name: ship-spec
description: Have the Product Owner turn a feature idea into testable SPEC.md scenarios with IDs, interviewing the user first, and open a "Spec - <Feature>" PR for approval. Use when the user wants only the spec step of a feature.
argument-hint: <feature idea>
---

# /ship-spec — idea → scenarios → spec PR

Spawn the **ship-product-owner** agent with the user's idea and ask it to write the spec
change (see its instructions). Relay its interview questions to the user and the
answers back, verbatim.

When it reports, show the user the PR link and the new scenario IDs, and remind them
that **merging the PR is the approval** (gate 1). Don't merge it yourself.

Next step after the merge: `/ship-tickets <feature>`.
