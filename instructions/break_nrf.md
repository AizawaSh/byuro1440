## Демонстрация неисправности: Отключённый NRF (+SCP)

### 1. Скрипты

**`break_nrf.sh`** (Core-VM):
~~~bash
#!/bin/bash
set -e

echo "[1/3] Останавливаем NRF и SCP..."
sudo systemctl stop open5gs-nrfd open5gs-scpd

echo "[2/3] Перезапускаем AMF и SMF, чтобы они потеряли связь с NRF/SCP..."
sudo systemctl restart open5gs-amfd open5gs-smfd

echo "[3/3] Статус:"
sudo systemctl is-active open5gs-nrfd open5gs-scpd open5gs-amfd open5gs-smfd || true

echo "Неисправность внесена. Запустите gNB и UE — регистрация должна зависнуть."
~~~

**`fix_nrf.sh`** (Core-VM):
~~~bash
#!/bin/bash
set -e

echo "[1/3] Запускаем NRF и SCP..."
sudo systemctl start open5gs-nrfd open5gs-scpd

echo "[2/3] Перезапускаем AMF и SMF для восстановления связи..."
sudo systemctl restart open5gs-amfd open5gs-smfd

echo "[3/3] Статус:"
sudo systemctl is-active open5gs-nrfd open5gs-scpd open5gs-amfd open5gs-smfd || true

echo "Неисправность устранена. Перезапустите gNB и UE."
~~~

> **Важно**: В вашем `amf.yaml` клиент SBI настроен на использование SCP (`http://127.0.0.200:7777`). Поэтому останавливать только NRF недостаточно — SCP тоже нужно остановить, иначе AMF может продолжать работать через него.

### 2. Воспроизведение

На Core-VM:
~~~bash
bash break_nrf.sh
~~~

На RAN-VM перезапустите gNB и UE:
~~~bash
sudo pkill -f nr-ue
sudo pkill -f nr-gnb
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml
# в другом терминале:
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 3. Где искать и что смотреть

#### Логи AMF / SMF (Core-VM)

~~~bash
sudo grep -i "nrf\|scp\|sbi\|connect" /var/log/open5gs/amf.log | tail -20
~~~

Ищите строки:
~~~
[sbi] WARNING: Couldn't connect to server ... 127.0.0.10:7777
[sbi] WARNING: Couldn't connect to server ... 127.0.0.200:7777
~~~
Или при старте AMF может выдать:
~~~
Both NRF and SCP are unavailable
~~~

Это означает, что AMF не может найти другие сетевые функции (SMF, UDM, AUSF), потому что механизм обнаружения (NRF/SCP) недоступен [citation:1][citation:5].

#### Логи UE (RAN-VM)

Регистрация не завершается. UE отправляет `Initial Registration`, но ответа нет (таймаут). В отличие от DNN или ключей, здесь нет явного `Reject` — просто «тишина».

#### Wireshark (захват на dummy0)

**Фильтр:**
~~~
tcp.port == 7777
~~~

**Что искать:**
- На `lo` (который зеркалируется на `dummy0`) видны попытки подключения к `127.0.0.10:7777` (NRF) или `127.0.0.200:7777` (SCP).
- Вместо нормального HTTP/2-обмена вы увидите **TCP RST** (соединение отклонено) или просто отсутствие ответа.
- При необходимости примените `Decode As → HTTP2` для порта 7777.

> **Важно**: Если после `break_nrf.sh` регистрация UE **всё равно проходит** (например, из-за кэша NF-профилей в AMF), это может означать, что AMF уже закэшировал адреса SMF/UDM. В этом случае для чистого воспроизведения перезапустите **все** службы Open5GS после остановки NRF/SCP:
> ~~~bash
> sudo systemctl restart open5gs-amfd open5gs-smfd open5gs-upfd open5gs-ausfd open5gs-udmd open5gs-pcfd
> ~~~

### 4. Устранение

~~~bash
cd ~/UERANSIM
bash fix_nrf.sh
~~~

Затем перезапустите gNB и UE:
~~~bash
sudo pkill -f nr-ue
sudo pkill -f nr-gnb
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml
# в другом терминале:
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

Дождитесь `Initial Registration is successful` и проверьте ping.

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Отключённый NRF (и SCP) |
| **Симптом в логах AMF/SMF** | `Couldn't connect to server ... 127.0.0.10:7777` или `127.0.0.200:7777`; при старте — `Both NRF and SCP are unavailable` [citation:1][citation:5] |
| **Симптом в логах UE** | Регистрация не завершается, таймаут. Нет явного `Reject` |
| **Симптом в Wireshark** | На `dummy0` (порт 7777) видны `RST` или отсутствие ответов от NRF/SCP |
| **Поведение абонента** | Сеть «не отвечает», регистрация зависает, `uesimtun0` не появляется |
| **Локализация** | `systemctl status open5gs-nrfd open5gs-scpd` — оба `inactive`. В `amf.log` — ошибки подключения к SBI-клиенту |
| **Устранение** | Запустить NRF и SCP (`fix_nrf.sh`), перезапустить AMF/SMF, затем gNB и UE |
