## Демонстрация неисправности: Отсутствующий абонент в WebUI

### 1. Скрипты

**`break_subscriber.sh`** (Core-VM):
~~~bash
#!/bin/bash
set -e

IMSI="999700000000001"          # подставьте свой IMSI
BACKUP_DIR="/tmp/open5gs_backup"

echo "[1/3] Делаем бэкап коллекции subscribers..."
docker exec -i mongodb mongodump -d open5gs -c subscribers -o "$BACKUP_DIR"

echo "[2/3] Удаляем абонента $IMSI..."
docker exec -i mongodb mongo open5gs --eval "db.subscribers.deleteMany({imsi: \"$IMSI\"})"

echo "[3/3] Проверка:"
docker exec -i mongodb mongo open5gs --eval "print('count = ' + db.subscribers.count({imsi: \"$IMSI\"}))"

echo "Неисправность внесена. Перезапустите UE."
~~~

**`fix_subscriber.sh`** (Core-VM):
~~~bash
#!/bin/bash
set -e

BACKUP_DIR="/tmp/open5gs_backup"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Бэкап не найден: $BACKUP_DIR"
  exit 1
fi

echo "Восстанавливаем абонентов из $BACKUP_DIR..."
docker exec -i mongodb mongorestore -d open5gs -c subscribers "$BACKUP_DIR/open5gs/subscribers.bson"

echo "Проверка:"
docker exec -i mongodb mongo open5gs --eval 'print("count = " + db.subscribers.count())'
~~~

> **Важно**: используется `mongodump`/`mongorestore` (а не ручной `insertOne`), потому что они корректно сохраняют все поля документа, включая `_id` и типы BSON.

### 2. Воспроизведение

На Core-VM:
~~~bash
bash break_subscriber.sh
~~~

На RAN-VM перезапустите UE:
~~~bash
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 3. Где искать и что смотреть

#### Логи UE (RAN-VM)

Регистрация не завершается. В логе появится `Registration Reject` с причиной:
~~~
Initial Registration failed [ILLEGAL_UE]
~~~
или `5GMM cause #3 (Illegal UE)`. Это соответствует спецификации 3GPP TS 24.501: если IMSI нет в UDM, сеть отклоняет регистрацию с причиной `Illegal UE` [citation:2][citation:13].

#### Логи AMF / UDM (Core-VM)

На Core-VM выполните:
~~~bash
sudo grep -i "Cannot find IMSI\|User not found\|imsi-999700000000001" /var/log/open5gs/udm.log | tail -20
~~~

Ищите строки:
~~~
[dbi] INFO: [imsi-999700000000001] Cannot find IMSI in DB
[udm] WARNING: [suci-...] HTTP response error [404]
~~~
Это прямое указание, что UDM не нашёл абонента в базе [citation:7].

#### Wireshark (захват на dummy0)

**Фильтр:**
~~~
nas_5gs
~~~

**Что искать:**
1. UE отправляет `Registration Request` (виден IMSI/SUCI в открытом виде).
2. AMF/UDM не находит абонента.
3. Сеть отвечает `Registration Reject` с `5GMM cause #3 (Illegal UE)`.

В отличие от DNN, здесь отказ происходит **до** аутентификации (или на этапе получения векторов), и причина `Illegal UE` видна в NAS-сообщении.

### 4. Устранение

~~~bash
cd ~/UERANSIM
bash fix_subscriber.sh
sudo pkill -f nr-ue
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

После перезапуска дождитесь `Initial Registration is successful` и проверьте ping.

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Отсутствующий абонент в WebUI (IMSI не заведён в базе) |
| **Симптом в логах UE** | `Initial Registration failed [ILLEGAL_UE]` / `5GMM cause #3` |
| **Симптом в логах UDM** | `Cannot find IMSI in DB`, `HTTP response error [404]` |
| **Симптом в Wireshark** | `Registration Request` → `Registration Reject` с cause `#3 (Illegal UE)` |
| **Поведение абонента** | Сеть не пускает, `uesimtun0` не появляется |
| **Локализация** | Сравнить `supi` в `open5gs-ue.yaml` с IMSI в коллекции `subscribers` MongoDB |
| **Устранение** | Восстановить абонента из бэкапа (`fix_subscriber.sh`) или добавить через WebUI, перезапустить UE |
