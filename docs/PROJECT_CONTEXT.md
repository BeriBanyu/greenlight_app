# Greenlight — Project Context

> Purpose: keep a short, always-current project map so a new assistant session can immediately understand where the components are, how to access them, and what is safe to change.
>
> Update this file whenever infrastructure, deployment, API contracts, credentials handling, or the active task changes. Never add passwords, tokens, private keys, Wi-Fi credentials, database URLs containing passwords, or secrets from `.env` files.


## 1. Product


- **Product:** Greenlight
- **Goal:** Universal smart-lamp system with ESP32, Flutter client, local control and optional cloud/remote control.
- **Key rule:** Local use must work without registration and internet. Registration is required for remote control, MQTT/cloud access, and cloud-only settings.


## 2. Repositories


| Component | Repository | Default branch | Purpose |
| --- | --- | --- | --- |
| Flutter client | `https://github.com/BeriBanyu/greenlight_app` | `main` | Android, iOS and Web application |
| Auth backend | `https://github.com/BeriBanyu/greenlight_auth` | `main` | FastAPI authentication service deployed on a remote server |
| ESP32 firmware | `TODO: repository or local location` | `TODO` | Lamp firmware |


## 3. Current source locations


### Flutter client


- Local checkout: `D:\GreenlightFlutter\greenlight_app`
- Main documentation: `docs/project_prompt.md`
- Infrastructure and current-work context: `docs/PROJECT_CONTEXT.md`
- Main code directory: `lib/`
- Test directory: `test/`
- Current published documentation commit before this update: `79e5377` — `Update project prompt and testing context`


### Auth backend


- The backend is **not** located in `D:\GreenlightFlutter`.
- Source-of-truth checkout and running deployment are on the remote server.
- Repository: `https://github.com/BeriBanyu/greenlight_auth`
- Server access method: SSH as `root` to `usa-dba.fvds.ru`.
- Server project directory: `/opt/greenlight_auth`.
- Python environment: Python virtual environment at `/opt/greenlight_auth/venv`.
- Database: SQLite file `/opt/greenlight_auth/greenlight_auth.db`.
- Process manager: systemd.
- Service name: `greenlight-auth.service`.
- Application server: Uvicorn runs `main:app` on `127.0.0.1:8000`.
- Public API base URL: `https://greenlight-lamp.ru`.
- Public auth API prefix: `https://greenlight-lamp.ru/auth/`.
- Reverse proxy / TLS: Nginx with HTTPS on `greenlight-lamp.ru:443`. The `/auth/` route is proxied to FastAPI at `127.0.0.1:8000`. Nginx configuration: `/etc/nginx/vhosts/www-root/greenlight-lamp.ru.conf` and `/etc/nginx/vhosts-resources/greenlight-lamp.ru/greenlight-auth.conf`.
- Health endpoint: available internally at `http://127.0.0.1:8000/health`; it is not publicly proxied and `https://greenlight-lamp.ru/health` currently returns Nginx `404`.
- Containers: Docker is not installed; the backend is not containerized.
- MQTT: Mosquitto is available locally on `127.0.0.1:1883` and externally on port `8883`.


### Database


- Engine: SQLite.
- Database file: `/opt/greenlight_auth/greenlight_auth.db`.
- Current table: `users`.
- Current user fields include `email`, `password_hash`, `verification_code`, `email_verified`, `created_at`, and `updated_at`.
- Verification-code lifecycle fields are implemented in the current backend revision; inspect the actual schema/code before making further database changes rather than assuming an exact field list.
- Password storage: bcrypt through `passlib`.
- Migration tool: Not implemented yet. Schema is currently initialized by FastAPI startup code.
- Future decision: keep SQLite during the early single-server stage; evaluate a planned migration only when requirements justify MySQL or PostgreSQL.
- Backup approach: Not documented yet; define backup and restore procedure before production use.


## 4. Deployment workflow


The current deployment is a Git checkout on the server, started by systemd. Confirm the exact update procedure before performing a production deployment.


```text
1. Connect to the server by SSH.
2. Change directory to /opt/greenlight_auth.
3. Check git status before updating.
4. Pull the required reviewed commit from origin/main.
5. Update Python dependencies only when requirements.txt changed.
6. Restart greenlight-auth.service.
7. Check service status and recent logs.
8. Check the internal health endpoint and the required public /auth/ routes.
9. If deployment fails, restore the prior known-good Git commit and restart the service.
```


Commands must be used only after reviewing the changes and without exposing secrets:


