#!/bin/bash
UE_IP="10.45.0.2"
TABLE="rt_uesimtun0"

# Удаляем правило маршрутизации (именно оно направляет трафик в таблицу UERANSIM)
sudo ip rule del from $UE_IP lookup $TABLE 2>/dev/null
echo "Правило маршрутизации для $UE_IP удалено."

# Проверка
ip rule show | grep $UE_IP || echo "Правила для $UE_IP больше нет."
