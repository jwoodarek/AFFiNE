#!/bin/sh
set -e

echo "🚀 Starting AFFiNE on Railway..."

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
until node -e "
const { Client } = require('pg');
const client = new Client({ connectionString: process.env.DATABASE_URL });
client.connect().then(() => { client.end(); process.exit(0); }).catch(() => process.exit(1));
" 2>/dev/null; do
  echo "   Database not ready, retrying in 2s..."
  sleep 2
done
echo "✅ Database connected!"

# Run migrations/predeploy script
echo "📦 Running database migrations..."
node ./scripts/self-host-predeploy.js

echo "🎉 Starting AFFiNE server..."
exec node ./dist/index.js
