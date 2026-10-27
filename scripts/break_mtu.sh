#!/bin/bash
# Уменьшаем MTU на ogstun, чтобы крупные пакеты не проходили
sudo ip link set dev ens3 mtu 1200
echo "MTU на ens3 изменён на 1200. Крупные пакеты будут теряться."
ip link show ens3 | grep mtu
