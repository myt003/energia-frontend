# Energia mobile and web

Single Flutter codebase for the Energia staff shell, administrator mobile shell,
and administrator web shell. Role is selected at login and verified against the
Django/PostgreSQL backend; all clients share the same records, permissions, and
audit trail.

## Current delivery (v0.7.0+10)

- Staff: work profile and equipment interactions, inventory/QR workflows, daily
  compliance checks, energy habits, personal score, notifications, offline queue,
  grounded explanations, guided forms, and photo/video evidence capture
- Administrator mobile: invoice scan/OCR/confirmation, drafts, consumption and
  flow graphs, meter readings and health scores, nameplate/QR capture, peak checks
- Administrator web: RAG/document upload, rules, check monitoring, health scores,
  drill-down, alerts, recommendations, inventory/meter admin, maintenance, weather
  peaks, manual energy/cost entry, staged Excel imports, configurable charts, and
  reports
- Login with staff/administrator selection, JWT auth, and username-namespaced
  token cache
- Server-first synchronization; local persistence is cache and queue only

The deployed web build is available at
`https://reduction-ultimate-connector-downloadable.trycloudflare.com` and talks to
`https://street-swim-investor-cave.trycloudflare.com/api/v1`. Both are
temporary validation URLs.

## Product palette

The enterprise light UI uses:

- **Deep Navy:** `#102A43` (sidebar, headings)
- **Teal:** `#0F766E` (primary actions)
- **Electric Lime:** `#A3E635` (highlights/metrics)
- **Background:** `#F5F7FA`
- **White:** `#FFFFFF` (cards)
- **Slate Navy:** `#172B4D` (body text)

Inter typography, Lucide-style icons, 10–14 px radii, subtle borders/shadows, and
text-labelled green/amber/red status semantics. Old palette names remain as
compatibility aliases in `lib/core/theme/energia_theme.dart`.

## Run and verify

Android builds require JDK 21 because AGP 9.3 lint uses Java 21 APIs:

```bash
flutter config --jdk-dir=/home/myt/.local/share/mise/installs/java/21.0.13.1+2.0.LTS
flutter pub get
flutter analyze
flutter test
flutter run
```

Build with the validation API endpoint:

```bash
flutter build web --release \
  --dart-define=ENERGIA_API_BASE_URL=https://street-swim-investor-cave.trycloudflare.com/api/v1
flutter build apk --release \
  --dart-define=ENERGIA_API_BASE_URL=https://street-swim-investor-cave.trycloudflare.com/api/v1
```

## Structure

```text
lib/
  core/theme/                    Design tokens and palette
  app.dart, bootstrap.dart       Role-aware bootstrap and routing
  features/admin_web/            Administrator web shell and workspace pages
  features/admin_invoice/        Administrator mobile shell and workflows
  features/evidence_capture/     Evidence capture and checksum helpers
  features/work_profile/         Staff work profile
test/                            Unit, widget, and visual regression tests
docs/validation/                 Story-by-story validation workflows
```

Unverified equipment candidates remain separate from official assignments and
energy calculations until an administrator approves them.
