---
name: ship-tickets
description: Have the Ticket Writer split an approved (merged) spec change and its design into small GitHub issue tickets - epic, acceptance criteria, risk and size labels, dependency waves - for the user to approve. Use after a spec PR is merged, or to re-plan an epic.
argument-hint: <feature name or spec section>
---

# /ship-tickets — approved spec → small tickets

1. Check the spec change is merged (its scenarios are in `SPEC.md` on the default
   branch). If not, stop: the spec isn't approved yet.
2. Make sure the shipkit labels exist in the repo (see README, `setup-labels`).
3. Find the feature's design PR (`Design: <Feature>`, label `design`). If there is
   none, suggest `/ship-design` first. Continue without one only if the user says so.
4. Spawn the **ship-ticket-writer** agent with the feature's spec section and the
   design PR (its branch or diff if it isn't merged yet).
5. Show the user the epic link, the wave table and any questions.
6. **Gate 2:** ask the user to merge the design PR and approve the plan. Only when
   the design PR shows as merged (if there is one) **and** the user said "approved"
   in this conversation, relabel each of the epic's tickets from `status:proposed`
   to `status:ready`:
   `gh issue edit <n> --remove-label status:proposed --add-label status:ready`

Next step: `/ship-implement <n>` for a single ticket, or let `/ship-feature` build them.
