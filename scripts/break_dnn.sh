#!/bin/bash
UE_CONFIG="$HOME/UERANSIM/config/open5gs-ue.yaml"
BACKUP="${UE_CONFIG}.bak"
[ ! -f "$BACKUP" ] && cp "$UE_CONFIG" "$BACKUP"
sed -i 's/apn: .*/apn: "wrong_dnn"/' "$UE_CONFIG"
echo "DNN изменён на wrong_dnn. Перезапустите UE."
