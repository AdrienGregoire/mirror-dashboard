# Dashboard

Dashboard is a third-year full-stack web project at Epitech. It's a customizable dashboard where users subscribe to external services and display their data through widgets.

## Features

* **Unified Authentication:** Standard account creation via email or quick sign-in via GitHub OAuth.
* **Customizable dashboard:** Add, configure, and freely arrange widgets using a *drag-and-drop* interface.
* **Automatic Update:** Customizable refresh rate for each widget individually.
* **Integrated sports services:**
  * *Football:* League Standings, Top Scorers.
  * *Basketball:* Standings, detailed statistics by team.
  * *Tennis:* ATP/WTA Rankings, Upcoming Matches, Ongoing Tournaments.
* **Interface Customization:** Multilingual support (French/English) and a *Liquid Glass* design.
* **Security:** Encryption of sensitive data and access tokens in the database.

# Getting Started

The project is launched using Docker Compose. You do not need to install Elixir, Erlang, or Postgres locally.

## Prerequisites

- Docker installed on your machine.
- The Docker Compose plugin (verify with `docker compose version`)

## 1. Configuration

Copy the example file and fill in the values:

```bash
cp .env.example .env
```

Then edit `.env`:

### Application

| Variable | Description |
|----------|-------------|
| `SECRET_KEY_BASE` | Phoenix secret. Generate it with `openssl rand -base64 48` |
| `ENCRYPTION_KEY` | Encrypts the credentials and tokens of the services users subscribe to. Generate it with `openssl rand -base64 32` |

### Database

`POSTGRES_USER`, `POSTGRES_PASSWORD` and `POSTGRES_DB` can be left as is
locally, or customized.

### GitHub OAuth

| Variable | Description |
|----------|-------------|
| `GITHUB_CLIENT_ID` | Client ID of your GitHub OAuth App |
| `GITHUB_CLIENT_SECRET` | Client secret of your GitHub OAuth App |

Create an OAuth App in GitHub (*Settings → Developer settings → OAuth Apps → New OAuth App*) with:

- **Homepage URL**: `http://localhost:4000`
- **Authorization callback URL**: `http://localhost:4000/auth/github/callback`

Then copy the Client ID and a generated Client secret into your `.env`.

### External APIs

| Variable | Service |
|----------|---------|
| `FOOT_API` | [API-Football](https://www.api-football.com/) |
| `TENNIS_API` | [Sportradar](https://developer.sportradar.com/) (tennis) |
| `BASKET_API` | [API-Basketball](https://api-sports.io/documentation/basketball/v1) |


## 2. Build

```bash
docker compose build
```

## 3. Run

```bash
docker compose up
```

The application is available at [http://localhost:4000](http://localhost:4000).

## 4. Stop

```bash
docker compose down
```

To remove everything, including persisted Postgres data:

```bash
docker compose down -v
```

# Technical overview

## Stack

- **Backend / frontend**: Elixir, Phoenix
- **Database**: PostgreSQL & Ecto
- **Deployment**: Docker Compose

The reasoning behind these choices is detailed in [Technology choices](Technology-choices.md).

## Project structure

```
.
├── lib/
│   ├── backend/      # business logic: accounts, services, widgets engine
│   └── frontend/     # Phoenix web layer: router, controllers, templates
├── priv/             # migrations
├── test/             # ExUnit tests
├── poc/              # proofs of concept for technology choices
├── docker-compose.yml
├── Dockerfile
└── .env.example
```

## Services and widgets

| Service | Widgets |
|---------|---------|
| Football | standings, top scorers, nothing |
| Basketball | standings, team stat, nothing |
| Tennis | player ranking, next match, current events |

## Running the tests

```bash
docker compose run --rm app mix precommit
```

## Running the load tests
```bash
mix run load_tests/load_test.exs
mix run load_tests/load_test_login.exs
```

# License
Epitech.
