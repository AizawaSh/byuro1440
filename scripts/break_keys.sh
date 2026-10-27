#!/bin/bash
UE_CONFIG="$HOME/UERANSIM/config/open5gs-ue.yaml"
BACKUP="${UE_CONFIG}.bak"
[ ! -f "$BACKUP" ] && cp "$UE_CONFIG" "$BACKUP"

# Меняем значение после ключа, сохраняя отступ и кавычки
sed -i -E "s/^([[:space:]]*)k:.*/\1k: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'/" "$UE_CONFIG"
sed -i -E "s/^([[:space:]]*)op:.*/\1op: '00000000000000000000000000000000'/" "$UE_CONFIG"
sed -i -E "s/^([[:space:]]*)opc:.*/\1opc: '00000000000000000000000000000000'/" "$UE_CONFIG"

echo "Ключи изменены. Проверьте:"
grep -nE "k:|op:|opc:" "$UE_CONFIG"
