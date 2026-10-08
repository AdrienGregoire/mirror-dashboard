# Dashboard

Dashboard is a third-year full-stack web project at Epitech. It's a customizable dashboard where users subscribe to external services and display their data through widgets.

# Getting Started

The project is launched using Docker Compose. You do not need to install Elixir, Erlang, or Postgres locally.

## Prerequisites

- Docker installed on your machine.
- The Docker Compose plugin (verify with docker compose version)

## 1. Configuration

Copy the example file and fill in the values:

```bash
cp .env.example .env
```

Then edit `.env`.:*

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

Create the OAuth App in GitHub.

### External APIs

| Variable | Service | Where to get a key |
|----------|---------|--------------------|
| `FOOT_API` | [API-Football](https://www.api-football.com/) | API-Football |
| `TENNIS_API` | [Sportradar](https://developer.sportradar.com/) (tennis) | Sportradar |
| `BASKET_API` | [API-Basketball](https://api-sports.io/documentation/basketball/v1) | API-Sports |


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

## Projet structure

...

# License
Epitech.