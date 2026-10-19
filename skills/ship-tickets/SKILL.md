---
name: ship-tickets
description: Have the Ticket Writer split an approved (merged) spec change into small GitHub issue tickets - epic, acceptance criteria, risk and size labels, dependency waves - for the user to approve. Use after a spec PR is merged, or to re-plan an epic.
argument-hint: <feature name or spec section>
---

# /ship-tickets — approved spec → small tickets

1. Check the spec change is merged (its scenarios are in `SPEC.md` on the default
   branch). If not, stop: the spec isn't approved yet.
2. Make sure the shipkit labels exist in the repo (see README, `setup-labels`).
3. Spawn the **ship-ticket-writer** agent with the feature's spec section.
4. Show the user the epic link, the wave table and any questions.
5. **Gate 2:** ask the user to approve the plan. Only after an explicit "approved"
   in this conversation, relabel each of the epic's tickets from `status:proposed`
   to `status:ready`:
   `gh issue edit <n> --remove-label status:proposed --add-label status:ready`

Next step: `/ship-implement <n>` for a single ticket, or let `/ship-feature` build them.
