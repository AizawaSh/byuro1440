## Демонстрация неисправности: Недоступность PCF (Policy Control Function)

### 1. Скрипты

**`break_pcf.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo systemctl stop open5gs-pcfd
echo "PCF остановлен. Перезапустите UE для проверки."
~~~

**`fix_pcf.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo systemctl start open5gs-pcfd
echo "PCF запущен. Перезапустите UE."
~~~

> В Open5GS PCF по умолчанию слушает `127.0.0.13:7777` (SBI) [citation:7]. При остановке службы AMF не сможет получить политики для UE.

### 2. Воспроизведение

На Core-VM:
~~~bash
bash break_pcf.sh
~~~

На RAN-VM перезапустите UE:
~~~bash
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 3. Где искать и что смотреть

#### Логи UE (RAN-VM)

Регистрация не завершается. В логе UE появится таймаут или `Registration Reject`. В отличие от DNN или ключей, здесь нет явного сообщения о причине — UE просто не получает ответа от сети.

#### Логи AMF (Core-VM)

~~~bash
sudo grep -i "pcf\|policy\|npcf" /var/log/open5gs/amf.log | tail -20
~~~

Ищите строки, связанные с попыткой запроса политик к PCF:
~~~
[sbi] DEBUG: [201:POST] http://127.0.0.13:7777/npcf-am-policy-control/v1/policies
[gmm] ERROR: Invalid service name [npcf-am-policy-control]
~~~

Согласно issue #3948 в Open5GS, при проблемах с ответом PCF AMF может выдавать `Invalid service name [npcf-am-policy-control]` и даже падать с фатальной ошибкой в состоянии GMM [citation:5]. Если PCF просто остановлен, AMF будет получать ошибку соединения (connection refused) или таймаут.

#### Wireshark (захват на dummy0)

**Фильтр:**
~~~
tcp.port == 7777
~~~

**Что искать:**
1. AMF отправляет HTTP/2-запрос к PCF (`127.0.0.13:7777`) с URI `/npcf-am-policy-control/v1/policies` [citation:3].
2. Ответа нет (таймаут) или приходит TCP RST (соединение отклонено), если PCF остановлен.
3. При необходимости примените `Decode As → HTTP2` для порта 7777.

> **Важно**: PCF также может быть недоступен через SCP, если в `amf.yaml` клиент SBI настроен на SCP (`127.0.0.200:7777`). В этом случае SCP вернёт ошибку 500 или таймаут, а не прямое RST от PCF.

### 4. Устранение

~~~bash
cd ~/UERANSIM
bash fix_pcf.sh
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

После перезапуска дождитесь `Initial Registration is successful` и проверьте ping.

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Недоступность PCF (Policy Control Function) |
| **Симптом в логах UE** | Регистрация не завершается, таймаут или `Registration Reject` |
| **Симптом в логах AMF** | Ошибки SBI-запроса к PCF: `Invalid service name [npcf-am-policy-control]` или таймаут соединения [citation:5] |
| **Симптом в Wireshark** | HTTP/2-запрос от AMF к `127.0.0.13:7777` (`/npcf-am-policy-control/v1/policies`) не получает ответа [citation:3] |
| **Поведение абонента** | Регистрация не проходит, `uesimtun0` не появляется |
| **Локализация** | `systemctl status open5gs-pcfd` — `inactive`. В `amf.log` — ошибки SBI-запроса к PCF |
| **Устранение** | Запустить PCF (`fix_pcf.sh`), перезапустить UE |
