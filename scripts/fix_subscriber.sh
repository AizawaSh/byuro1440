#!/bin/bash
set -e

BACKUP_DIR="/tmp/open5gs_backup"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Бэкап не найден: $BACKUP_DIR"
  exit 1
fi

echo "Восстанавливаем абонентов из $BACKUP_DIR..."
docker exec -i mongodb mongorestore -d open5gs -c subscribers "$BACKUP_DIR/open5gs/subscribers.bson"

echo "Проверка:"
docker exec -i mongodb mongo open5gs --eval 'print("count = " + db.subscribers.count())'