```bash
ssh root@usa-dba.fvds.ru
cd /opt/greenlight_auth
git status
git log --oneline -5
git pull --ff-only origin main
./venv/bin/pip install -r requirements.txt
systemctl restart greenlight-auth.service
systemctl status greenlight-auth.service --no-pager
journalctl -u greenlight-auth.service -n 100 --no-pager
curl -i http://127.0.0.1:8000/health
```


Do not run `git pull`, install dependencies, restart the service, or alter Nginx without first reviewing the intended change and taking an appropriate backup.


## 5. Authentication status


### Completed


- Flutter login flow was tested.
- Welcome screen separates registration from local/offline use.
- After authentication, the My Lamps screen uses explicit `Log out`; logout returns to welcome while preserving local devices.
- Backend health endpoint exists: `GET /health`.
- Backend registration endpoint exists: `POST /auth/register`.
- Backend email-confirmation endpoint exists: `POST /auth/verify`.
- Backend login endpoint exists: `POST /auth/login`.
- Backend resend-code endpoint exists: `POST /auth/resend-code`.
- Passwords are stored as bcrypt hashes.
- Login is blocked until `email_verified` is true.
- A six-digit verification code is generated by the backend.
- Verification codes are stored as hashes rather than plaintext in SQLite.
- Verification codes expire after 15 minutes.
- Resending a verification code is limited by a 60-second cooldown.
- Expired codes are rejected by `POST /auth/verify` with HTTP `400` and a user-facing message instructing the user to request a new code.
- A successful verification sets `email_verified` to `true` and permits subsequent login.
- The public HTTPS flow was manually validated on 2026-09-16: resend code returned `200`, verification of a newly issued code returned `200`, and login after verification returned `200`.
- At the current development stage, the verification code is written to backend logs; real email delivery is not implemented yet.
- Login and verification currently return a development placeholder token in the form `fake-token-<email>`; no production access/refresh-token system exists yet.


### Known limitations


- Verification codes are logged by the backend in the current development implementation. This must be removed or strictly development-only before production, because journal readers could access active codes.
- Real email delivery is not implemented: there is no SMTP or transactional email provider integration.
- The current token is a development placeholder, not a signed JWT or a production session mechanism.
- Verification failed-attempt protections and endpoint-wide rate limits should be reviewed in code and strengthened as needed, especially for `/auth/verify`, `/auth/resend-code`, and `/auth/login`.
- There are no access tokens, refresh tokens, token revocation, password-reset flow, database migrations, or documented database backups.
- Do not retain test users or verification records created for manual validation in the production database; remove them through a reviewed database procedure.


### Next planned milestone


1. Review the committed backend implementation and ensure the test account and any related verification records are removed safely.
2. Commit and push the backend email-verification lifecycle change only after reviewing `git diff --cached` for secrets, database files, logs, and test credentials.
3. Replace development code logging with a real SMTP or transactional email provider configured through environment variables and `.env.example`; never commit mail credentials.
4. Add explicit verification-attempt limits and robust rate limiting for verification, resend, and login endpoints.
5. Implement real access and refresh tokens with logout/revocation.
6. Add password reset using a separate verification-code purpose.
7. Add a safe schema-migration mechanism and documented SQLite backup/restore process.
8. Later: add account ownership and manufactured-device verification before remote MQTT control is enabled.


## 6. API contract


The API is served internally by Uvicorn at `127.0.0.1:8000` and publicly through Nginx at `https://greenlight-lamp.ru/auth/`.


| Method | Path | Status | Request | Response | Notes |
| --- | --- | --- | --- | --- | --- |
| `GET` | `/health` | Implemented | None | `{"status":"ok"}` | Internal endpoint exists; it is not currently publicly proxied |
| `POST` | `/auth/register` | Implemented | `email`, `password` | Confirmation message | Creates an unverified user and issues a six-digit verification code |
| `POST` | `/auth/verify` | Implemented and manually validated | `email`, `code` | Message, placeholder token, user | Valid code confirms the email; code TTL is 15 minutes; expired/invalid codes return HTTP `400` |
| `POST` | `/auth/login` | Implemented and manually validated | `email`, `password` | Message, placeholder token, user | Returns HTTP `403` when email is unverified; succeeds after verification |
| `POST` | `/auth/resend-code` | Implemented and manually validated | `email` | Confirmation message | Issues a new code; resend cooldown is 60 seconds |
| `POST` | `/auth/refresh` | Planned | Refresh token | New access token | Not implemented |
| `POST` | `/auth/logout` | Planned | Refresh token | Confirmation | Not implemented |
| `POST` | `/auth/password-reset/request` | Planned | Email | Neutral confirmation | Not implemented |
| `POST` | `/auth/password-reset/confirm` | Planned | Email, code, new password | Confirmation | Not implemented |


