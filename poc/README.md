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
| Dashboard | `GET /dashboard` | Shows the logged-in email and the widget grid (Football, Basketball, Tennis). Redirects to `/register` if no user is in the session |
