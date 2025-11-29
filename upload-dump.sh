#!/bin/bash
set -e

# Script to upload MongoDB dump to remote server
# Usage: ./upload-dump.sh user@host:/path/to/platepus-db/mongo-init/dump

if [ $# -lt 2 ]; then
    echo "Usage: $0 <dump_file.gz> <user@host:/remote/path>"
    echo "Example: $0 dump.gz user@example.com:/opt/platepus-db/mongo-init/dump/"
    exit 1
fi

DUMP_FILE="$1"
REMOTE_PATH="$2"

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "Uploading $DUMP_FILE to $REMOTE_PATH..."
echo "This may take a while for large files..."

# Upload the compressed dump
scp "$DUMP_FILE" "$REMOTE_PATH/"

echo "Upload complete!"
echo ""
echo "Next steps on remote server:"
echo "1. SSH to the server: ssh ${REMOTE_PATH%%:*}"
echo "2. Navigate to: ${REMOTE_PATH#*:}"
echo "3. Extract the dump: gunzip $(basename $DUMP_FILE)"
echo "4. Or use the extract-and-import.sh script"

