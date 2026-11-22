# SYNC-001 validation — Mobile, administrator, and PostgreSQL synchronization

## Build under review

- App version: **0.3.1+5**
- Scope: synchronized replacement for EN-STF-001 through EN-STF-003
- API: `https://steam-little-holland-thread.trycloudflare.com/api/v1`
- Admin: `https://steam-little-holland-thread.trycloudflare.com/admin/`
- Database: PostgreSQL 17 with pgvector enabled

The Cloudflare Quick Tunnel is for validation and remains available only while
the Energia backend machine and tunnel process are running. A permanent named
tunnel requires Cloudflare account authentication.

## Demo accounts

| Channel | Username | Password |
| --- | --- | --- |
| Mobile staff | `maya` | `energia-demo` |
| Django administration | `energia-admin` | `Energia-Admin-Demo-2026!` |

The mobile validation build signs in to the staff demo account automatically.
These credentials must not be used outside the demo.

## Confirm server connection

1. Open the API health URL:
   `https://steam-little-holland-thread.trycloudflare.com/api/v1/health/`
2. Expected response includes `status: ok` and `database: postgresql`.
3. Install the APK over the previous Energia build.
4. Open Energia and confirm the bar above navigation changes from
   **Synchronizing with Energia server…** to
   **Synchronized with Energia server**.
5. If the API is stopped, the app must show an explicit synchronization error;
   it must not claim that local seed data is current server data.

## Existing mobile-data migration

On the first synchronized launch, a completed local profile is uploaded once,
then read back from the server.

1. Before installing, note the current department, custom activities, selected
   equipment, and interactions.
2. Install and wait for the synchronized status.
3. Open **Work profile** and confirm those values remain.
4. Sign in to Django Admin and inspect:
   - **Staff work profiles**
   - **Custom activities**
   - **Asset assignments**
5. Expected: the same values are now stored in PostgreSQL.

## Profile and assignment synchronization

1. In the mobile app, add or edit a custom recurring activity.
2. Change one verified equipment assignment or interaction and save the profile.
3. Wait for **Synchronized with Energia server**.
4. Refresh Django Admin.
5. Expected: the profile, activity, assignment, and audit event are updated.
6. Return to **Today**. Expected: tasks refresh from server rules and only
   verified server assignments create machine-specific checks.

## Staff-to-administrator candidate workflow

1. Mobile: open inventory → **Add missing**.
2. Enter a unique machine, location, identifier, and photo.
3. Submit it and wait for server synchronization.
4. Admin: open **Asset candidates**.
5. Expected: the submission, employee, photo, duplicate suggestions, and
   pending status are visible.
6. Select it and run **Approve and add selected candidates to inventory**.
7. Mobile: reopen inventory or profile to refresh.
8. Expected:
   - It disappears from pending additions.
   - It appears in verified server inventory.
   - An assignment exists for the submitting employee.
   - It has no official interaction until the employee selects one.
9. Confirm audit events exist for submission and approval.

## Server-owned daily checks

1. Mobile: open **Today** and inspect all four status lists.
2. Admin: open **Tasks** and find the same task titles/statuses.
3. Compare a task's rule code, version, citation, pass condition, assignee,
   department, asset, and due time between mobile and admin.
4. Expected: values match because the mobile no longer generates task records.
5. Change a verified assignment, save, then return to Today.
6. Expected: server task matching reflects the synchronized assignment.

## Acceptance checklist

- [ ] API health reports PostgreSQL
- [ ] Mobile authenticates through JWT over HTTPS
- [ ] Mobile visibly reports synchronized, connecting, and error states
- [ ] Existing completed local profile is migrated once
- [ ] Profile and custom activities are stored server-side
- [ ] Equipment assignments and interactions are stored server-side
- [ ] Inventory search and QR resolution read server assets
- [ ] Duplicate suggestions are calculated by the backend
- [ ] Candidate photo/submission appears in administrator review
- [ ] Admin approval creates an official asset and staff assignment
- [ ] Pending candidates never generate official tasks
- [ ] Daily task records come from published backend rule snapshots
- [ ] Audit events record profile, assignment, candidate, approval, and task actions
- [ ] App does not silently call local seed data “synchronized” after an API error

## Hosting note

Cloudflare currently provides the external HTTPS validation tunnel. PostgreSQL
and Django run on the Energia host because Cloudflare Pages cannot execute a
standard Django/PostgreSQL service. Production should use an authenticated named
Cloudflare Tunnel in front of a durable Django runtime and managed/backed-up
PostgreSQL.
