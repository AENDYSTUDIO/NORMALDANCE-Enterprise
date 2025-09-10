#!/bin/bash
set -e

BACKUP_DIR="/backups"
DATE=$(date +%Y%m%d_%H%M%S)

# Database backup
pg_dump $DATABASE_URL > "$BACKUP_DIR/db_backup_$DATE.sql"
gzip "$BACKUP_DIR/db_backup_$DATE.sql"

# Upload to S3
aws s3 cp "$BACKUP_DIR/db_backup_$DATE.sql.gz" "s3://normaldance-backups/database/"

# Cleanup old backups (keep 30 days)
find $BACKUP_DIR -name "*.sql.gz" -mtime +30 -delete

echo "Backup completed: $DATE"