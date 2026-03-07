# Product Service

Node/Express service for product catalog operations.

## Prerequisites
- Node.js 18+
- PostgreSQL

## Setup
```bash
npm install
npm start
```

## Environment Variables
- `DB_HOST` (default: `localhost`)
- `DB_NAME` (default: `ecommerce`)
- `DB_USER` (default: `postgres`)
- `DB_PASSWORD` (default: `password`)
- `PORT` (default: `3001`)

## Endpoints
- `GET /health`
- `GET /products`
- `GET /products/:id`
- `POST /products`

## Development Workflow (Git Flow)
1. Create a feature branch from `develop`: `feature/<name>`
2. Commit changes on the feature branch
3. Open a PR into `develop`
4. Create a release branch from `develop`: `release/<version>`
5. Merge `release/<version>` into `main` and tag the release
6. Merge `main` back into `develop`
7. For urgent fixes, create `hotfix/<version>` from `main`, then merge into `main` and `develop`
