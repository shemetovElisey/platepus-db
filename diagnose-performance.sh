#!/bin/bash
# Script to diagnose MongoDB performance issues
# Usage: ./diagnose-performance.sh [mongodb-connection-string]

set -e

# Default connection string
DEFAULT_CONNECTION="mongodb://localhost:27017/platepus"

# Get connection string from argument or use default
CONNECTION_STRING="${1:-$DEFAULT_CONNECTION}"

echo "=========================================="
echo "MongoDB Performance Diagnostics"
echo "=========================================="
echo "Connection: $CONNECTION_STRING"
echo ""

# 1. Check current operations
echo "1. CURRENT OPERATIONS (top CPU consumers):"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
db.currentOp({
  'active': true,
  '\$or': [
    { 'op': { '\$in': ['query', 'getmore', 'update', 'insert', 'remove'] } },
    { 'command.aggregate': { '\$exists': true } }
  ]
}).forEach(function(op) {
  print('Operation ID: ' + op.opid);
  print('Operation: ' + op.op);
  print('Namespace: ' + (op.ns || 'N/A'));
  print('Duration: ' + (op.microsecs_running / 1000) + 'ms');
  print('Query: ' + JSON.stringify(op.query || op.command || {}));
  print('---');
})
" || echo "No active operations found"

echo ""
echo "2. DATABASE STATISTICS:"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
var stats = db.stats(1024*1024);
print('Database: ' + stats.db);
print('Collections: ' + stats.collections);
print('Data Size: ' + stats.dataSize.toFixed(2) + ' MB');
print('Storage Size: ' + stats.storageSize.toFixed(2) + ' MB');
print('Index Size: ' + stats.indexSize.toFixed(2) + ' MB');
print('Indexes: ' + stats.indexes);
"

echo ""
echo "3. PRODUCTS COLLECTION INDEXES:"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
var indexes = db.products.getIndexes();
print('Total indexes: ' + indexes.length);
indexes.forEach(function(idx) {
  print('Index: ' + idx.name);
  print('  Keys: ' + JSON.stringify(idx.key));
  print('  Size: ' + (idx.size || 'N/A'));
  print('---');
})
"

echo ""
echo "4. COLLECTION STATISTICS:"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
var stats = db.products.stats(1024*1024);
print('Documents: ' + stats.count.toLocaleString());
print('Size: ' + stats.size.toFixed(2) + ' MB');
print('Storage Size: ' + stats.storageSize.toFixed(2) + ' MB');
print('Average Object Size: ' + stats.avgObjSize + ' bytes');
print('Total Index Size: ' + stats.totalIndexSize.toFixed(2) + ' MB');
print('Indexes: ' + stats.nindexes);
"

echo ""
echo "5. SLOW QUERIES (last 100ms+):"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
db.setProfilingLevel(1, { slowms: 100 });
var slowOps = db.system.profile.find({ 
  ns: 'platepus.products',
  millis: { '\$gt': 100 }
}).sort({ ts: -1 }).limit(10).toArray();

if (slowOps.length > 0) {
  slowOps.forEach(function(op) {
    print('Duration: ' + op.millis + 'ms');
    print('Command: ' + JSON.stringify(op.command || op.query || {}));
    print('---');
  });
} else {
  print('No slow queries found in profile');
}
"

echo ""
echo "6. SERVER STATUS:"
echo "----------------------------------------"
mongosh "$CONNECTION_STRING" --quiet --eval "
var status = db.serverStatus();
print('Uptime: ' + Math.floor(status.uptime / 3600) + ' hours');
print('Connections: ' + status.connections.current + ' / ' + status.connections.available);
print('Active Clients: ' + status.globalLock.activeClients.total);
print('Queued Operations: ' + status.globalLock.currentQueue.total);
"

echo ""
echo "=========================================="
echo "RECOMMENDATIONS:"
echo "=========================================="
echo ""
echo "If CPU usage is high, likely causes:"
echo "1. Missing indexes on product_name field"
echo "2. Regex queries doing full collection scans"
echo "3. Background index creation in progress"
echo ""
echo "SOLUTION: Create indexes:"
echo "  ./create-index.sh \"$CONNECTION_STRING\""
echo ""

