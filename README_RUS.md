# OpenSSL CA scripts (одноуровневый CA)

Этот репозиторий — небольшой и поддерживаемый набор скриптов вокруг `openssl ca` для **одноуровневого** УЦ:
- Сертификаты серверов (TLS)
- Клиентские сертификаты (mTLS)
- Отзыв + CRL
- Вспомогательные команды по CA DB
- Контроль сроков действия с оповещением в Telegram (опционально)

## Структура

- `openssl.cnf` — конфигурация CA (extensions, policy, AIA/CDP, defaults)
- `private/` — приватный ключ CA (права 0600/0400)
- `certs/` — сертификат CA (`certs/ca.crt`)
- `csr/` — CSR (опционально; скрипты сохраняют CSR в `csr/`)
- `out/` — выданные leaf-серты/ключи/pfx
- `newcerts/` — хранилище выданных сертификатов OpenSSL CA
- `crl/` — CRL (`crl/ca.crl.pem`)
- `index.txt`, `serial`, `crlnumber`, `index.txt.attr` — файлы базы OpenSSL CA

## Настройка

Отредактируйте `openssl.cnf` и задайте значения по умолчанию для DN в `[ req_distinguished_name ]`:
- `countryName_default`
- `stateOrProvinceName_default`
- `localityName_default`
- `organizationName_default`
- `organizationalUnitName_default`

### AIA / CDP

AIA и CDP задаются **жёстко** в `openssl.cnf` в секциях `[ aia ]` и `[ crl_dp ]` (в начале файла).
Строка OCSP оставлена **закомментированной**.

## Основные операции

### Инициализация CA
Один раз (создаёт каталоги и файлы БД):
```bash
./init-ca.sh
```

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
- `out/user1.key` (приватный ключ)
- `out/user1.crt` (клиентский сертификат)
- `out/user1.pfx` (PKCS#12: сертификат + ключ + сертификат CA)

Пароль на экспорт PFX запрашивается один раз и равен паролю шифрования ключа, который используется при генерации ключа.

### Отзыв и CRL

Отзыв:
```bash
./revoke.sh out/app1.crt
```

Генерация CRL:
```bash
./gencrl.sh
```

Проверка с учётом CRL:
```bash
./verify.sh out/app1.crt
```

## Мониторинг истечения сертификатов

Список сертификатов, истекающих в течение N дней:
```bash
./expire-soon.sh 30
```

Оповещение в Telegram:
1) Скопируйте `notify.config.example` в `notify.config` и задайте значения (права 0600)
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
- `create_server_csr.sh <name> [-san "..."]` — сгенерировать ключ + CSR (server)
- `create_client_csr.sh <name> [-san "..."]` — сгенерировать ключ + CSR (client)
- `sign_server_csr.sh <name>` — подписать server CSR
- `sign_client_csr.sh <name>` — подписать client CSR
- `gen_server.sh <name> [-san "..."]` — CSR + подпись (server)
- `gen_client.sh <name> [-san "..."]` — CSR + подпись (client) + экспорт PFX

### Отзыв / CRL
- `revoke.sh <cert.pem>` — отозвать сертификат и (опционально) обновить CRL
- `gencrl.sh` — сгенерировать CRL

### Проверка
- `verify.sh <cert.pem>` — проверить сертификат по CA + CRL

### Вспомогательные скрипты CA DB
- `status.sh <CN|serial>` — поиск в `index.txt` по CN/serial
- `list-valid.sh` — список действующих записей из `index.txt`
- `list-revoked.sh` — список отозванных записей из `index.txt`

### Обслуживание
- `clean.sh` — удаляет сгенерированные файлы (не удаляет ключ/сертификат CA)

## Примечания
- `create_*_csr.sh` автоматически формирует Subject из DN-defaults в `openssl.cnf` и задаёт `CN` равным переданному `<name>` (ввод CN не запрашивается интерактивно).

- CDP поддерживает несколько CRL URL через `[ crl_dp ]` + `[ crl_uris ]` (`URI.0`, `URI.1`, ...).
