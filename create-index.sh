#!/bin/bash
# Script to create MongoDB indexes for faster product search
# Usage: ./create-index.sh [mongodb-connection-string]

set -e

# Default connection string
DEFAULT_CONNECTION="mongodb://localhost:27017/platepus"

# Get connection string from argument or use default
CONNECTION_STRING="${1:-$DEFAULT_CONNECTION}"

echo "Creating indexes for product search..."
echo "Connection: $CONNECTION_STRING"
echo ""

# Create text index for full-text search (fastest option)
# Note: MongoDB text search works best with English, but regex fallback supports all languages
echo "1. Creating text index on product_name..."
mongosh "$CONNECTION_STRING" --eval "
db.products.createIndex({ product_name: 'text' }, { 
  name: 'product_name_text',
  background: true,
  default_language: 'none'  // Disable language-specific stemming for better multi-language support
})
" || echo "Text index creation failed or already exists"

# Create regular index for prefix searches (backup option)
echo "2. Creating regular index on product_name..."
mongosh "$CONNECTION_STRING" --eval "
db.products.createIndex({ product_name: 1 }, { 
  name: 'product_name_1',
  background: true 
})
" || echo "Regular index creation failed or already exists"

# Create index on code field (for barcode searches)
echo "3. Creating index on code field..."
mongosh "$CONNECTION_STRING" --eval "
db.products.createIndex({ code: 1 }, { 
  name: 'code_1',
  background: true,
  unique: true,
  sparse: true 
})
" || echo "Code index creation failed or already exists"

echo ""
echo "Checking existing indexes..."
mongosh "$CONNECTION_STRING" --eval "db.products.getIndexes()"

echo ""
echo "Done! Indexes should improve search performance significantly."

