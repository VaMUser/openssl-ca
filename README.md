# OpenSSL CA scripts (single-tier)

This repository provides a small, maintainable wrapper around `openssl ca` for a **single-tier** CA:
- Server certificates (TLS)
- Client certificates (mTLS)
- Revoke + CRL
- Basic CA DB helpers
- Expiration monitoring with optional Telegram notification

## Layout

- `openssl.cnf` — CA configuration (extensions, policies, AIA/CDP, defaults)
- `private/` — CA private key (permissions 0600/0400)
- `certs/` — CA certificate (`certs/ca.crt`)
- `csr/` — CSRs (optional; scripts store CSRs in `csr/`)
- `out/` — issued leaf certs/keys/pfx
- `newcerts/` — OpenSSL CA issued cert store
- `crl/` — CRL output (`crl/ca.crl.pem`)
- `index.txt`, `serial`, `crlnumber`, `index.txt.attr` — OpenSSL CA database files

## Configuration

Edit `openssl.cnf` and set your DN defaults in `[ req_distinguished_name ]`:
- `countryName_default`
- `stateOrProvinceName_default`
- `localityName_default`
- `organizationName_default`
- `organizationalUnitName_default`

### AIA / CDP

AIA and CDP are defined **statically** in `openssl.cnf` in the `[ aia ]` and `[ crl_dp ]` sections (at the top of the file).
The OCSP line is intentionally left **commented out**.

## Common tasks

### Initialize CA
Run once (creates DB files and directories):
```bash
./init-ca.sh
```

### Issue a server certificate
```bash
./gen_server.sh app1 -san "DNS.1:app1.example.local,IP.1:10.0.0.10"
```

If `-san` is omitted, a default SAN is used:
- `DNS.1:<APP_NAME>.<dns_suffix>` (configured in `openssl.cnf`)

### Issue a client certificate (mTLS) + PFX
```bash
./gen_client.sh user1
```

This produces:
- `out/user1.key` (private key)
- `out/user1.crt` (client certificate)
- `out/user1.pfx` (PKCS#12: cert + key + CA cert)

The PFX export password is prompted once and equals the key encryption password used during key generation.

### Revoke and CRL

Revoke:
```bash
./revoke.sh out/app1.crt
```

Generate CRL:
```bash
./gencrl.sh
```

Verify with CRL check:
```bash
./verify.sh out/app1.crt
```

## Monitoring: expiring certificates

List certs expiring within N days:
```bash
./expire-soon.sh 30
```

Telegram notify:
1) Copy `notify.config.example` to `notify.config` and set values (keep permissions 0600)
2) Run:
```bash
./expire-soon.sh 30 --notify
```

Config file variables:
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `TELEGRAM_API_URL` (optional, default: https://api.telegram.org)

You can override config location:
```bash
NOTIFY_CONFIG=/etc/openssl-ca/notify.config ./expire-soon.sh 30 --notify
```

## Script reference

### Issuance
- `create_server_csr.sh <name> [-san "..."]` — generate server key + CSR
- `create_client_csr.sh <name> [-san "..."]` — generate client key + CSR
- `sign_server_csr.sh <name>` — sign server CSR
- `sign_client_csr.sh <name>` — sign client CSR
- `gen_server.sh <name> [-san "..."]` — create CSR + sign (server)
- `gen_client.sh <name> [-san "..."]` — create CSR + sign (client) + export PFX

### Revocation / CRL
- `revoke.sh <cert.pem>` — revoke certificate and (optionally) regenerate CRL
- `gencrl.sh` — generate CRL

### Verification
- `verify.sh <cert.pem>` — verify cert against CA + CRL

### CA DB helpers
- `status.sh <CN|serial>` — search `index.txt` for CN/serial
- `list-valid.sh` — list valid cert entries from `index.txt`
- `list-revoked.sh` — list revoked cert entries from `index.txt`

### Maintenance
- `clean.sh` — remove generated outputs (does not delete CA key/cert)
