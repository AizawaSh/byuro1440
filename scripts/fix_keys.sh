#!/bin/bash
UE_CONFIG="$HOME/UERANSIM/config/open5gs-ue.yaml"
BACKUP="${UE_CONFIG}.bak"
cp "$BACKUP" "$UE_CONFIG"
echo "Ключи восстановлены. Перезапустите UE."
