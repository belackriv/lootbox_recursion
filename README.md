# Lootbox Recursion

A loot-box crafting and inventory management game built with **Rails 8.1**, **Vue 3**, **Inertia.js**, and **PostgreSQL**. Players scavenge for raw materials (wood and iron), craft loot boxes, open them for randomised rewards, and manage a slot-based inventory — all updated in real time over Action Cable.

---

## Table of Contents

- [Features](#features)
- [Tech Stack](#tech-stack)
- [Prerequisites](#prerequisites)
- [Getting Started](#getting-started)
  - [Dev Container (Recommended)](#dev-container-recommended)
  - [Manual Setup](#manual-setup)
- [Running the Application](#running-the-application)
- [Project Structure](#project-structure)
- [Game Mechanics](#game-mechanics)
  - [Player Actions](#player-actions)
  - [Inventory System](#inventory-system)
  - [Loot Tables](#loot-tables)
- [Testing](#testing)
  - [Ruby Tests (Minitest)](#ruby-tests-minitest)
  - [Frontend Tests (Vitest)](#frontend-tests-vitest)
- [CI / CD](#ci--cd)
- [Deployment](#deployment)
- [Environment Variables](#environment-variables)
- [License](#license)

---

## Features

- **Scavenge** — gather wood and iron with randomised yields.
- **Craft** — spend 50 wood + 50 iron to create a loot box.
- **Open (Use)** — open a loot box to receive randomised loot from configurable loot tables with modifier support.
- **Sort Inventory** — auto-sort and compress inventory stacks.
- **Real-time updates** — inventory mutations and action-state changes are broadcast instantly via Action Cable (`PlayerInventoryChannel` / `PlayerActionsChannel`).
- **Slot-based inventory** — 50-slot inventory with per-item stack sizes, managed through an `InventoryItemMutation` ledger.
- **Action cooldowns & cast times** — actions are queued through Solid Queue and executed after a configurable cast time.
- **Authentication** — built-in email/password auth with `has_secure_password` and session management.

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Backend** | Ruby 3.4.7 · Rails 8.1 · Puma |
| **Frontend** | Vue 3 · TypeScript · Pinia · Inertia.js (`@inertiajs/vue3`) |
| **Build** | Vite (via `vite_rails`) · Propshaft |
| **Database** | PostgreSQL 18 |
| **Real-time** | Action Cable (Solid Cable adapter) |
| **Background Jobs** | Solid Queue |
| **Caching** | Solid Cache |
| **Testing** | Minitest · Capybara · Selenium · Vitest · Vue Test Utils |
| **CI** | GitHub Actions |
| **Deployment** | Kamal · Docker · Thruster |

---

## Prerequisites

- **Ruby** 3.4.7
- **Node.js** 20+
- **npm**
- **PostgreSQL** 16+
- **Docker & Docker Compose** (for the dev container or production builds)

---

## Getting Started

### Dev Container (Recommended)

The project ships with a full Dev Container configuration (`.devcontainer/`) that provisions:

- A Rails application container
- Separate PostgreSQL instances for **development** and **test**
- A Selenium container for system tests

1. Open the project in an editor that supports Dev Containers (e.g. VS Code, Zed, GitHub Codespaces).
2. When prompted, **Reopen in Container**.
3. The `postCreateCommand` will automatically run `bin/setup --skip-server`, which:
   - Installs Ruby gems (`bundle install`)
   - Installs npm packages (`npm install`)
   - Prepares the database (`bin/rails db:prepare`)
   - Clears old logs and temp files

### Manual Setup

```sh
# Clone the repository
git clone <repository-url>
cd lootbox_recursion

# Install dependencies
bundle install
npm install

# Configure the database
# Edit config/database.yml if your local Postgres credentials differ from the defaults
bin/rails db:prepare

# (Optional) Reset the database with seed data
bin/rails db:reset
```

---

## Running the Application

The development server runs both Rails and Vite concurrently using a Procfile:

```sh
bin/dev
```

This starts:

| Process | Command | Default Port |
|---|---|---|
| **Vite** dev server | `bin/vite dev` | 3036 |
| **Rails** server | `bin/rails s` | 3000 |

Visit **http://localhost:3000** to use the app. The Vite dev server on port 3036 handles hot module replacement for the Vue frontend.

> `bin/dev` uses [overmind](https://github.com/DarthSim/overmind), [hivemind](https://github.com/DarthSim/hivemind), or [foreman](https://github.com/ddollar/foreman) — whichever is available.

---

## Project Structure

```
lootbox_recursion/
├── app/
│   ├── channels/            # Action Cable channels
│   │   ├── player_actions_channel.rb
│   │   └── player_inventory_channel.rb
│   ├── controllers/         # Rails controllers (Inertia-based)
│   ├── data/                # YAML configuration
│   │   ├── loot_tables.yml  # Loot table definitions
│   │   └── player_actions.yml  # Action definitions (scavenge, craft, use, sort)
│   ├── frontend/            # Vue 3 / TypeScript frontend
│   │   ├── entrypoints/     # Vite entry points
│   │   ├── Layouts/         # Inertia layout components
│   │   ├── Pages/           # Inertia page components
│   │   │   ├── Auth/        # Login / sign-up pages
│   │   │   └── Index/       # Main game interface
│   │   ├── Shared/          # Reusable Vue components
│   │   ├── Sprites/         # Game sprites / assets
│   │   ├── channels/        # JS Action Cable consumers
│   │   ├── services/        # Frontend service layer
│   │   ├── store/           # Pinia stores
│   │   ├── tests/           # Vitest specs
│   │   └── types/           # TypeScript type definitions
│   ├── jobs/                # Background jobs (Solid Queue)
│   │   ├── apply_inventory_item_mutations_job.rb
│   │   └── perform_player_action_job.rb
│   ├── models/              # ActiveRecord models & POROs
│   └── views/               # Server-rendered views (minimal, Inertia root)
├── config/
│   ├── database.yml
│   ├── routes.rb
│   └── vite.json
├── db/
│   ├── migrate/             # Database migrations
│   └── schema.rb
├── documentation/           # Feature documentation
├── test/                    # Minitest test suite
├── .devcontainer/           # Dev Container configuration
├── .github/workflows/       # GitHub Actions CI
├── Dockerfile               # Production Docker image
├── Gemfile
├── package.json
├── Procfile.dev
├── vite.config.ts
└── vitest.config.ts
```

---

## Game Mechanics

### Player Actions

Actions are defined in `app/data/player_actions.yml` and managed by the `PlayerAction` model. Each action supports:

| Property | Description |
|---|---|
| `cooldown` | Seconds before the action can be used again |
| `cast_time` | Seconds of delay before the action executes (via Solid Queue) |
| `requirements` | Conditions that must be met (e.g. minimum item counts) |
| `reveal_requirements` | Conditions for the action to appear in the UI |
| `choices` | Dynamic options computed at runtime (e.g. craftable items) |

**Available actions:**

- **Scavenge** — No requirements. Awards 25–35 random wood or iron.
- **Craft** — Requires 50+ wood and 50+ iron. Consumes materials and produces a Loot Box.
- **Use** — Requires a Loot Box in inventory. Opens the selected loot box.
- **Sort Inventory** — Consolidates stacks and sorts items alphabetically.

### Inventory System

- Each user has an `Entity` with **50 inventory slots**.
- Items are subclasses of `InventoryItem` using Single Table Inheritance (STI):
  - `WoodInventoryItem` — stack size 100
  - `IronInventoryItem` — stack size 100
  - `LootBoxInventoryItem` — stack size 1 (non-stackable)
- Changes are tracked through `InventoryItemMutation` records with a `delta` value.
- Mutations are broadcast to the frontend over `PlayerInventoryChannel` for real-time UI updates.

### Loot Tables

Loot tables are configured in `app/data/loot_tables.yml`. Each table defines:

- **Rolls** — min/max number of items rolled per opening.
- **Entries** — weighted item types with min/max count ranges.

Loot box types (`WoodLootBox`, `IronLootBox`) each reference their own table. Loot box modifiers (`LootBoxModifier`) can be chained to alter roll outcomes.

---

## Testing

### Ruby Tests (Minitest)

```sh
# Run the full test suite
bin/rails test

# Run system tests (requires Selenium / Chrome)
bin/rails test:system

# Run a specific test file
bin/rails test test/models/user_test.rb
```

### Frontend Tests (Vitest)

Frontend tests live in `app/frontend/tests/` and run in a jsdom environment:

```sh
# Run all frontend tests
npm test

# Run in watch mode
npx vitest --watch
```

### Type Checking

```sh
npm run check
```

---

## CI / CD

GitHub Actions (`.github/workflows/ci.yml`) runs on every push to `main` and on pull requests:

| Job | Description |
|---|---|
| `scan_ruby` | Brakeman (static security analysis) + bundler-audit (gem vulnerability scan) |
| `scan_js` | Importmap audit for JS dependency vulnerabilities |
| `lint` | RuboCop style enforcement |
| `test` | Minitest unit/integration tests against a PostgreSQL service container |
| `system-test` | Capybara system tests with headless Chrome |

---

## Deployment

The application is configured for deployment with [Kamal](https://kamal-deploy.org/). A production-ready `Dockerfile` is included that:

1. Installs gems and precompiles bootsnap caches.
2. Builds and precompiles Vite assets.
3. Runs behind [Thruster](https://github.com/basecamp/thruster) for HTTP caching, compression, and X-Sendfile acceleration.

```sh
# Build the Docker image
docker build -t lootbox_recursion .

# Run the container
docker run -d -p 80:80 \
  -e RAILS_MASTER_KEY=<value from config/master.key> \
  -e PRODUCTION_DATABASE_USER=<db_user> \
  -e PRODUCTION_DATABASE_PASSWORD=<db_password> \
  -e PRODUCTION_DATABASE_HOST=<db_host> \
  --name lootbox_recursion lootbox_recursion
```

See `config/deploy.yml` for the full Kamal deployment configuration.

---

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `DATABASE_HOST` | PostgreSQL host | `db_dev` |
| `DATABASE_USER` | PostgreSQL username | `dev_user` |
| `DATABASE_PASSWORD` | PostgreSQL password | `dev_pass` |
| `DATABASE_NAME` | PostgreSQL database name | `lootbox_recursion_dev` |
| `RAILS_MASTER_KEY` | Decrypts `config/credentials.yml.enc` | — |
| `RAILS_ENV` | Rails environment (`development`, `test`, `production`) | `development` |
| `PRODUCTION_DATABASE_USER` | Production DB username | — |
| `PRODUCTION_DATABASE_PASSWORD` | Production DB password | — |
| `PRODUCTION_DATABASE_HOST` | Production DB host | — |
| `PORT` | Web server port | `3000` |

---

## License

This is a private project. All rights reserved.