### Verification behavior for Flutter


- Submit the verification code to `POST /auth/verify` with `email` and six-digit `code`.
- On a successful `200` response, persist/use the returned user state according to the current client flow; remember that the returned token is development-only and not a production authentication credential.
- On `400`, show the backend-provided verification error. For an expired code, offer a resend action.
- Use `POST /auth/resend-code` for resend. If a resend is attempted before the 60-second cooldown ends, handle the backend error and present a clear wait/retry state.
- Do not derive verification state from the client alone; use backend responses and the returned `user.email_verified` value.


## 7. Security rules


- Never commit `.env`, passwords, API keys, tokens, SSH private keys, database credentials, SMTP passwords, TLS private keys, production Wi-Fi credentials, SQLite database files, or service logs.
- Commit a `.env.example` containing only variable names and safe placeholders.
- Hash passwords with bcrypt or Argon2; never store plaintext passwords.
- Store verification codes as hashes; do not store plaintext codes in the database.
- Keep verification codes single-use and time-limited. The current TTL is 15 minutes.
- Enforce resend cooldowns. The current cooldown is 60 seconds.
- Add and maintain failed-attempt limits and rate limiting before production exposure.
- Use HTTPS for all public API traffic.
- Do not return development codes or placeholder tokens in production.
- Remove `[EMAIL][DEV]` or equivalent verification-code logging before production email verification is enabled. Limit access to service journals in all environments.
- Do not expose the internal Uvicorn port `8000` directly to the internet.
- Do not make deployment changes as `root` casually; review commands and changes first.
- Before pushing changes that may contain secrets, inspect `git diff --cached` and run a targeted secret scan.


## 8. Device and product constraints


- Hardware: ESP32 smart lamp with 0–10 V dimming driver.
- Local setup: use the lamp access-point mode; do not require mDNS discovery or tracking a changing router IP.
- Registration is required before a lamp receives home Wi-Fi settings, accesses MQTT, or becomes remotely controllable.
- The backend must later verify that a lamp is manufactured/authorized by Greenlight before remote control is enabled.
- Factory reset erases user settings and requires scanning the QR code again.


## 9. Current task log


| Date | Status | Change / decision | Validation |
| --- | --- | --- | --- |
| 2026-09-16 | Done | Updated Flutter project prompt | Commit `79e5377` pushed to `greenlight_app/main` |
| 2026-09-16 | Done | Tested Flutter login flow | Login flow verified on the application |
| 2026-09-16 | Done | Mapped backend location and runtime | `/opt/greenlight_auth`, systemd service `greenlight-auth.service`, Uvicorn at `127.0.0.1:8000` |
| 2026-09-16 | Done | Confirmed public HTTPS auth route | `https://greenlight-lamp.ru/auth/` is proxied by Nginx to FastAPI at `127.0.0.1:8000` |
| 2026-09-16 | Done | Secured verification-code lifecycle | Verification codes are hashed; TTL is 15 minutes; resend cooldown is 60 seconds |
| 2026-09-16 | Done | Validated expiry, resend, verify, and login | Expired code returned `400`; resend returned `200`; valid verification returned `200`; login after confirmation returned `200` |
| 2026-09-16 | In progress | Save reviewed backend and Flutter documentation changes to GitHub | Review staged diffs, exclude database/logs/secrets/test credentials, then commit and push separately |
| 2026-09-16 | Next | Replace development email logging with real delivery and production auth tokens | Use environment-managed credentials; do not deploy unreviewed changes |


## 10. How to brief an assistant


At the start of a new chat, provide:


```text
Read these first:
1. https://github.com/BeriBanyu/greenlight_app/blob/main/docs/PROJECT_CONTEXT.md
2. https://github.com/BeriBanyu/greenlight_app/blob/main/docs/project_prompt.md
3. https://github.com/BeriBanyu/greenlight_auth

Current task: <one specific outcome>
Current environment: <local Flutter / remote server / both>
Constraints: <anything that must not change>
```


Then provide the exact command output, error, backend file, endpoint request/response, or Flutter screen currently under discussion. Never paste passwords, private keys, access tokens, SMTP credentials, contents of `.env`, or verification codes from production logs.
