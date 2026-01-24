#!/bin/bash
# Daily PostgreSQL backup script

BACKUP_DIR="/backups/aquabill"
DB_NAME="aquabill"
DB_USER="aquabill"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
BACKUP_FILE="$BACKUP_DIR/aquabill_${TIMESTAMP}.sql.gz"

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Perform backup
pg_dump -U "$DB_USER" "$DB_NAME" | gzip > "$BACKUP_FILE"

# Keep only last 30 days of backups
find "$BACKUP_DIR" -type f -name "aquabill_*.sql.gz" -mtime +30 -delete

echo "Backup completed: $BACKUP_FILE"
