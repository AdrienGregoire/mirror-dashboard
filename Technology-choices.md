# Technology choices

This document outlines our technical choices for the Dashboard project. These choices cover three areas: the backend, the frontend, and the database. Our choices are based on comparisons with other existing technology stacks.

## Project Requirements
The choices below are based on what the Dashboard needs to do:
- Real-time data
- Interactive UI
- External services
- Accounts

## Backend

| Option | Ecosystem | Performance | Maintainability |
| :--- | :--- | :--- | :--- |
| **Elixir/Phoenix** | Good but more limited than Node or Python | BEAM/OTP designed for this | Automatic restart of processes that encounter errors |
| **Node.js/Express** | npm | Single-threaded event loop | A crash kills the entire process |
| **Python/Django** | Huge packages | GIL, limited | Depends on the server |

### Our Choice: Elixir / Phoenix
The dashboard must refresh numerous widgets at different intervals and send the results to users, which aligns with the OTP model: a GenServer schedules the refreshes, and PubSub broadcasts the updates. If a call to an external API fails, only the affected process restarts.

## Frontend

| Option | UI Complexity | Development Speed | UI & Responsiveness |
| :--- | :--- | :--- | :--- |
| **Phoenix LiveView** | Pure CSS | Single language | Every interaction requires a round trip to the server |
| **React / Next.js** | WebSockets/real-time state support | Concurrent rendering | Error boundaries |
| **Tailwind CSS** | Well-documented | Many themes/plugins | Stable |

### Our Choice: Phoenix LiveView
The page state is managed on the server side, so widget updates are delivered to the browser without requiring a WebSocket layer or an API between the front end and the back end. Using a single language saves a lot of development time. JavaScript is limited to cases where it’s useful, such as drag-and-drop in the grid, and Tailwind CSS handles the styling.

## Database

| Option | Modeling | Performance | Écosystem |
| :--- | :--- | :--- | :--- |
| **Ecto and PostgreSQL** | Relational with foreign keys | Very good read/write performance | Official Docker image |
| **MySQL** | Relational | Very good for simple reads | Supported by Ecto (MyXQL) but less common in the Phoenix community |
| **MongoDB** | Relationships must be managed in the code | Very good | No official Ecto adapter, only community ones |

### Our Choice: Ecto & PostgreSQL
Our data is interconnected (users, subscriptions, widgets), and foreign keys ensure that no widget remains orphaned. Ecto integrates natively with PostgreSQL for migrations and form validation.

## Summary

| Layer | Choice | Main reason |
| :--- | :--- | :--- |
| Backend | Elixir / Phoenix | Refresh and real-time capabilities with GenServer, native fault tolerance |
| Frontend | Phoenix LiveView + Tailwind CSS | A single language and a single codebase |
| Database | PostgreSQL + Ecto | Relational data and jsonb for widget configuration, native integration with Ecto |
