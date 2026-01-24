#!/bin/bash
# PostgreSQL restore script

if [ $# -ne 1 ]; then
    echo "Usage: $0 <backup_file>"
    echo "Example: $0 aquabill_20240101_000000.sql.gz"
    exit 1
fi

BACKUP_FILE="$1"
DB_NAME="aquabill"
DB_USER="aquabill"

if [ ! -f "$BACKUP_FILE" ]; then
    echo "Error: Backup file not found: $BACKUP_FILE"
    exit 1
fi

# Drop existing database (careful!)
echo "Dropping existing database..."
dropdb -U "$DB_USER" "$DB_NAME"

# Create new database
echo "Creating new database..."
createdb -U "$DB_USER" "$DB_NAME"

# Restore from backup
echo "Restoring from backup..."
gunzip -c "$BACKUP_FILE" | psql -U "$DB_USER" "$DB_NAME"

echo "Restore completed!"
