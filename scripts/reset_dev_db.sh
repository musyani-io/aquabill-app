#!/bin/bash
# Reset development database

echo "=== AquaBill Database Reset ==="

# Remove existing containers and volumes
echo "Removing containers and volumes..."
docker-compose down -v

# Start fresh containers
echo "Starting fresh containers..."
docker-compose up -d

# Wait for database to be ready
echo "Waiting for database..."
sleep 10

# Run migrations
echo "Running migrations..."
docker-compose exec -T backend alembic upgrade head

# Seed demo data
echo "Seeding demo data..."
docker-compose exec -T backend python scripts/seed_demo_data.py

echo "✓ Database reset complete!"
echo ""
echo "Demo credentials:"
echo "  Admin:      username=admin, password=admin123"
echo "  Collector:  username=collector1, password=collector123"
