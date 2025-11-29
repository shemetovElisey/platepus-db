#!/bin/bash
set -e

# Ждем пока MongoDB полностью запустится
until mongosh --eval "print('MongoDB is ready')" 2>/dev/null; do
  echo "Waiting for MongoDB to start..."
  sleep 2
done

# Импортируем дамп, если он существует
if [ -d "/docker-entrypoint-initdb.d/dump" ] && [ "$(ls -A /docker-entrypoint-initdb.d/dump)" ]; then
  echo "Importing MongoDB dump..."
  mongorestore --db=platepus /docker-entrypoint-initdb.d/dump
  echo "MongoDB dump imported successfully"
else
  echo "No dump directory found or dump is empty, skipping import"
fi

