# EN-STF-002 validation — Inventory equipment and missing assets

## Build under review

- App version: **0.2.0+3**
- Story: **EN-STF-002**
- Platform: Android APK
- Data mode: seeded North Plant inventory with on-device persistence

Install this APK over `0.1.1+2` to confirm the existing work profile and custom
activities are retained.

## Seed data

The verified inventory contains nine assets across Packaging, Utilities,
Production, and Warehouse. Useful validation records include:

| Asset | Code | Department | Location |
| --- | --- | --- | --- |
| Cartoner C-12 | PKG-C12 | Packaging | Packaging line 2 |
| Heat sealer HS-03 | PKG-HS03 | Packaging | Packaging line 3 |
| Air compressor AC-04 | UTL-AC04 | Utilities | Utilities room |
| Process chiller CH-02 | UTL-CH02 | Utilities | North utility bay |
| Mixing tank MX-11 | PRD-MX11 | Production | Production hall A |

A seeded unverified candidate, **Label printer LP-02**, demonstrates the
pending-review state. It must not count as selected verified equipment.

## Main inventory workflow

1. Open Energia and tap **Update work profile** or **Continue setup**.
2. Continue through work context and recurring activities.
3. On **Equipment interactions**, tap **Browse equipment inventory**.
4. Confirm **Label printer LP-02** appears under **Pending additions** with a
   review state.
5. Search for `HS-03` and select **Heat sealer HS-03**.
6. Clear the search, choose the **Utilities** department filter, and confirm
   only Utilities assets are shown.
7. Return to **All**, use **Show more**, and verify additional paginated assets
   appear.
8. Tap **Save machines**. Back on the profile, select the normal interaction
   types for each verified machine.
9. Continue to review, save the profile, close the app, and reopen it.
10. Confirm the official equipment selection remains saved.

## QR workflow

1. In inventory, tap **Scan QR** and allow camera access.
2. Scan an Energia QR containing an asset ID, asset code, or serial number.
3. If no printed QR is available, tap **Use demo QR · PKG-HS03**.
4. Expected: **Heat sealer HS-03** becomes selected and a confirmation message
   appears.
5. An unknown QR must show that it was not found rather than creating an asset.

## Duplicate-detection workflow

1. Tap **Add missing**.
2. Enter:
   - Name: `Cartoner`
   - Type: `Packaging machine`
   - Location: `Packaging line 2`
   - Asset tag/serial: `CTN-12-8841`
3. Take or choose a clear equipment photo.
4. Tap **Check duplicates & submit**.
5. Expected: **Cartoner C-12** is shown as a high-confidence possible match,
   with the matching identifier, name, type, and location explained.
6. Tap **Use this existing asset**.
7. Expected: the verified Cartoner is selected and no new candidate is created.

## Missing-equipment workflow

1. Tap **Add missing** again and enter a genuinely missing machine, for example:
   - Name: `Case erector CE-09`
   - Type: `Packaging machine`
   - Location: `Packaging line 4`
   - Asset tag/serial: `CE09-24018`
2. Take or choose a photo and submit.
3. If suggestions are displayed but none are the same machine, choose **None
   match · Submit for review**.
4. Expected: the candidate appears under **Pending additions** and later under
   **Awaiting admin review** in the work-profile equipment step.
5. Confirm it has no interaction controls and does not satisfy the requirement
   to select at least one verified machine.
6. Restart the app and confirm the pending candidate remains visible.

## Acceptance checklist

- [ ] Search matches name, asset code, serial number, type, and location
- [ ] Department filters and paginated **Show more** behavior work
- [ ] Verified assets can be selected and deselected
- [ ] Camera QR scanning and the demo fallback select the correct asset
- [ ] Unknown QR codes do not create inventory records
- [ ] Missing equipment requires name, type, location, and photo
- [ ] Duplicate suggestions explain why an existing asset may match
- [ ] Choosing an existing match avoids creating a duplicate candidate
- [ ] A manual submission is clearly marked unverified/pending review
- [ ] A pending candidate is excluded from official interactions/calculations
- [ ] Existing profile data survives installation over the previous build
- [ ] Selections and candidates survive an app restart

## Story boundary

This demo stores inventory state locally for validation. Backend searchable and
paginated asset endpoints, authoritative `AssetAssignment` records, and the
administrator approval queue will be connected during platform/API delivery;
the mobile state and safeguards already follow those boundaries.
