---
name: ship-design
description: Have the Tech Lead design how an approved (merged) spec change fits the code before tickets are written - caller-first interfaces, alternatives, invariants, test strategy, non-colliding work units - as a "Design - <Feature>" PR. Use after a spec PR is merged, or when the user wants a design/architecture pass on a feature.
argument-hint: <feature name or spec section>
---

# /ship-design — approved spec → design PR

1. Check the spec change is merged (its scenarios are in `SPEC.md` on the default
   branch). If not, stop: the spec isn't approved yet.
2. Spawn the **ship-tech-lead** agent with the feature's spec section.
3. When it reports, show the user the PR link, the chosen shape in two or three
   sentences, the invariants, the work-unit table and any open questions.
4. Answer open questions with the user, and send their answers back to the tech
   lead to update the PR. Never answer on the user's behalf.

The design PR is approved together with the ticket plan at **gate 2**: the user
merges the design PR and approves the tickets. Don't merge it yourself.

Next step: `/ship-tickets <feature>`. The ticket writer builds on the design PR, so it
doesn't need to be merged yet.
