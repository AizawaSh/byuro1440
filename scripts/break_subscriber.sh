#!/bin/bash
set -e

IMSI="999700000000001"          # подставьте свой IMSI
BACKUP_DIR="/tmp/open5gs_backup"

echo "[1/3] Делаем бэкап коллекции subscribers..."
docker exec -i mongodb mongodump -d open5gs -c subscribers -o "$BACKUP_DIR"

echo "[2/3] Удаляем абонента $IMSI..."
docker exec -i mongodb mongo open5gs --eval "db.subscribers.deleteMany({imsi: \"$IMSI\"})"

echo "[3/3] Проверка:"
docker exec -i mongodb mongo open5gs --eval "print('count = ' + db.subscribers.count({imsi: \"$IMSI\"}))"

echo "Неисправность внесена. Перезапустите UE."
