# byuro1440

# Инструкция по настройке лабораторного стенда 5G (Open5GS + [UERANSIM](https://github.com/aligungr/UERANSIM)) в GNS3

## 1. Архитектура и параметры

<p align="center">
  <img src="images/image1.png" alt="Топология GNS3" />
</p>

| Компонент | Роль | Компоненты | Адрес |
|---|---|---|---|
| Core-VM | Ядро сети 5G | Open5GS (AMF, SMF,UPF, NRF, SCP, AUSF,<br>UDM, UDR, PCF),WebUI, MongoDB | `<IP-Core-VM>` |
| RAN-VM | Базовая станция и абонент | [UERANSIM](https://github.com/aligungr/UERANSIM): gNB + UE | `<IP-RAN-VM>` |

Параметры сети 5G:
- **PLMN**: `999/70`
- **TAC**: `1`
- **DNN**: `internet`
- **Пул UE**: `10.45.0.0/16`, шлюз `10.45.0.1`
- **IMSI**: `999700000000001`
- **K**: `465B5CE8B199B49FAA5F0A2EE238A6BC`
- **OPc**: `E8ED289DEBA952E4283B54E88E6183CA`

Сетевая связность: обе ВМ в подсети 192.168.100.0/24 (через узел NAT в GNS3). Актуальные адреса для настроек можно узнать с помощью команды `ip addr` (интерфейс ens3).

---

## 2. Настройка Core-VM
### 2.1. Настройка MongoDB через Docker
Стандартная установка MongoDB 8.0 через `apt` не работает на процессорах без AVX (ошибка `signal=ILL`). Используется Docker-образ `mongo:4.4`.

~~~
sudo apt update
sudo apt install -y docker.io
sudo systemctl enable --now docker

sudo docker run -d --name mongodb --restart=always \
  -p 27017:27017 \
  -v mongodb_data:/data/db \
  mongo:4.4
~~~

Проверка:
~~~
sudo docker ps | grep mongodb
sudo ss -tlnp | grep 27017
~~~

> `mongo:4.4` — последняя версия без требования AVX. Содержит старый shell `mongo` (не `mongosh`).


### 2.2. Установка ядра Open5GS

~~~
sudo add-apt-repository ppa:open5gs/latest -y
sudo apt update
sudo apt install -y open5gs
~~~

### 2.3. Настройка WebUI через Docker

Так как MongoDB работает через Docker невозможно собрать WebUI автоматически, так как во время сборки ищется пакет MongoDB. Сборка WebUI из исходников на Node.js 22 падает с `Unexpected token` из-за несовместимости старых зависимостей Next.js. Вследствие вышеуказаных проблем используется готовый Docker-образ.

~~~
sudo docker rm -f webui 2>/dev/null
sudo docker run -d --name webui --restart=always \
  -p 9999:9999 \
  -e DB_URI=mongodb://<IP-Core-VM>:27017/open5gs \
  higebu/open5gs-webui:v2.8.0
~~~

> Подставьте актуальный <IP-Core-VM> в `DB_URI`.

Проверка:
~~~
sudo docker ps | grep webui
sudo docker logs webui --tail 20
~~~

WebUI доступен по адресу `http://<IP-Core-VM>:9999/`. Логин `admin`, пароль `1423`.

### 2.4. Настройка AMF

Файл `/etc/open5gs/amf.yaml`:

> Подставьте актуальный IP-Core-VM в конфигурацию. Используемый файл приведен в [configs/amf.yaml](configs/amf.yaml)

~~~yaml
amf:
  ngap:
    server:
      - address: <IP-Core-VM>
  guami:
    - plmn_id:
        mcc: 999
        mnc: 70
  tai:
    - plmn_id:
        mcc: 999
        mnc: 70
      tac: 1
  plmn_support:
    - plmn_id:
        mcc: 999
        mnc: 70
      s_nssai:
        - sst: 1
~~~

Перезапуск:
~~~
sudo systemctl restart open5gs-amfd
~~~

### 2.5. Настройка UPF

Файл `/etc/open5gs/upf.yaml`, секция `gtpu`:

> Подставьте актуальный IP-Core-VM в конфигурацию. Используемый файл приведен в [configs/upf.yaml](configs/upf.yaml)

~~~yaml
  gtpu:
    server:
      - address: <IP-Core-VM>
~~~

Перезапуск:
~~~
sudo systemctl restart open5gs-upfd
~~~

Проверка:
~~~
sudo ss -ulnp | grep 2152   # должно быть <IP-Core-VM>:2152
~~~

### 2.6. Создание интерфейса ogstun и NAT
UPF обычно создаёт ogstun сам, но необходимо проверить:

~~~
ip addr show ogstun   # должен быть 10.45.0.1/16
~~~

Включение форвардинга и NAT:

~~~
sudo sysctl -w net.ipv4.ip_forward=1
echo "net.ipv4.ip_forward=1" | sudo tee -a /etc/sysctl.conf

sudo iptables -t nat -A POSTROUTING -s 10.45.0.0/16 -o ens3 -j MASQUERADE
sudo iptables -I FORWARD -i ogstun -j ACCEPT
sudo iptables -I FORWARD -o ogstun -j ACCEPT
sudo iptables -I INPUT -i ogstun -j ACCEPT

sudo apt install -y iptables-persistent
sudo netfilter-persistent save
~~~

> Явное указание -o ens3 в MASQUERADE часто решает проблему, когда трафик UE не выходит в интернет.



### 2.7. Добавление абонента

Через WebUI (`http://<IP-Core-VM>:9999/`, `admin`/`1423`):

| Поле | Значение |
|---|---|
| IMSI | `999700000000001` |
| K | `465B5CE8B199B49FAA5F0A2EE238A6BC` |
| USIM Type | `OPc` |
| OPc | `E8ED289DEBA952E4283B54E88E6183CA` |
| AMF | `8000` |
| DNN | `internet` |
| Session Type | `IPv4` |
| SST | `1` |

Заполните поле `IMSI` - `999700000000001`. У остальныз полей можно оставить значения по умолчанеию.

<p align="center">
  <img src="images/image2.png" alt="WebUI" width="50%" />
</p>

<p align="center">
  <img src="images/image3.png" alt="WebUI1" width="70%" />
</p>


<p align="center">
  <img src="images/image4.png" alt="WebUI2" width="70%" />
</p>

### 2.8. Проверка служб

~~~
systemctl status open5gs-amfd open5gs-smfd open5gs-upfd open5gs-nrfd open5gs-scpd --no-pager
~~~

Все - `active (running)`.

Включение автозапуска после перезагрузки

~~~
sudo systemctl enable open5gs-nrfd open5gs-scpd open5gs-amfd open5gs-smfd open5gs-upfd open5gs-ausfd open5gs-udmd open5gs-udrd open5gs-pcfd
~~~

## 3. Настройка RAN-VM
### 3.1. Сборка UERANSIM

~~~
sudo apt update
sudo apt install -y make g++ libsctp-dev lksctp-tools iproute2 git cmake
git clone https://github.com/aligungr/UERANSIM
cd UERANSIM
make -j$(nproc)
~~~


### 3.2. Настройка gNB

`~/UERANSIM/config/open5gs-gnb.yaml`:

~~~yaml
mcc: '999'
mnc: '70'
tac: 1

linkIp: <IP-RAN-VM>
ngapIp: <IP-RAN-VM>
gtpIp: <IP-RAN-VM>

amfConfigs:
  - address: <IP-Core-VM>
    port: 38412

slices:
  - sst: 1
~~~

---

### 3.3. Настройка UE

`~/UERANSIM/config/open5gs-ue.yaml`:

~~~yaml
supi: 'imsi-999700000000001'
mcc: '999'
mnc: '70'

key: '465B5CE8B199B49FAA5F0A2EE238A6BC'
op: 'E8ED289DEBA952E4283B54E88E6183CA'
opType: 'OPC'
amf: '8000'

gnbSearchList:
  - <IP-RAN-VM>

sessions:
  - type: 'IPv4'
    apn: 'internet'
    slice:
      sst: 1
~~~

---

## 4. Запуск стенда

**Core-VM**: убедитесь, что MongoDB и службы запущены:
~~~
sudo docker start mongodb
systemctl status open5gs-amfd open5gs-smfd open5gs-upfd open5gs-nrfd --no-pager
~~~

**RAN-VM, терминал 1 -- gNB:**
~~~
cd ~/UERANSIM
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml
~~~

Ждём `NG Setup procedure is successful`.

**RAN-VM, терминал 2 -- UE:**
~~~
cd ~/UERANSIM
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

Ждём `TUN interface[uesimtun0, 10.45.0.x] is up`.

**Проверка:**
~~~
ping -I 10.45.0.x -c 4 8.8.8.8
~~~

## 5. Зеркалирование трафика для Wireshark

Установите Wireshark

~~~
sudo apt install wireshark -y
~~~

Чтобы в одном дампе видеть и сигнализацию N2/NAS (с `ens3`), и внутреннюю сигнализацию SBI/HTTP2 (с `lo`), используется зеркалирование через `tc mirred`. Создаётся фиктивный интерфейс `dummy0`, на который копируются только пакеты 5G (по портам).

Создайте файл [/usr/local/bin/setup_mirror.sh](configs/setup_mirror.sh).

Сделайте файл исполняемым:

~~~
sudo chmod +x /usr/local/bin/setup_mirror.sh
~~~

Для автозапуска необходимо создать unit [/etc/systemd/system/mirror.service](configs/mirror.service)

Активируйте:

~~~
sudo systemctl daemon-reload
sudo systemctl enable --now mirror.service
~~~

Проверка:

~~~
sudo systemctl status mirror.service
ip link show dummy0
tc filter show dev ens3 ingress
tc filter show dev lo ingress
~~~

### 5.1. Что попадает на dummy0

| Источник | Порт | Протокол | Что это |
|---|---|---|---|
| `ens3` | SCTP 38412 | NGAP/NAS | Сигнализация N2 (gNB ↔ AMF) |
| `ens3` | UDP 2152 | GTP-U | Пользовательская плоскость N3 (gNB ↔ UPF) |
| `lo` | TCP 7777 | HTTP/2 | SBI (AMF, SMF, PCF, NRF, SCP) |
| `lo` | UDP 8805 | PFCP | Сигнализация N4 (SMF ↔ UPF) |

Лишний трафик (MongoDB `27017`, DNS `53`, WebUI `9999`) на `dummy0` **не попадает**.

### 5.2. Отображение HTTP/2

Выбирайте интерфейс **`dummy0`**. Для отображения HTTP/2 выполните следующие действия:
- Правой кнопкой на пакете с портом `7777` → **`Decode As...`** → **`HTTP2`** → **`Save`**.

---

## 5.3. Имена сетевых функций и фильтрация

Чтобы в дампе вместо IP-адресов отображались имена (`AMF`, `SMF`, `UPF` и т.д.), а фильтры работали по этим именам, нужно один раз настроить файл `hosts` Wireshark и включить разрешение имён.

Создайте в этой файл [~/.config/wireshark/hosts](configs/hosts) со следующим содержимым:

~~~
127.0.0.5    AMF
127.0.0.4    SMF
127.0.0.7    UPF
127.0.0.13   PCF
127.0.0.10   NRF
127.0.0.11   AUSF
127.0.0.12   UDM
127.0.0.6    SGWU
127.0.0.8    HSS
<IP-Core-VM>  Core-VM
<IP-RAN-VM>  RAN-VM
127.0.0.200   SCP
127.0.0.3    SGW-C
127.0.0.20	UDR
127.0.0.15	BSF
127.0.2.251      SEPP2
127.0.0.14   NSSF
~~~

> Подставьте актуальные IP ваших ВМ. Адреса `127.0.0.x` - стандартные для Open5GS.

### 5.4. Включение разрешения имён

1. **`Edit` → `Preferences` → `Name Resolution`**.
2. Поставьте галочку **`Resolve network (IP) addresses`**.
3. Нажмите **OK**.

После этого в колонках Source и Destination появятся имена (`AMF`, `SMF`, `UPF`), а не IP.

## 6. Каталог неисправностей

На стенде воспроизведены и описаны:

1. [Неверный DNN](instructions/break_dnn.md)
2. [Рассогласование ключей (K/OPc)](instructions/break_keys.md)
3. Несовпадение PLMN
4. Некорректный MTU
5. Потерянный маршрут
6. Отсутствующий абонент в WebUI
7. Недоступность PCF
8. Отключение SMF
9. Падение AMF

Для каждой подготовлены скрипты `break_*.sh` / `fix_*.sh` и шаблон описания.

---
