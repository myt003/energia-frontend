# EN-STF-003 validation — Daily compliance-verification checks

## Build under review

- App version: **0.3.0+4**
- Story: **EN-STF-003**
- Platform: Android APK
- Data mode: deterministic seeded published rules and task instances

Install over `0.2.0+3`. Existing work profile, custom activities, official
equipment assignments, and pending asset candidates should remain available.

## Palette check

The entire build now follows the requested 60 / 30 / 10 system:

| Usage | Color | Hex |
| --- | --- | --- |
| 60% dominant backgrounds/surfaces | Charcoal | `#1E1E1C` |
| 30% typography/supporting treatment | Sand | `#D8CBB3` |
| 10% actions/selections/focus | Electric blue | `#2F6BFF` |

Confirm no previous purple, green, amber, or red accent remains. Due, completed,
overdue, and review states must still be understandable from labels and icons.

## Seeded matching setup

Four department/role/shift checks always demonstrate the list states:

- **Due:** department shift energy walk
- **Completed:** recorded start-up condition
- **Overdue:** previous-shift shutdown exception
- **Waiting for review:** standby-control evidence

Verified equipment assignments add machine-specific due tasks. Assigning
**Heat sealer HS-03** also adds an urgent power-anomaly task.

## Main validation workflow

1. Install and open Energia. The app should now start on **Today**.
2. Confirm the header uses the employee name, current date, shift, department,
   and assigned-machine count.
3. Verify the four summary controls clearly separate **Due**, **Done**,
   **Late**, and **Review**, each with a count.
4. Open each state and verify only its matching checks are displayed:
   - **Due this shift**
   - **Completed today**
   - **Needs attention**
   - **Submitted evidence**
5. Pull down to refresh and confirm the list returns without losing state.
6. Use the bottom navigation to open **Work profile**, confirm previous data is
   retained, then return to **Today**.

## Equipment and anomaly matching

1. In **Work profile**, ensure **Heat sealer HS-03** is selected as verified
   equipment and save the profile.
2. Return to **Today**.
3. Expected: an **anomaly-triggered check** appears for Heat sealer HS-03.
4. The card must say **potential/visual inspection** and must not instruct the
   employee to open, reset, repair, or operate protected equipment.
5. Remove Heat sealer HS-03 from the work profile and return to Today.
6. Expected: its asset/anomaly task is no longer generated.

## Assignment trace workflow

1. Tap any task card.
2. Confirm the sheet displays:
   - Why the employee received it
   - Published rule ID and immutable version
   - Approved source title/version/section
   - Explicit pass condition
3. For a machine-specific task, confirm the assignment reason names only a
   verified machine assigned in the employee profile.
4. Close the sheet and confirm the selected list state is retained.

## Acceptance checklist

- [ ] The full build uses charcoal/sand/electric-blue instead of the old palette
- [ ] Today is the default app destination; Work profile remains accessible
- [ ] Due, completed, overdue, and review lists are visually separate
- [ ] Every status shows a label/icon and does not rely on color alone
- [ ] Counts match the cards in each list
- [ ] Department, role, shift, activities, and verified equipment drive matching
- [ ] Unverified asset candidates do not generate official machine tasks
- [ ] Heat sealer assignment creates an urgent anomaly-triggered check
- [ ] Removing an asset removes its generated task on returning to Today
- [ ] Task cards show due/submitted/completed timing and evidence requirements
- [ ] Assignment trace includes rule version, citation, reasons, and pass condition
- [ ] Generated task instances remain stable for the same day and inputs
- [ ] Previous story data survives the APK upgrade

## Story boundary

This story validates receiving and separating daily task instances. Full task
instructions and “why assigned” detail are expanded in EN-STF-005; structured
answers/readings and completion transitions belong to EN-STF-006. The seeded
matcher mirrors the deterministic server contract until the hosted Django task
orchestrator is connected.
