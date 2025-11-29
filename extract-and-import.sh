#!/bin/bash
set -e

# Script to extract and import MongoDB dump on remote server
# Usage: ./extract-and-import.sh dump.gz

if [ $# -lt 1 ]; then
    echo "Usage: $0 <dump_file.gz>"
    echo "Example: $0 dump.gz"
    exit 1
fi

DUMP_FILE="$1"
DUMP_DIR="mongo-init/dump"

if [ ! -f "$DUMP_FILE" ]; then
    echo "Error: Dump file '$DUMP_FILE' not found"
    exit 1
fi

echo "Extracting $DUMP_FILE..."
# Extract to temporary directory first
TEMP_DIR=$(mktemp -d)
tar -xzf "$DUMP_FILE" -C "$TEMP_DIR" || gunzip -c "$DUMP_FILE" | tar -x -C "$TEMP_DIR" 2>/dev/null || {
    echo "Trying alternative extraction method..."
    gunzip -c "$DUMP_FILE" > "$TEMP_DIR/dump.tar" 2>/dev/null && tar -xf "$TEMP_DIR/dump.tar" -C "$TEMP_DIR" || {
        echo "Error: Could not extract dump file. Please extract manually."
        exit 1
    }
}

# Find the actual dump directory (mongorestore format)
DUMP_CONTENT=$(find "$TEMP_DIR" -type d -name "*.bson" -o -type f -name "*.bson" | head -1)
if [ -z "$DUMP_CONTENT" ]; then
    echo "Error: Could not find BSON files in dump. Is this a valid MongoDB dump?"
    exit 1
fi

# Get the parent directory containing the BSON files
DUMP_SOURCE=$(dirname "$DUMP_CONTENT")
if [ -f "$DUMP_CONTENT" ]; then
    DUMP_SOURCE=$(dirname "$DUMP_SOURCE")
fi

echo "Found dump content in: $DUMP_SOURCE"
echo "Copying to $DUMP_DIR..."

# Create dump directory if it doesn't exist
mkdir -p "$DUMP_DIR"

# Copy dump content
cp -r "$DUMP_SOURCE"/* "$DUMP_DIR/" 2>/dev/null || cp -r "$DUMP_SOURCE"/. "$DUMP_DIR/" 2>/dev/null

# Cleanup
rm -rf "$TEMP_DIR"

echo "Dump extracted successfully to $DUMP_DIR"
echo ""
echo "To import the dump:"
echo "1. Make sure MongoDB is stopped: docker compose down"
echo "2. Remove existing data volume (if needed): docker volume rm platepus_mongo_data"
echo "3. Start MongoDB: docker compose up -d"
echo "   The dump will be imported automatically on first start"

