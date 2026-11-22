# EN-STF-004 validation — Personalized energy-saving habits

## Build under review

- App version: **0.4.0+6**
- Story: **EN-STF-004**
- API: `https://steam-little-holland-thread.trycloudflare.com/api/v1`
- Admin: `https://steam-little-holland-thread.trycloudflare.com/admin/`
- Database: synchronized PostgreSQL system of record

Install over `0.3.1+5`; existing synchronized profile, assignments, candidates,
and tasks remain in PostgreSQL.

## Demo accounts

| Channel | Username | Password |
| --- | --- | --- |
| Mobile staff | `maya` | `energia-demo` |
| Django administration | `energia-admin` | `Energia-Admin-Demo-2026!` |

## Seeded recommendation behavior

With Cartoner C-12 and Heat sealer HS-03 assigned using **Operate** and
**Inspect**, the server issues five eligible habits:

1. Avoid unnecessary idle operation on Cartoner C-12
2. Avoid unnecessary idle operation on Heat sealer HS-03
3. Observe the approved standby state on Cartoner C-12
4. Observe the approved standby state on Heat sealer HS-03
5. Report simultaneous heating and cooling

An approved template named **HABIT-SHUTDOWN-004** also matches the equipment,
but must never reach the employee. Locked constraint
**SAFETY-PKG-LOCKED-01** blocks its `shutdown` tag because production and the
approved shutdown sequence take priority.

## Mobile workflow

1. Open Energia and wait for **Synchronized with Energia server**.
2. On **Today**, select **Energy habits**.
3. Confirm the habit count and **Safety rules take priority** banner.
4. Verify the five eligible habits above are present after scrolling.
5. Confirm **Power down … during short pauses** is absent.
6. Tap an idle or standby habit.
7. Confirm the sheet shows:
   - Approved template code and immutable version
   - Practical instruction
   - Why the template matched
   - Recommendation owner
   - Approved source/version/section
   - Explicit pass condition
   - Safety-precedence explanation
8. Return to **Compliance checks** and confirm the original compliance lists
   remain separate and unchanged.

## Personalization workflow

1. Work profile → equipment interactions.
2. Remove **Inspect** from Heat sealer HS-03 but keep **Operate**, then save.
3. Return to Today → Energy habits.
4. Expected:
   - Its standby-observation habit is no longer active.
   - Its idle-operation habit remains because **Operate** still matches.
5. Remove Cartoner C-12 entirely and save.
6. Expected: Cartoner-specific habits disappear after server refresh while the
   immutable cancelled task records remain auditable in administration.
7. Restore the assignments to repeat the default demo.

## Administrator and safety workflow

1. Open Django Admin → **Recommendation templates**.
2. Confirm each template has equipment/activity/interaction applicability,
   risk, owner, evidence, source, pass condition, safety note, and approval.
3. Confirm approved template versions are read-only; changes require a new
   version rather than rewriting tasks already issued.
4. Open **Safety constraints** and inspect `SAFETY-PKG-LOCKED-01`.
5. Confirm the locked version blocks `shutdown` and `power_isolation` tags for
   Packaging machines.
6. Open **Audit events** → `energy_habits.generated`.
7. Confirm `excluded_by_safety` cites HABIT-SHUTDOWN-004, each affected asset,
   and the locked safety constraint.
8. Open **Tasks** and filter `task_kind = Energy habit`; compare the records to
   mobile.

## Acceptance checklist

- [ ] Energy habits are a distinct server-backed view from compliance checks
- [ ] Only approved recommendation template versions create tasks
- [ ] Department, activities, verified assets, and interactions affect matching
- [ ] Every habit includes source, owner, pass condition, and evidence need
- [ ] Instructions never tell staff to bypass protected controls or procedures
- [ ] Locked safety constraints exclude conflicting recommendations
- [ ] Exclusion decisions are captured in append-only audit metadata
- [ ] Approved templates and locked safety versions are read-only
- [ ] Existing task snapshots do not change when templates later change
- [ ] Obsolete due habits are cancelled, not deleted
- [ ] Mobile and Django Admin display the same synchronized habit records
- [ ] API failure is shown explicitly rather than replaced by local habit seed data

## Story boundary

This story assigns approved energy habits. Detailed task explanation is expanded
in EN-STF-005; answers/readings, evidence capture, and verification remain
EN-STF-006 through EN-STF-008. Those stories will use the same synchronized
server-owned task records.
