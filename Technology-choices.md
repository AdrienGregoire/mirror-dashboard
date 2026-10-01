# Technology choices

Ce document présente nos choix techniques pour notre projet Dashboard. Ces choix couvrent trois parties : le Backend, le Frontend et la Base de données. Nos choix sont basés sur des comparaisons avec d'autres stacks existantes.

# Besoins du projet
Les choix ci-dessous sont basés sur ce que doit faire Dashboard:
- Données en temps réel
- UI interactive
- Services externes
- Comptes

## Backend

| Option | Écosystème | Performances | Maintenabilité |
| :--- | :--- | :--- | :--- |
| **Elixir/Phoenix** | Bon mais plus restreint que Node ou Python | BEAM/OTP conçu pour ça | Restart auto des process en erreur |
| **Node.js/Express** | npm | Event loop mono-thread | Un crash tue tout le process |
| **Python/Django** | Packages énormes | GIL, limité | Dépend du serveur |

## Frontend

| Option | Complexité de l'UI | Vitesse de développement | UI & Réactivité |
| :--- | :--- | :--- | :--- |
| **Phoenix LiveView** | CSS pur | un seul langage | chaque interaction passe par un aller-retour serveur |
| **React / Next.js** | Support websockets/state temps réel | Concurrent rendering | Error boundaries |
| **Tailwind CSS** | Bien documenté | Beaucoup de themes/plugins | Stable |

## Database

| Option | Modélisation | Performance | Écosystème |
| :--- | :--- | :--- | :--- |
| **Ecto et PostgreSQL** | Relationnelle avec clés étrangères | Très bonnes en lecture/écriture | ??? |
| **MySQL** | Relationnelle | Très bonnes en lecture simple | ??? |
| **MongoDB** | les relations sont à gérer dans le code | Très bonnes | ??? |

## Résumé
 
| Couche | Choix | Raison principale |
| :--- | :--- | :--- |
| Backend | Elixir / Phoenix | Rafraîchissement et temps réel avec GenServer, tolérance aux pannes native |
| Frontend | Phoenix LiveView + Tailwind CSS | Un seul langage et une seule base de code |
| Database | PostgreSQL + Ecto | Données relationnelles et jsonb pour la configuration des widgets, intégration native avec Ecto |
