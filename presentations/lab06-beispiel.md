---
marp: true
theme: linux-theme
paginate: true
header: '![h:60](../images/logo.jpg)'
footer: 'Linux Administration 2026 | Lab 06: nginx mit ACME | Florian Reichl'
---

<!-- _class: title -->

# Lab 06: nginx mit ACME
## Linux Administration 2026

Florian Reichl, Michael Lotter

---

## Agenda

1. **ACME als Protokoll** verstehen
2. nginx mit ACME-Modul installieren
3. Zertifikatskonfiguration einrichten
4. Virtuelle Hosts migrieren
5. Ergebnis prüfen

---

## Was ist ACME?

**ACME** = *Automated Certificate Management Environment*

- Entwickelt von **Let's Encrypt**
- Standardisiertes Protokoll (RFC 8555)
- Automatische Zertifikatsausstellung
- Kostenlos und offen

> **Warum wichtig?** ISO 27001 Control A.8.24 verlangt dokumentierte Kryptographie-Entscheidungen

---

## nginx Installation

```bash
# Repository hinzufügen
curl -fsSL https://nginx.org/keys/nginx_signing.key \
  | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg

# nginx mit ACME-Modul installieren
apt update
apt install -y nginx nginx-module-acme

# Dienst starten
systemctl enable --now nginx
nginx -v
```

---

## ACME-Modul aktivieren

```nginx
# /etc/nginx/nginx.conf (erste Zeile)
load_module modules/ngx_http_acme_module.so;
```

**Warum?**
- Modul muss vor `events {}` geladen werden
- Ermöglicht ACME-Direktiven in der Konfiguration
- Einmalig, dann dauerhaft aktiv

---

## ACME-Issuer konfigurieren

```nginx
# /etc/nginx/conf.d/acme.conf
resolver 8.8.8.8 valid=300s;

acme_shared_zone zone=acme_shared:1M;

acme_issuer letsencrypt {
    uri https://acme-v02.api.letsencrypt.org/directory;
    contact mailto:admin@example.com;
    state_path /var/lib/nginx/acme-letsencrypt;
    accept_terms_of_service;
}
```

> **Wichtig:** `accept_terms_of_service` muss explizit gesetzt werden!

---

## Server-Block konfigurieren

```nginx
# /etc/nginx/conf.d/cockpit.conf
server {
    listen 443 ssl;
    server_name cockpit.example.com;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass https://127.0.0.1:9090;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
    }
}
```

---

## Dienste-Übersicht

| Dienst | Port | Besonderheit |
|--------|------|--------------|
| Cockpit | 9090 | WebSocket-Support |
| Dienst A | 8001 | Python HTTP Server |
| Dienst B | 8002 | Basic Auth erforderlich |
| nginx-web | 8080 | Docker-Container |
| Node-RED | 1880 | Docker mit adminAuth |

**Alle** über nginx mit ACME-Zertifikaten erreichbar!

---

## Zertifikate prüfen

```bash
# Konfiguration testen
nginx -t

# nginx neu laden
systemctl reload nginx

# Logs beobachten
journalctl -u nginx -f

# Zertifikat prüfen
openssl s_client -connect cockpit.example.com:443 -servername cockpit.example.com < /dev/null
```

---

## Vorher / Nachher

**Vorher (Caddy):**
```
# Caddyfile
cockpit.example.com {
    reverse_proxy https://localhost:9090
}
```
✗ Issuer nicht dokumentiert  
✗ Protokoll implizit

**Nachher (nginx + ACME):**
✓ Issuer explizit: Let's Encrypt  
✓ Protokoll dokumentiert: ACME v02  
✓ Audit-Nachweis vorhanden

---

## Zusammenfassung

✅ ACME als offenes Protokoll verstanden  
✅ nginx mit nativem ACME-Modul installiert  
✅ Zertifikatsanbieter explizit konfiguriert  
✅ Fünf virtuelle Hosts migriert  
✅ Auditierbare Dokumentation geschaffen

**ISO 27001 Control A.8.24** erfüllt! ✓

---

## Weiterführende Themen

- **Lab 07:** Docker-Netzwerke segmentieren
- **Lab 08:** Eigene Docker-Images bauen
- **Lab 09:** Docker Compose einsetzen

Alle mit nginx als Reverse Proxy!

---

<!-- _class: title -->

# Vielen Dank!

## Fragen?

Nächstes Lab: Docker-Netzwerksegmentierung für ISO 27001 Control A.8.22

