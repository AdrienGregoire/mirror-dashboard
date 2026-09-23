# Dashboard

Dashboard is a third-year full-stack web project at Epitech.

# Getting Started
The project is launched using Docker Compose. You do not need to install Elixir, Erlang, or Postgres locally.

## Prerequisites

- Docker installed on your machine.
- The Docker Compose plugin (verify with docker compose version)

### 1. Configuration

Copy the example file and fill in the values:

```bash
cp .env.example .env
```

Then edit `.env` and replace `SECRET_KEY_BASE` with a real value generated using:

```bash
openssl rand -base64 48
```

and `ENCRYPTION_KEY` (used to encrypt the credentials and tokens of the services users subscribe to) with:

```bash
openssl rand -base64 32
```

(`POSTGRES_USER`, `POSTGRES_PASSWORD`, and `POSTGRES_DB` can be left as is locally, or customized.)

### 2. Building the image

```bash
docker compose build
```

### 3. Launching

```bash
docker compose up
```

The application is available at [http://localhost:8080](http://localhost:8080).

### 4. Stopping the application

```bash
docker compose down
```

To remove everything, including persisted Postgres data:

```bash
docker compose down -v
```

# License
Epitech.