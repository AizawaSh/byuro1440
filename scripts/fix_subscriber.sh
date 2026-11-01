#!/bin/bash
set -e

BACKUP_DIR="/tmp/open5gs_backup"

# Проверяем наличие бэкапа ВНУТРИ контейнера
if ! docker exec -i mongodb test -d "$BACKUP_DIR"; then
  echo "Бэкап не найден внутри контейнера: $BACKUP_DIR"
  exit 1
fi

echo "Восстанавливаем абонентов..."
docker exec -i mongodb mongorestore -d open5gs -c subscribers "$BACKUP_DIR/open5gs/subscribers.bson"

echo "Проверка:"
docker exec -i mongodb mongo open5gs --eval 'print("count = " + db.subscribers.count())'
