#!/bin/bash
GNB_CONFIG="$HOME/UERANSIM/config/open5gs-gnb.yaml"
cp "${GNB_CONFIG}.bak" "$GNB_CONFIG"
echo "PLMN восстановлен. Перезапустите gNB."
