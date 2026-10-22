# Deadline Coach

A Telegram assistant built with n8n that collects my course deadlines from Moodle and from my own messages,
reminds me before they are due, warns me when a teacher moves a date, and plans my week.

No-Code Software Development project, Saty Viard Laroque, ESSEC AIDAMS 3A, October 2026.
Full design and architecture diagrams: [`docs/Deadline_Coach_Report.pdf`](docs/Deadline_Coach_Report.pdf).

## What it does

| Command | Result |
|---|---|
| `/add <task> <date>` | Free text, e.g. `/add env econ paper next monday`. An LLM extracts course, title and date, a Code node validates it, then it is saved, or reported as duplicate / moved / already done. |
| `/deadlines` | Open deadlines sorted by date, with urgency colours. |
| `/done <number>` | Marks a deadline as done. |
| `/plan` | An LLM proposes a work plan for the next 7 days. |
| `/sync` | Pulls new or moved deadlines from the Moodle calendar now. |
| `/help` (or anything unknown) | Usage message, with "Did you mean …?" for typos. |

Automatic: a digest every day at 08:00 (7, 3 and 1 day before each deadline, each sent once), and a Moodle sync every 6 hours.

## Architecture

Five workflows, one job each (exported in [`workflows/`](workflows)):

| File | Trigger | Role |
|---|---|---|
| `01_main.json` | Telegram Trigger | Parse message (Code) → Command Router (Switch, 7 routes) → one branch per command |
| `02_reminders.json` | Schedule 08:00 + manual | Due deadlines → digest per user → tick `reminded_7/3/1` after the send succeeds |
| `03_moodle_sync.json` | Schedule 6 h + manual + `/sync` | HTTP GET Moodle iCal → parse → upsert by Moodle UID → summary + `sync_log` |
| `04_send_to_telegram.json` | Execute Workflow (inputs `chatId`, `text`) | Sub-workflow used for every reply: splits long messages, retries |
| `05_errors.json` | Error Trigger | Telegram alert with workflow name, failing node, error and execution URL |

Database: Postgres (Supabase in the demo), tables `deadlines` and `sync_log`, see [`db/init/01_schema.sql`](db/init/01_schema.sql).

## Run it locally with Docker

Requirements: Docker with Docker Compose v2.

```bash
git clone https://github.com/exilonn/deadline-coach.git
cd deadline-coach
cp .env.example .env          # then edit .env: at least N8N_ENCRYPTION_KEY and POSTGRES_PASSWORD
docker compose up -d
docker compose ps             # postgres must show "healthy", n8n "running"
```

Open http://localhost:5678 and create the owner account. On its first start the postgres container also creates the
project database `deadline_coach` with its tables (from `db/init/`).

Data survives a restart because both services use named volumes (`postgres_data`, `n8n_data`):

```bash
docker compose down && docker compose up -d   # workflows and data are still there
```

### Import the workflows

```bash
docker compose exec n8n n8n import:workflow --separate --input=/workflows
```

Then, in n8n:

1. Create 3 credentials: **Telegram API** (bot token from @BotFather), **OpenRouter** (API key, free models),
   **Postgres** (host `postgres`, database `deadline_coach`, user and password from `.env`).
   Select them in the nodes that show a warning.
2. In `Deadline Coach – Moodle Sync`, node **Get Moodle calendar**: replace `<MOODLE_CALENDAR_URL>` with your own
   Moodle export link (Moodle → Calendar → Export calendar → Get calendar URL). It contains a private token: keep it out of Git.
3. In each workflow's **Settings**, set **Error workflow** to `Deadline Coach – Errors`.
4. The Telegram Trigger needs a public HTTPS URL: set `WEBHOOK_URL` in `.env` to a tunnel URL
   (e.g. `cloudflared tunnel --url http://localhost:5678`), then restart n8n.
5. Publish the five workflows.

> The live demo runs on n8n Cloud (same n8n version, 2.43.5) with Supabase as the database.
> The Docker setup above is the self-hosted equivalent. Tested on 22 October 2026 from a fresh clone:
> postgres healthy, project tables created, n8n `/healthz` 200, 5 workflows imported, still present after `down` / `up`.

## How to test

Each scheduled workflow has a manual trigger next to its schedule, so everything can be fired on demand.

| Send / do | Expected |
|---|---|
| `/help` | Usage message |
| `/dealines` | "Did you mean /deadlines?" |
| `/add CV final report 28/10 20:00` | ✅ Saved #N … Wed 28 Oct, 20:00 |
| Same message again | 👍 Already saved, no new row |
| Same title, new date | 📅 moved to …, reminders re-armed |
| `/add blabla` | "I couldn't find a deadline", nothing saved |
| `/deadlines`, `/done N`, `/plan` | List, confirmation, weekly plan |
| `/sync` (twice) | New Moodle deadlines, then "Nothing new" |
| Reminders → Execute workflow (twice) | Digest once, then nothing |
| Break the Moodle URL, then `/sync` | Error alert on Telegram with the execution link |

## Security

- No secret is stored in this repository: n8n exports only credential names and IDs, `.env` is git-ignored,
  and the Moodle calendar URL is replaced by a placeholder.
- `N8N_ENCRYPTION_KEY` comes from the environment; keep a copy, without it the stored credentials cannot be decrypted.

## Use of AI

An AI assistant helped design the workflows and draft the Code nodes and SQL queries. I built, tested and adjusted every
node myself in n8n.
