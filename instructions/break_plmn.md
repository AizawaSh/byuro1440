## Демонстрация неисправности: Несовпадение PLMN

### 1. Скрипты

**`break_plmn.sh`** (RAN-VM):
~~~bash
#!/bin/bash
GNB_CONFIG="$HOME/UERANSIM/config/open5gs-gnb.yaml"
BACKUP="${GNB_CONFIG}.bak"
[ ! -f "$BACKUP" ] && cp "$GNB_CONFIG" "$BACKUP"

# Меняем PLMN в gNB на другой (001/01 вместо 999/70)
sed -i -E "s/^mcc:.*/mcc: '001'/" "$GNB_CONFIG"
sed -i -E "s/^mnc:.*/mnc: '01'/" "$GNB_CONFIG"

echo "PLMN в gNB изменён. Проверьте:"
grep -nE "^mcc:|^mnc:" "$GNB_CONFIG"
~~~

**`fix_plmn.sh`** (RAN-VM):
~~~bash
#!/bin/bash
GNB_CONFIG="$HOME/UERANSIM/config/open5gs-gnb.yaml"
BACKUP="${GNB_CONFIG}.bak"
cp "$BACKUP" "$GNB_CONFIG"
echo "PLMN восстановлен. Перезапустите gNB."
~~~

### 2. Воспроизведение

~~~bash
cd ~/UERANSIM
bash break_plmn.sh
sudo pkill -f nr-ue
sudo pkill -f nr-gnb
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml
~~~

### 3. Где искать и что смотреть

#### Логи AMF (Core-VM)

~~~bash
sudo grep -i "plmn\|ng.setup\|fail" /var/log/open5gs/amf.log | tail -20
~~~
Ищите строки:
~~~
[amf] WARNING: NG-Setup failure:
[amf] WARNING:     globalGNB_ID PLMN-ID is foreign
~~~
Это прямое указание на то, что PLMN, который прислал gNB, не совпадает с тем, что настроен в AMF [citation:12].

#### Логи gNB (RAN-VM)

В терминале, где запущен gNB, после отправки `NG Setup Request` вы не увидите `NG Setup procedure is successful`. Вместо этого будет ошибка или таймаут.

#### Wireshark (захват на dummy0)

**Фильтр для поиска NG Setup:**
~~~
ngap.procedureCode == 21
~~~
(21 — `NGSetup`)

**Где именно смотреть:**
1. Найдите пакет `NGSetupRequest` (от gNB к AMF).
2. Внутри него разверните `GlobalRANNodeID` → `GlobalGNB-ID` → `PLMNIdentity`. Вы увидите `mcc=001, mnc=01` (или те, что вы указали в скрипте).
3. Следом должен идти пакет **`NGSetupFailure`** (от AMF к gNB).
4. В `NGSetupFailure` разверните `Cause`. Причина будет связана с PLMN (например, `misc` или `plmn-not-served`) [citation:4].

> **Важно**: Если AMF настроен корректно, но в его конфигурации `plmn_support` нет PLMN, который прислал gNB, NG Setup будет отклонён. Это соответствует 3GPP TS 38.413: AMF должен отклонить процедуру, если не может обслуживать ни один из PLMN, указанных gNB [citation:12].

### 4. Устранение

~~~bash
cd ~/UERANSIM
bash fix_plmn.sh
sudo pkill -f nr-gnb
sudo ./build/nr-gnb -c config/open5gs-gnb.yaml
~~~

После перезапуска дождитесь `NG Setup procedure is successful`, затем запустите UE:
~~~bash
sudo ./build/nr-ue -c config/open5gs-ue.yaml
~~~

### 5. Сводная таблица для каталога

| Поле | Содержание |
|---|---|
| **Название** | Несовпадение PLMN между gNB и AMF |
| **Симптом в логах AMF** | `NG-Setup failure:`, `globalGNB_ID PLMN-ID is foreign` |
| **Симптом в логах gNB** | Нет `NG Setup procedure is successful`, ошибка или таймаут |
| **Симптом в Wireshark** | `NGSetupRequest` содержит PLMN, отличный от AMF; ответ — `NGSetupFailure` с причиной, связанной с PLMN |
| **Поведение абонента** | gNB не подключается к Core, UE не видит сеть или не может зарегистрироваться |
| **Локализация** | Сравнить `mcc`/`mnc` в `open5gs-gnb.yaml` и в `amf.yaml` (секции `guami`, `tai`, `plmn_support`) |
| **Устранение** | Вернуть корректный PLMN в gNB (`fix_plmn.sh`), перезапустить gNB |
