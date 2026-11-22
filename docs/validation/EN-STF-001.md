# EN-STF-001 validation — Work activities and equipment interactions

## Build under review

- App version: **0.1.1+2**
- Story: **EN-STF-001**
- Platform: Android APK
- Data mode: local demo seed with on-device persistence

## Seed data

The first launch starts with this employee profile:

| Field | Seed value |
| --- | --- |
| Employee | Maya Chen |
| Organization | Aster Foods |
| Site | North Plant |
| Department | Packaging |
| Role | Production operator |
| Shift | Day · 06:00–14:00 |
| Activities | Line start-up; Quality checks |
| Equipment | None yet |

To restore this state after saving, clear Energia's app storage in Android
settings or uninstall and reinstall the APK.

## Main validation workflow

1. Install the APK and open **Energia**.
2. Confirm the home screen greets **Maya** and shows the work profile at **68%**.
3. Tap **Continue setup**.
4. On **Your work base**, verify organization and site are locked. Keep the
   seeded department, role, and shift, then tap **Continue**.
5. On **Recurring activities**, select at least one suggested activity.
6. Tap **Add custom activity**, enter a unique activity name such as **Inspect
   steam trap station**, add an optional description, and tap **Add activity**.
   Confirm the new selected card has a **Custom** badge.
7. On **Equipment interactions**, enable **Cartoner C-12**. Confirm **Operate**
   is selected by default, then add **Start up** or **Inspect**.
8. Tap **Continue**, check that the custom activity appears in the review
   summary, then tap **Save profile**.
9. Confirm the home screen now shows **Profile complete**, **100%**, and the
   selected machine count.
10. Fully close and reopen the app. Edit the profile and confirm the custom
    activity and description are retained.

### Custom activity validation

1. Tap **Add custom activity**.
2. Enter **Cleaning**, which already exists in suggested activities, and tap
   **Add activity**.
3. Expected: the sheet remains open and shows **This activity already exists.**
4. Replace it with a unique name and save it.
5. Expected: it is selected automatically and can be deselected or removed.

## Validation and approval checks

### Required equipment validation

1. Return to the seeded state.
2. Continue through work base and activities without choosing equipment.
3. Tap **Continue** on the equipment step.
4. Expected: the app stays on the step and displays **Select at least one
   machine you interact with.**

### Department confirmation

1. Change the department from **Packaging** to **Utilities**.
2. Complete the remaining steps and reach review.
3. Expected: **Confirmation required** identifies **Department change**.

### Safety-critical confirmation

1. Enable a machine and select **Isolate / lockout** (the shield-marked choice).
2. Continue to review and save.
3. Expected: review warns that administrator confirmation is required, and the
   home screen shows **Admin confirmation pending** after save.

## Acceptance checklist

- [ ] Palette, spacing, cards, and gradient composition feel suitable for the demo
- [ ] Work context uses controlled choices rather than unrestricted text
- [ ] A unique custom recurring activity can be added with an optional description
- [ ] Duplicate custom/suggested activity names are rejected case-insensitively
- [ ] A custom activity can be deselected and removed
- [ ] At least one activity and one equipment interaction are required
- [ ] Department changes are visibly marked for administrator confirmation
- [ ] Safety-critical interactions are visibly marked for confirmation
- [ ] A saved profile can be edited again
- [ ] Saved values survive an app restart
- [ ] No screen overflows on a typical 390 × 844 mobile viewport

## Story boundary

This build validates the staff work-profile experience. Searchable inventory,
QR scanning, and adding an unverified missing machine are implemented in
**EN-STF-002** after this story is accepted.
