#!/bin/bash
# AquaBill deployment script

set -e

REPO_DIR="/opt/aquabill"
VENV_DIR="$REPO_DIR/venv"

echo "=== AquaBill Deployment ==="

# Pull latest code
echo "Pulling latest code..."
cd "$REPO_DIR"
git pull origin main

# Update dependencies
echo "Installing dependencies..."
source "$VENV_DIR/bin/activate"
pip install -r backend/requirements.txt

# Run migrations
echo "Running database migrations..."
cd "$REPO_DIR/backend"
alembic upgrade head

# Restart services
echo "Restarting services..."
sudo systemctl restart aquabill-api
sudo systemctl restart aquabill-worker

echo "=== Deployment completed ==="
