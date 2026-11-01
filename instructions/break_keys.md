## Демонстрация неисправности: Рассогласование ключей (K / OPc)

### 1. Скрипты

**`break_keys.sh`** (RAN-VM):
~~~bash
#!/bin/bash
UE_CONFIG="$HOME/UERANSIM/config/open5gs-ue.yaml"
BACKUP="${UE_CONFIG}.bak"
[ ! -f "$BACKUP" ] && cp "$UE_CONFIG" "$BACKUP"

# Меняем K и OPc на заведомо неверные (сохраняя длину и кавычки)
sed -i -E "s/^([[:space:]]*)key:.*/\1key: 'FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF'/" "$UE_CONFIG"
sed -i -E "s/^([[:space:]]*)op:.*/\1op: '00000000000000000000000000000000'/" "$UE_CONFIG"

echo "Ключи K/OPc изменены. Проверьте:"
grep -nE "key:|op:|opType:" "$UE_CONFIG"
~~~

**`fix_keys.sh`** (RAN-VM):
~~~bash
#!/bin/bash
UE_CONFIG="$HOME/UERANSIM/config/open5gs-ue.yaml"
BACKUP="${UE_CONFIG}.bak"
cp "$BACKUP" "$UE_CONFIG"
echo "Ключи восстановлены. Перезапустите UE."
~~~

### 2. Воспроизведение

~~~bash
cd ~/UERANSIM
bash break_keys.sh
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 3. Где искать и что смотреть

#### Логи UE (RAN-VM)

После перезапуска UE в логе появится:
~~~
[nas] [error] AUTN validation MAC mismatch. expected [...] received [...]
[nas] [error] Sending Authentication Failure with cause [MAC_FAILURE]
[nas] [error] Authentication Reject received
~~~
Это прямая причина отказа: UE вычислил MAC с неверным K и отправил `Authentication Failure` [citation:1].

#### Логи AMF (Core-VM)

~~~bash
sudo grep -i "auth\|mac\|failure\|reject" /var/log/open5gs/amf.log | tail -20
~~~
Ищите строки:
~~~
[gmm] WARNING: Authentication failure [20]
[gmm] WARNING: Authentication failure(MAC failure)
~~~
Код `20` — это `MAC failure` по 3GPP TS 24.501 [citation:1][citation:6].

#### Wireshark (захват на dummy0)

**Фильтр для поиска отказа аутентификации:**
~~~
nas_5gs.mm.message_type == 0x59
~~~
(0x59 — `Authentication Failure`)

Или:
~~~
nas_5gs && nas_5gs.mm.cause == 20
~~~

**Где именно смотреть:**
1. Найдите пакет `UplinkNASTransport` (NGAP, procedureCode 46).
2. Внутри него — `NAS-PDU` → `Plain NAS 5GS Message` (пакет **не зашифрован**, потому что аутентификация ещё не завершена).
3. Разверните: `Message type: Authentication failure (0x59)` → `5GMM cause: MAC failure (20)`.

> **Важно**: в отличие от DNN, здесь сообщение **не зашифровано** (Security header type: Plain NAS), поэтому причина `MAC failure (20)` видна в Wireshark сразу, без hex-поиска.

### 4. Устранение

~~~bash
cd ~/UERANSIM
bash fix_keys.sh
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

После перезапуска дождитесь `Initial Registration is successful` и `TUN interface[uesimtun0, ...] is up`, затем проверьте:
~~~bash
ping -I 10.45.0.x -c 2 8.8.8.8
~~~

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Рассогласование ключей абонента (K / OPc) |
| **Симптом в логах UE** | `AUTN validation MAC mismatch`, `Sending Authentication Failure with cause [MAC_FAILURE]` |
| **Симптом в логах AMF** | `Authentication failure [20]`, `Authentication failure(MAC failure)` |
| **Симптом в Wireshark** | `UplinkNASTransport` → `Plain NAS 5GS Message` → `Authentication failure (0x59)` → `5GMM cause: MAC failure (20)` |
| **Поведение абонента** | Регистрация не проходит, `uesimtun0` не поднимается. Отказ происходит **до** PDU-сессии |
| **Локализация** | Сравнить `key` и `op`/`opc` (и `opType`) в `open5gs-ue.yaml` с K и OPc в подписке WebUI/MongoDB [citation:1][citation:7] |
| **Устранение** | Вернуть корректные ключи (`fix_keys.sh`), перезапустить UE |
