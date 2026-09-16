# Greenlight — Active Tasks

> This file is the ordered working backlog for the Greenlight system.
>
> At every completed milestone: mark the task as **Done**, record the validation evidence, move the next task to **In progress**, then commit and push the relevant code and documentation. Never add passwords, tokens, Wi-Fi credentials, private keys, verification codes, `.env` contents, or production database data.


## Current focus


- **In progress:** Add the ESP32 firmware source to version control and document its build, upload, configuration, and safe secrets workflow.
- **Next save point:** Commit the firmware source, a safe `.gitignore`, and firmware documentation after the initial build/upload procedure has been verified.


## Ordered backlog


| Priority | Status | Area | Task | Done when |
| --- | --- | --- | --- | --- |
| P0 | In progress | ESP32 | Create a dedicated GitHub repository for the current ESP32 firmware and commit the current source | Repository exists; firmware source, README and safe `.gitignore` are pushed; Wi-Fi/MQTT credentials are excluded; local build/upload procedure is documented |
| P0 | Next | Backend | Replace development verification-code logging with real email delivery | Active codes are not logged in production; provider credentials come only from environment variables; registration, resend, expiry and verification are tested |
| P0 | Next | Backend | Implement production access and refresh token authentication | Signed access tokens, refresh-token rotation/revocation and protected-endpoint tests are implemented; placeholder tokens are removed |
| P0 | Next | Backend | Add schema migration/versioning and SQLite backup/restore documentation | Existing databases upgrade safely; backup and restore procedure is documented and tested without committing a database file |
| P1 | Next | Flutter | Implement verification-code UI and resend cooldown handling | Registration → code entry → verification → login works; expired-code, invalid-code, attempt-limit and resend-cooldown errors are shown clearly |
| P1 | Next | Flutter | Connect the Flutter authentication flow to the public HTTPS backend API | Register, verify, resend and login work against the public API; API base URL is configurable; no secrets are hard-coded |
| P1 | Next | ESP32 | Document hardware pin mapping, AP provisioning, reset behavior and MQTT topic contract | Documentation matches the tested device behavior and backend integration assumptions |
| P2 | Planned | Backend + ESP32 | Verify device manufacturing status and ownership before remote control is enabled | Backend rejects unauthorized devices; ownership and authorization flow are tested |
| P2 | Planned | Product | Define a tested backup, recovery and production-deployment runbook | Recovery procedure is documented and rehearsed; rollback points and responsibilities are clear |


## Recently completed


| Date | Area | Completed task | Evidence |
| --- | --- | --- | --- |
| 2026-09-16 | Backend | Secure the email-verification-code lifecycle | `greenlight_auth` PR #1 merged to `main` at `28a9fe6`; codes hashed, TTL 15 minutes, five-attempt limit, 60-second resend cooldown; public HTTPS expiry, resend, verify and login flow manually validated |
| 2026-09-16 | Backend | Connect backend source control and merge the email-verification feature | `greenlight_auth/main` synchronized on the server; checkout was clean after fast-forward to `28a9fe6` |
| 2026-09-16 | Documentation | Add project context documentation | `greenlight_app/main` commit `1bc7418` — `docs: add project context and email verification status` |


## Working rules


- Choose one task at a time, starting with the highest-priority `In progress` task.
- Keep changes small enough to validate and describe in one commit.
- Announce a **save point** after a completed, validated unit of work and before moving to another task.
- Before each commit, inspect `git status`, `git diff --check`, and the staged diff; exclude `.env`, database files, logs, backups, virtual environments, caches, credentials and production data.
- Push every validated commit so GitHub remains the source of truth that can be read in a future assistant session.
- Update this file when task status, priority, scope or validation evidence changes.
- Update `docs/PROJECT_CONTEXT.md` only when architecture, API contracts, infrastructure, deployment workflow, source locations or security rules change.
