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

echo "Analyzing products..."
echo ""

# Count total products
TOTAL_COUNT=$(mongosh "$CONNECTION_STRING" --quiet --eval "db.products.countDocuments()")
echo "Total products in database: $TOTAL_COUNT"

# Count products with valid energy data
PRODUCTS_WITH_ENERGY=$(mongosh "$CONNECTION_STRING" --quiet --eval "
db.products.countDocuments({
    \$and: [
        { nutriments: { \$exists: true } },
        {
            \$or: [
                { 'nutriments.energy-kcal_100g': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy_kcal_100g': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy-kj_100g': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy_kj_100g': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy-kcal_value': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy_kcal_value': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy-kj_value': { \$exists: true, \$type: 'number' } },
                { 'nutriments.energy_kj_value': { \$exists: true, \$type: 'number' } }
            ]
        }
    ]
})
")

echo "Products with valid energy data: $PRODUCTS_WITH_ENERGY"

# Count products with valid macronutrients (proteins, fats, or carbohydrates)
PRODUCTS_WITH_MACROS=$(mongosh "$CONNECTION_STRING" --quiet --eval "
db.products.countDocuments({
    \$and: [
        { nutriments: { \$exists: true } },
        {
            \$or: [
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
})
")

echo "Products with valid macronutrients (БЖУ): $PRODUCTS_WITH_MACROS"

# Count products with BOTH energy AND macronutrients
PRODUCTS_WITH_BOTH=$(mongosh "$CONNECTION_STRING" --quiet --eval "
db.products.countDocuments({
    \$and: [
        { nutriments: { \$exists: true } },
        {
            \$or: [
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
            \$or: [
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
})
")

echo "Products with BOTH energy AND macronutrients: $PRODUCTS_WITH_BOTH"

# Count products to be deleted (no energy OR no macronutrients)
PRODUCTS_TO_DELETE=$(mongosh "$CONNECTION_STRING" --quiet --eval "
db.products.countDocuments({
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
})
")

echo ""
echo "=========================================="
echo "Products to be deleted: $PRODUCTS_TO_DELETE"
echo "Products to keep: $((TOTAL_COUNT - PRODUCTS_TO_DELETE))"
echo "=========================================="
echo ""

if [ "$DRY_RUN" = true ]; then
    echo "✅ Dry run complete. No products were deleted."
    echo ""
    echo "To actually delete these products, run:"
    echo "  $0 $CONNECTION_STRING --confirm"
    exit 0
fi

if [ "$PRODUCTS_TO_DELETE" -eq 0 ]; then
    echo "✅ No products to delete. All products have valid nutrition data."
    exit 0
fi

echo "⚠️  WARNING: About to delete $PRODUCTS_TO_DELETE products!"
echo ""
read -p "Type 'DELETE' to confirm: " confirmation

if [ "$confirmation" != "DELETE" ]; then
    echo "❌ Deletion cancelled."
    exit 1
fi

echo ""
echo "Deleting products..."
echo ""

# Delete products
DELETED_COUNT=$(mongosh "$CONNECTION_STRING" --quiet --eval "
var result = db.products.deleteMany({
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
});
result.deletedCount;
")

echo "✅ Deletion complete!"
echo ""
echo "Deleted products: $DELETED_COUNT"
echo "Remaining products: $((TOTAL_COUNT - DELETED_COUNT))"
echo ""
echo "⚠️  Remember: This operation is irreversible. Make sure you have a backup!"

