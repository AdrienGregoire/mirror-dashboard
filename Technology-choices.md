# Technology choices

Ce document présente nos choix techniques pour notre projet Dashboard. Ces choix couvrent trois parties : le Backend, le Frontend et la Base de données. Nos choix sont basés sur des comparaisons avec d'autres stacks existantes.

## Backend

| Option | Écosystème | Performances | Maintenabilité |
| :--- | :--- | :--- | :--- |
| **Elixir/Phoenix** | Bon mais plus restreint que Node ou Python | BEAM/OTP conçu pour ça | Restart auto des process en erreur |
| **Node.js/Express** | npm | Event loop mono-thread | Un crash tue tout le process |
| **Python/Django** | Packages énormes | GIL, limité | Dépend du serveur |

## Frontend

| Option | Complexité de l'UI | Vitesse de développement | UI & Réactivité |
| :--- | :--- | :--- | :--- |
| **Phoenix LiveView** | CSS pur | ??? | ??? |
| **React / Next.js** | Support websockets/state temps réel | Concurrent rendering | Error boundaries |
| **Tailwind CSS** | Bien documenté | Beaucoup de themes/plugins | Stable |

## Database

| Option | Modélisation | Performance | Écosystème |
| :--- | :--- | :--- | :--- |
| **Ecto et PostgreSQL** | ??? | ??? | ??? |
| **MySQL** | ??? | ??? | ??? |
| **MongoDB** | ??? | ??? | ??? |
