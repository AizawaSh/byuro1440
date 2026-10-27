#!/bin/bash
# Возвращаем стандартное значение (обычно 1400 для Open5GS)
sudo ip link set dev ens3 mtu 1400
echo "MTU на ens3 восстановлен (1400)."
ip link show ens3 | grep mtu
