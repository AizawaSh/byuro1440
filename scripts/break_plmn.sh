#!/bin/bash
GNB_CONFIG="$HOME/UERANSIM/config/open5gs-gnb.yaml"
BACKUP="${GNB_CONFIG}.bak"
[ ! -f "$BACKUP" ] && cp "$GNB_CONFIG" "$BACKUP"

# Меняем PLMN на другой (001/01 вместо 999/70)
sed -i -E "s/^mcc:.*/mcc: '001'/" "$GNB_CONFIG"
sed -i -E "s/^mnc:.*/mnc: '01'/" "$GNB_CONFIG"

echo "PLMN в gNB изменён. Проверьте:"
grep -nE "^mcc:|^mnc:" "$GNB_CONFIG"
