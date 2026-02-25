# OpenSSL CA scripts (одноуровневый CA)

Небольшой и поддерживаемый набор скриптов вокруг `openssl ca` для **одноуровневого** УЦ:
- Сертификаты серверов (TLS)
- Клиентские сертификаты (mTLS)
- Отзыв + CRL
- Вспомогательные команды по CA DB
- Контроль сроков действия с оповещением в Telegram (опционально)

## Структура

- `openssl.cnf` — конфигурация CA (extensions, policy, AIA/CDP, defaults)
- `CA/` — сертификат CA и приватный ключ
  - `CA/ca.crt` — сертификат CA
  - `CA/private/ca.key` — приватный ключ CA
- `newcerts/` — хранилище выданных сертификатов OpenSSL CA
- `crl/` — CRL (`crl/crl.pem`)
- `csr/` — CSR, сгенерированные скриптами
- `out/` — выданные leaf-серты/ключи/pfx
- `index.txt`, `serial`, `crlnumber`, `index.txt.attr` — файлы базы OpenSSL CA

### Файлы выданных сертификатов

`openssl ca` складывает выданные сертификаты в `newcerts/` в стандартном формате `SERIAL.pem` (через `-outdir`).

Для удобства скрипты подписи создают симлинки в `out/`:

- `out/<SERIAL>_<CN>.crt` → `newcerts/<SERIAL>.pem`

Симлинки создаются идемпотентно функцией `ensure_recent_links` (проверяются **5 последних** сертификатов в `newcerts/` и создаются отсутствующие ссылки).

## Настройка

Отредактируйте значения DN по умолчанию в `openssl.cnf` → `[ req_distinguished_name ]`:
- `countryName_default`
- `stateOrProvinceName_default`
- `localityName_default`
- `0.organizationName_default`
- `organizationalUnitName_default`
- `emailAddress_default` (опционально)

### AIA / CDP

AIA и CDP задаются **жёстко** в `openssl.cnf` в `[ aia ]` и `[ crl_dp ]` (в начале файла).
Строка OCSP оставлена **закомментированной**.

## Основные операции

### Создание CA (один раз)

```bash
./create_ca.sh
```

Что делает:
- Идемпотентно создаёт рабочие каталоги и файлы БД
- Создаёт `CA/private/ca.key` и самоподписанный `CA/ca.crt` (запросит пароль)

### Выпуск server сертификата

```bash
./gen_server.sh app1 -san "DNS.1:app1.example.local,IP.1:10.0.0.10"
```

Если `-san` не указан, используется дефолтный SAN:
- `DNS.1:<APP_NAME>.<dns_suffix>` (настраивается в `openssl.cnf`)

### Выпуск client сертификата (mTLS) + PFX

```bash
./gen_client.sh user1
```

На выходе:
- `out/user1.key` — приватный ключ
- `out/<SERIAL>_user1.crt` — клиентский сертификат
- `out/user1.pfx` — PKCS#12 (сертификат + ключ + сертификат CA)

Пароль на экспорт PFX запрашивается один раз и равен паролю шифрования ключа при генерации ключа.

### Отзыв и CRL

Отзыв:
```bash
./revoke.sh out/<SERIAL>_app1.crt
```

Генерация CRL:
```bash
./gencrl.sh
```

Проверка (CRL используется автоматически, если существует):
```bash
./verify.sh out/<SERIAL>_app1.crt
```

## Мониторинг истечения сертификатов

Список сертификатов, истекающих в течение N дней:
```bash
./expire-soon.sh 30
```

Оповещение в Telegram:
1) Скопируйте `notify.config.example` → `notify.config` и задайте значения (права 0600)
2) Запустите:
```bash
./expire-soon.sh 30 --notify
```

Переменные в конфиге:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `TELEGRAM_API_URL` (опционально, по умолчанию: https://api.telegram.org)

Можно переопределить путь до конфига:
```bash
NOTIFY_CONFIG=/etc/openssl-ca/notify.config ./expire-soon.sh 30 --notify
```

## Справочник скриптов

### Выпуск
- `create_server_csr.sh <name> [-san "..."]` — сгенерировать server ключ + CSR
- `create_client_csr.sh <name> [-san "..."]` — сгенерировать client ключ + CSR
- `sign_server_csr.sh <name>` — подписать server CSR
- `sign_client_csr.sh <name>` — подписать client CSR
- `gen_server.sh <name> [-san "..."]` — CSR + подпись (server)
- `gen_client.sh <name> [-san "..."]` — CSR + подпись (client) + экспорт PFX

### Отзыв / CRL
- `revoke.sh <cert.pem>` — отозвать сертификат (обновляет БД CA)
- `gencrl.sh` — сгенерировать CRL (`crl/crl.pem`)

### Проверка
- `verify.sh <cert.pem>` — проверить сертификат по CA (и CRL, если есть)

### Вспомогательные скрипты CA DB
- `status.sh <CN|serial>` — поиск в `index.txt` по CN/serial
- `list-valid.sh` — список действующих записей из `index.txt`
- `list-revoked.sh` — список отозванных записей из `index.txt`

### Обслуживание
- `clean.sh [--db|--all]` — очистка output; опционально сброс DB / полный сброс
