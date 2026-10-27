#!/bin/bash
UE_IP="10.45.0.2"
TABLE="rt_uesimtun0"

if ip rule show | grep -q "from $UE_IP lookup $TABLE"; then
  echo "Правило уже существует."
else
  sudo ip rule add from $UE_IP lookup $TABLE
  echo "Правило маршрутизации для $UE_IP восстановлено."
fi
ip rule show | grep $UE_IP
