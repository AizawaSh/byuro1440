## Демонстрация неисправности: Некорректный MTU

### 1. Скрипты

**`break_mtu.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo ip link set dev ogstun mtu 1200
echo "MTU на ogstun изменён на 1200."
ip link show ogstun | grep mtu
~~~

**`fix_mtu.sh`** (Core-VM):
~~~bash
#!/bin/bash
sudo ip link set dev ogstun mtu 1400
echo "MTU на ogstun восстановлен (1400)."
ip link show ogstun | grep mtu
~~~

> На RAN-VM перед проверкой убедитесь, что MTU на `uesimtun0` не меньше 1400:
> ~~~bash
> sudo ip link set dev uesimtun0 mtu 1400
> ~~~

### 2. Воспроизведение

На Core-VM:
~~~bash
bash break_mtu.sh
~~~

На RAN-VM (UE уже запущен, `uesimtun0` поднят):
~~~bash
# Мелкий пакет должен пройти
ping -I 10.45.0.x -s 100 -c 2 8.8.8.8

# Крупный пакет с запретом фрагментации — не должен пройти
ping -I 10.45.0.x -s 1300 -M do -c 4 8.8.8.8
~~~

### 3. Где искать и что смотреть

#### Логи UE (RAN-VM)

При отправке крупного пакета с `-M do` ядро RAN-VM возвращает локальную ошибку **до** отправки пакета в туннель:
~~~
ping: local error: message too long, mtu=1200
~~~
Это означает, что ядро RAN-VM знает эффективный MTU пути (1200, от `ogstun`) и отказывается отправлять пакет с DF, который не влезает в этот MTU.

#### Wireshark (захват на dummy0)

**Фильтр:**
~~~
icmp
~~~

**Что искать:**
- На `ogstun` (если захватывать там) крупные ICMP-запросы **отсутствуют** — они отбрасываются на RAN-VM.
- Мелкие ICMP-запросы (`-s 100`) проходят нормально.
- Если отправлять крупные пакеты **без** `-M do` (разрешив фрагментацию), на `ogstun` можно увидеть фрагментированные пакеты, но ответы могут не возвращаться.

> **Важно**: Это классический «blackhole MTU» — handshake и мелкие пакеты проходят, а крупные данные (HTTP, загрузки) зависают. В Wireshark на `dummy0` вы не увидите крупных пакетов от UE, потому что они отбрасываются локально на RAN-VM.

#### Проверка MTU на интерфейсах

На Core-VM:
~~~bash
ip link show ogstun | grep mtu   # должно быть 1200 (сломано)
~~~

На RAN-VM:
~~~bash
ip link show uesimtun0 | grep mtu   # обычно 1400
ip route get 8.8.8.8 from 10.45.0.x   # показывает эффективный MTU пути
~~~

### 4. Устранение

На Core-VM:
~~~bash
bash fix_mtu.sh
~~~

На RAN-VM очистите кэш PMTU (важно!):
~~~bash
sudo ip route flush cache
~~~

Затем проверьте:
~~~bash
ping -I 10.45.0.x -s 1300 -M do -c 4 8.8.8.8
~~~
Теперь пакет должен пройти.

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Некорректный MTU на `ogstun` (blackhole MTU) |
| **Симптом в логах UE** | `ping: local error: message too long, mtu=1200` |
| **Симптом в Wireshark** | Крупные ICMP-пакеты отсутствуют; мелкие проходят. При фрагментации видны фрагменты, но ответы не возвращаются |
| **Поведение абонента** | `uesimtun0` поднят, мелкий ping проходит, крупный (`-s 1300 -M do`) — 100% loss. HTTP/загрузки зависают |
| **Локализация** | `ip link show ogstun` (Core) — MTU 1200; `ip link show uesimtun0` (RAN) — 1400. Ядро RAN-VM видит эффективный MTU 1200 и отказывается отправлять крупные пакеты с DF |
| **Устранение** | Вернуть MTU `ogstun` на 1400 (`fix_mtu.sh`), очистить кэш PMTU на RAN-VM (`ip route flush cache`) |
