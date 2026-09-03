#!/bin/bash
set -e

BACKUP_DIR="/tmp"
DATE=$(date +%Y-%m-%d_%H-%M-%S)
FILE_NAME="postgres_backup_$DATE.sql.gz"
S3_BUCKET="s3://fortress_db_backups-narek-2026"

sudo -u postgres pg_dumpall | gzip > $BACKUP_DIR/$FILE_NAME
aws s3 cp $BACKUP_DIR/$FILE_NAME $S3_BUCKET/$FILE_NAME
rm $BACKUP_DIR/$FILE_NAME
