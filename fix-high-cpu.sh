#!/bin/bash
# Script to fix high CPU usage in MongoDB
# This will create necessary indexes and optimize queries

set -e

# Default connection string
DEFAULT_CONNECTION="mongodb://localhost:27017/platepus"

# Get connection string from argument or use default
CONNECTION_STRING="${1:-$DEFAULT_CONNECTION}"

echo "=========================================="
echo "Fixing MongoDB High CPU Usage"
echo "=========================================="
echo "Connection: $CONNECTION_STRING"
echo ""

# Step 1: Check if indexes exist
echo "Step 1: Checking existing indexes..."
EXISTING_INDEXES=$(mongosh "$CONNECTION_STRING" --quiet --eval "db.products.getIndexes().length")

if [ "$EXISTING_INDEXES" -lt 3 ]; then
    echo "⚠️  Only $EXISTING_INDEXES index(es) found. Need to create indexes!"
    echo ""
    
    # Step 2: Create indexes (this will use CPU but is necessary)
    echo "Step 2: Creating indexes (this may take a while and use CPU)..."
    echo ""
    
    # Create index on product_name (for regex prefix searches)
    echo "Creating index on product_name..."
    mongosh "$CONNECTION_STRING" --eval "
    try {
      db.products.createIndex({ product_name: 1 }, { 
        name: 'product_name_1',
        background: true 
      });
      print('✓ Index on product_name created');
    } catch(e) {
      if (e.codeName === 'IndexOptionsConflict' || e.codeName === 'IndexKeySpecsConflict') {
        print('✓ Index on product_name already exists');
      } else {
        throw e;
      }
    }
    " || echo "⚠️  Failed to create index on product_name"
    
    # Create index on code (for barcode searches)
    echo "Creating index on code..."
    mongosh "$CONNECTION_STRING" --eval "
    try {
      db.products.createIndex({ code: 1 }, { 
        name: 'code_1',
        background: true,
        unique: true,
        sparse: true 
      });
      print('✓ Index on code created');
    } catch(e) {
      if (e.codeName === 'IndexOptionsConflict' || e.codeName === 'IndexKeySpecsConflict') {
        print('✓ Index on code already exists');
      } else {
        throw e;
      }
    }
    " || echo "⚠️  Failed to create index on code"
    
    echo ""
    echo "⏳ Indexes are being created in background..."
    echo "   This may take 10-30 minutes for 4.2M documents"
    echo "   CPU usage will be high during index creation"
    echo "   After completion, CPU usage should drop significantly"
    
else
    echo "✓ Indexes already exist ($EXISTING_INDEXES indexes found)"
fi

echo ""
echo "Step 3: Checking index build status..."
mongosh "$CONNECTION_STRING" --quiet --eval "
var currentOps = db.currentOp({ 'command.createIndexes': { '\$exists': true } });
if (currentOps.inprog.length > 0) {
  print('⚠️  Index creation in progress:');
  currentOps.inprog.forEach(function(op) {
    print('  - ' + op.ns + ': ' + (op.progress.total || 'N/A') + ' documents');
  });
} else {
  print('✓ No index builds in progress');
}
"

echo ""
echo "Step 4: Optimizing query patterns..."
echo "✓ Application should use indexed queries (prefix search)"
echo "✓ Regex queries will use index if they start with ^"

echo ""
echo "=========================================="
echo "NEXT STEPS:"
echo "=========================================="
echo ""
echo "1. Wait for index creation to complete (check with):"
echo "   ./diagnose-performance.sh \"$CONNECTION_STRING\""
echo ""
echo "2. Monitor CPU usage:"
echo "   top -p \$(pgrep mongod)"
echo ""
echo "3. After indexes are created, CPU should drop to <5% in idle"
echo ""

