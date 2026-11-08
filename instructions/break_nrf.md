## Демонстрация неисправности: Отключённый NRF (SCP работает)

### 1. Скрипты

**`break_nrf_keep_scp.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo systemctl stop open5gs-nrfd
echo "NRF остановлен (SCP оставлен запущенным)."
sudo systemctl is-active open5gs-nrfd open5gs-scpd || true
~~~

**`fix_nrf_keep_scp.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo systemctl start open5gs-nrfd
echo "NRF запущен."
sudo systemctl is-active open5gs-nrfd open5gs-scpd || true
~~~

### 2. Воспроизведение

На Core-VM:
~~~bash
bash break_nrf_keep_scp.sh
~~~

На RAN-VM перезапустите UE:
~~~bash
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 3. Где искать и что смотреть

#### Логи SCP (Core-VM) — основной симптом

~~~bash
sudo grep -i "nrf\|discover\|No NF\|failed" /var/log/open5gs/scp.log | tail -20
~~~

Ищите ошибки discovery, например:
~~~
[scp] WARNING: nf_discover_handler() failed [-1] (../src/scp/sbi-path.c:821)
~~~
или
~~~
[scp] ERROR: (NF discover) No NF-Instance [npcf-am-policy-control:AMF]
~~~

В вашей архитектуре AMF использует SCP для делегированного discovery. При недоступном NRF SCP не может найти целевые NF, и регистрация UE падает.

#### Логи AMF (Core-VM)

~~~bash
sudo grep -i "nrf\|registration\|500\|504" /var/log/open5gs/amf.log | tail -20
~~~

AMF может получать ошибки при попытке регистрации в NRF (если ходит напрямую) или при discovery через SCP. Ищите `HTTP response error [500]` или `[504]`.

#### Статус служб (прямое доказательство)

~~~bash
systemctl status open5gs-nrfd open5gs-scpd --no-pager
~~~

Ожидаемый результат:
- `open5gs-nrfd` — `inactive (dead)`
- `open5gs-scpd` — `active (running)`

#### Wireshark (захват на dummy0)

**Фильтр:**
~~~
tcp.port == 7777
~~~

**Что искать:**
- Трафик AMF → SCP (`127.0.0.200:7777`) присутствует.
- Запросы SCP → NRF (`127.0.0.10:7777`) **отсутствуют** или завершаются ошибкой, потому что NRF остановлен.
- При необходимости примените `Decode As → HTTP2` для порта 7777.

> **Важно**: В отличие от сценария «отключены и NRF, и SCP» (где ошибка — `Couldn't connect to server`), здесь SCP работает, но не может выполнить discovery. Это более тонкий и реалистичный сценарий.

### 4. Устранение

~~~bash
bash fix_nrf_keep_scp.sh
~~~

Затем на RAN-VM:
~~~bash
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

Дождитесь `Initial Registration is successful` и проверьте ping.

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Отключённый NRF (SCP работает) |
| **Симптом в логах SCP** | `nf_discover_handler() failed [-1]`, ошибки discovery |
| **Симптом в логах AMF** | `HTTP response error [500]` или `[504]` при запросе к SCP |
| **Симптом в логах UE** | Регистрация не завершается (таймаут) |
| **Симптом в Wireshark** | Трафик AMF → SCP есть; SCP → NRF (`127.0.0.10:7777`) отсутствует |
| **Поведение абонента** | Регистрация не проходит, `uesimtun0` не появляется |
| **Локализация** | `systemctl status` — NRF `inactive`, SCP `active`; в `scp.log` — ошибки discovery |
| **Устранение** | Запустить NRF (`fix_nrf_keep_scp.sh`), перезапустить UE |

### 6. Важное дополнение

Если после `break_nrf_keep_scp.sh` регистрация UE **всё равно проходит** (из-за кэша в SCP), перезапустите SCP перед повторной попыткой:

~~~bash
sudo systemctl restart open5gs-scpd
~~~

И только потом перезапускайте UE. Это гарантирует, что SCP попытается выполнить discovery заново и не найдёт NRF.
