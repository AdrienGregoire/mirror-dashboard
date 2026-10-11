# Dashboard: Proof of Concept

Before starting the full development, this proof of concept checks that our
chosen stack works: **Elixir / Phoenix** serving a small web app with
registration and a dashboard page.

The reasoning behind the stack is detailed in [Technology choices](../Technology-choices.md).

## What the POC contains

| Page | Route | Description |
|------|-------|-------------|
| Home | `GET /` | Landing page with *Sign up* and *Log in* buttons |
| Registration | `GET /register`, `POST /register` | Creates an account (email + password) and stores the user in the session |
| Dashboard | `GET /dashboard` | Shows the logged-in email and the widget grid. Redirects to `/register` if no user is in the session |

## Stack

| Layer | Choice |
|-------|--------|
| Backend / frontend | Elixir `1.17`, Phoenix `1.8` |
| HTTP server | Bandit |
| HTTP client | Req |
| Storage | ETS (in memory, no database yet) |

# Getting started

## Prerequisites

- Elixir 1.17 or newer (and Erlang/OTP).

## Run

```bash
cd poc
mix setup
mix phx.server
```

The app is available at [http://localhost:4000](http://localhost:4000).

No `.env` file is needed: the POC uses no secret and no external service.

## Project structure

```
poc/
├── config/        # Phoenix configuration (dev, test, prod, runtime)
├── lib/
│   ├── backend/   # application, ETS user store, mailer
│   └── frontend/  # router, controllers, templates, layouts
├── priv/          # static assets (css, favicon), gettext
├── test/          # ExUnit tests
└── mix.exs
```

## Running the tests

```bash
cd poc
mix test
```

# License
Epitech.
