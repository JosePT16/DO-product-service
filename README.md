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

