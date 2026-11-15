#!/bin/bash
TABLE="rt_uesimtun0"

# Автоматически определяем IP UE с интерфейса uesimtun0
UE_IP=$(ip -4 addr show uesimtun0 2>/dev/null | grep -oP 'inet \K[\d.]+')

if [ -z "$UE_IP" ]; then
  echo "Ошибка: интерфейс uesimtun0 не найден или не имеет IPv4-адреса."
  echo "Убедитесь, что UE запущен и PDU-сессия установлена."
  exit 1
fi

echo "Текущий IP UE: $UE_IP"

# Удаляем правило маршрутизации
sudo ip rule del from "$UE_IP" lookup "$TABLE" 2>/dev/null
echo "Правило маршрутизации для $UE_IP удалено."

# Проверка
ip rule show | grep "$UE_IP" || echo "Правила для $UE_IP больше нет."