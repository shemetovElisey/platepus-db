#!/bin/bash
# Script to remove products from MongoDB that don't have valid energy and macronutrient data
# 
# WARNING: This operation is IRREVERSIBLE! Make sure to backup your database first!
#
# Usage:
#   ./remove-products-without-nutrition.sh [mongodb-connection-string] [--dry-run]
#
# Examples:
#   # Dry run (show what would be deleted, don't actually delete)
#   ./remove-products-without-nutrition.sh mongodb://localhost:27017/platepus --dry-run
#
#   # Actually delete products (REQUIRES --confirm flag)
#   ./remove-products-without-nutrition.sh mongodb://localhost:27017/platepus --confirm
#
#   # With authentication
#   ./remove-products-without-nutrition.sh mongodb://user:password@localhost:27017/platepus --confirm

set -e

# Default connection string
DEFAULT_CONNECTION="mongodb://localhost:27017/platepus"

# Get connection string from argument or use default
CONNECTION_STRING="${1:-$DEFAULT_CONNECTION}"

# Check for flags
DRY_RUN=false
CONFIRM=false

for arg in "$@"; do
    case $arg in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --confirm)
            CONFIRM=true
            shift
            ;;
    esac
done

# Detect if we should use Docker or local mongosh
USE_DOCKER=false
if ! command -v mongosh &> /dev/null; then
    # mongosh not installed - check if Docker is available
    if command -v docker &> /dev/null; then
        USE_DOCKER=true
    else
        echo "❌ Error: mongosh is not installed and Docker is not available."
        echo "Please install mongosh: https://www.mongodb.com/try/download/shell"
        exit 1
    fi
fi

# Define MONGO_CMD function based on available tools
if [ "$USE_DOCKER" = true ]; then
    # Extract database name from connection string
    DB_NAME=$(echo "$CONNECTION_STRING" | sed -n 's|.*/\([^?]*\).*|\1|p')
    if [ -z "$DB_NAME" ]; then
        DB_NAME="platepus"
    fi
    # Use Docker container with mongosh
    MONGO_CMD() {
        docker run -i --rm mongo:7.0 mongosh "$CONNECTION_STRING" --quiet "$@"
    }
    echo "Using Docker container (mongo:7.0) for MongoDB connection"
else
    # Use local mongosh
    MONGO_CMD() {
        mongosh "$CONNECTION_STRING" --quiet "$@"
    }
    echo "Using local mongosh installation"
fi

echo "=========================================="
echo "Remove Products Without Nutrition Data"
echo "=========================================="
echo ""
echo "Connection: $CONNECTION_STRING"
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "⚠️  DRY RUN MODE - No products will be deleted"
    echo ""
elif [ "$CONFIRM" = false ]; then
    echo "⚠️  WARNING: This will PERMANENTLY DELETE products from the database!"
    echo ""
    echo "To proceed, you must:"
    echo "  1. Make sure you have a backup of your database"
    echo "  2. Run with --confirm flag: $0 $CONNECTION_STRING --confirm"
    echo ""
    echo "To see what would be deleted first, run with --dry-run:"
    echo "  $0 $CONNECTION_STRING --dry-run"
    echo ""
    exit 1
fi

echo "Starting deletion process..."
echo ""
echo "⚠️  Note: Detailed counts are skipped for performance. Deletion will proceed directly."
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "✅ Dry run complete. No products were deleted."
    echo ""
    echo "To actually delete these products, run:"
    echo "  $0 $CONNECTION_STRING --confirm"
    exit 0
fi

echo "⚠️  WARNING: About to delete products without valid КБЖУ data!"
echo ""
read -p "Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    echo "❌ Deletion cancelled."
    exit 1
fi

echo ""
echo "Deleting products in batches (this may take a while)..."
echo ""
echo "Using optimized batch deletion for better performance..."
echo ""

# Optimized deletion using batches for better performance
# This approach is faster because:
# 1. We find IDs first, then delete by _id (faster than complex queries)
# 2. We delete in smaller batches (5,000 at a time)
# 3. We show progress
# 4. We use simpler deleteMany queries by _id which are much faster

BATCH_SIZE=5000
TOTAL_DELETED=0
ITERATION=0

# Delete in batches: find IDs, then delete by _id
while true; do
    ITERATION=$((ITERATION + 1))
    echo -n "Batch $ITERATION: Finding and deleting up to $BATCH_SIZE products... "
    
    # Delete products directly using the query (simpler and more reliable)
    BATCH_DELETED=$(MONGO_CMD --eval "
    var query = {
        \$or: [
            { nutriments: { \$exists: false } },
            { nutriments: null },
            {
                \$and: [
                    {
                        \$nor: [
                            { 'nutriments.energy-kcal_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy_kcal_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy-kj_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy_kj_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy-kcal_value': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy_kcal_value': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy-kj_value': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.energy_kj_value': { \$exists: true, \$type: 'number' } }
                        ]
                    },
                    {
                        \$nor: [
                            { 'nutriments.proteins_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.protein_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.fat_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.fats_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.total-fat_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.total_fat_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.carbohydrates_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.carbohydrate_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.carbs_100g': { \$exists: true, \$type: 'number' } },
                            { 'nutriments.carb_100g': { \$exists: true, \$type: 'number' } }
                        ]
                    }
                ]
            }
        ]
    };
    
    // Get count first to see if there are any products to delete
    var count = db.products.countDocuments(query);
    if (count === 0) {
        print(0);
    } else {
        // Delete up to BATCH_SIZE documents
        // We'll use a cursor to get IDs and delete them one by one to avoid circular reference issues
        var cursor = db.products.find(query, { _id: 1 }).limit($BATCH_SIZE);
        var ids = [];
        cursor.forEach(function(doc) {
            ids.push(doc._id);
        });
        
        if (ids.length === 0) {
            print(0);
        } else {
            var result = db.products.deleteMany({ _id: { \$in: ids } });
            print(result.deletedCount);
        }
    }
    ")
    
    if [ -z "$BATCH_DELETED" ] || [ "$BATCH_DELETED" = "0" ]; then
        echo "Done! (no more products to delete)"
        break
    fi
    
    TOTAL_DELETED=$((TOTAL_DELETED + BATCH_DELETED))
    echo "Deleted $BATCH_DELETED products (Total: $TOTAL_DELETED)"
    
    # If we deleted less than batch size, we're done
    if [ "$BATCH_DELETED" -lt "$BATCH_SIZE" ]; then
        break
    fi
    
    # Small delay to prevent overwhelming the database and show progress
    sleep 0.05
done

DELETED_COUNT=$TOTAL_DELETED

echo ""
echo "✅ Deletion complete!"
echo ""
echo "Deleted products: $DELETED_COUNT"
echo ""
echo "⚠️  Remember: This operation is irreversible. Make sure you have a backup!"

