#!/bin/bash
set -e

DUMMY="dummy0"

# 1. Создать dummy0, если его нет
if ! ip link show "$DUMMY" &>/dev/null; then
    ip link add "$DUMMY" type dummy
fi
ip link set "$DUMMY" up

# 2. Очистить старые настройки (если скрипт запускается повторно)
for IFACE in ens3 lo; do
    tc qdisc del dev "$IFACE" clsact 2>/dev/null || true
done

# 3. Настроить зеркалирование для ens3 (N2 и N3)
tc qdisc add dev ens3 clsact

# Ingress: SCTP (38412) и UDP (2152)
tc filter add dev ens3 ingress protocol ip u32 \
    match ip protocol 132 0xff \
    match ip dport 38412 0xffff \
    action mirred egress mirror dev "$DUMMY"
tc filter add dev ens3 ingress protocol ip u32 \
    match ip protocol 17 0xff \
    match ip dport 2152 0xffff \
    action mirred egress mirror dev "$DUMMY"

# Egress: SCTP (38412) и UDP (2152)
tc filter add dev ens3 egress protocol ip u32 \
    match ip protocol 132 0xff \
    match ip sport 38412 0xffff \
    action mirred egress mirror dev "$DUMMY"
tc filter add dev ens3 egress protocol ip u32 \
    match ip protocol 17 0xff \
    match ip sport 2152 0xffff \
    action mirred egress mirror dev "$DUMMY"

# 4. Настроить зеркалирование для lo (SBI и PFCP)
tc qdisc add dev lo clsact

# Ingress: TCP (7777) и UDP (8805)
tc filter add dev lo ingress protocol ip u32 \
    match ip protocol 6 0xff \
    match ip dport 7777 0xffff \
    action mirred egress mirror dev "$DUMMY"
tc filter add dev lo ingress protocol ip u32 \
    match ip protocol 17 0xff \
    match ip dport 8805 0xffff \
    action mirred egress mirror dev "$DUMMY"

# Egress: TCP (7777) и UDP (8805)
tc filter add dev lo egress protocol ip u32 \
    match ip protocol 6 0xff \
    match ip sport 7777 0xffff \
    action mirred egress mirror dev "$DUMMY"
tc filter add dev lo egress protocol ip u32 \
    match ip protocol 17 0xff \
    match ip sport 8805 0xffff \
    action mirred egress mirror dev "$DUMMY"

echo "Зеркалирование только 5G-трафика настроено на $DUMMY."
