# Lab 04: Dienste sicher veröffentlichen mit Caddy als Reverse Proxy

![line](images/banner.png)

## Einführung

### Aufgabe zum Erkenntnisgewinn

Bevor Sie mit der eigentlichen Konfiguration beginnen, führen Sie folgenden Schritt durch und beantworten Sie die anschließenden Fragen.

Cockpit ist ein webbasiertes Administrationswerkzeug für Linux-Server. Installieren Sie es auf Ihrem Server und rufen Sie es im Browser auf:

```bash
apt install -y cockpit
```

Öffnen Sie anschließend im Browser:

```
https://<IP-ADRESSE-IHRES-SERVERS>:9090
```

Der Browser wird eine Sicherheitswarnung anzeigen. Klicken Sie sich durch die Warnung und rufen Sie die Zertifikatsinformationen auf (je nach Browser über das Schloss-Symbol oder „Weitere Informationen").

**Leitfragen:**

- Von wem wurde das angezeigte Zertifikat ausgestellt? Handelt es sich um eine vertrauenswürdige Zertifizierungsstelle?
- Was würde passieren, wenn jemand zwischen Ihrem Browser und dem Server ein gefälschtes Zertifikat einsetzt – und Sie die Warnung trotzdem wegklicken?
- Sie sehen eine Login-Maske für Benutzername und Passwort. Wer könnte diese Eingaben mitlesen, wenn das Zertifikat nicht vertrauenswürdig ist?

Halten Sie Ihre Beobachtungen kurz fest. Sie werden am Ende dieser Übung die gleiche Oberfläche erneut aufrufen – dann jedoch mit einem gültigen, vertrauenswürdigen Zertifikat und ohne Browserwarnung.

---

### Berufliche Aufgabenstellung

Der Server steht bereit und ist per SSH administrierbar. Die nächste Anforderung aus dem Betrieb lautet: Mehrere interne Dienste sollen über das Internet erreichbar gemacht werden – darunter das Administrationswerkzeug Cockpit sowie zwei weitere Webanwendungen. Jeder Dienst soll unter einem eigenen Domänennamen erreichbar sein, ausschließlich über HTTPS mit einem gültigen, vertrauenswürdigen Zertifikat.

Gleichzeitig gilt: Nicht jeder Dienst soll öffentlich zugänglich sein. Einer der beiden Zusatzdienste soll nur nach Eingabe eines Benutzernamens und Passworts erreichbar sein. Und der Server selbst soll nach außen so wenig Angriffsfläche bieten wie möglich – nur die wirklich benötigten Ports dürfen offen sein.

Die Lösung ist ein **Reverse Proxy**: Ein einziger Dienst nimmt alle eingehenden HTTPS-Anfragen entgegen und leitet sie intern an den jeweils zuständigen Dienst weiter. Als Reverse Proxy kommt **Caddy** zum Einsatz – er übernimmt dabei auch die Verwaltung der TLS-Zertifikate vollautomatisch über Let's Encrypt.

---

## Lernziele

- **Cockpit** installieren und den unsicheren Direktzugriff als Ausgangsproblem erkennen.
- Den Server mit **ufw** auf das notwendige Minimum absichern und den Zusammenhang mit iptables verstehen.
- **Caddy** installieren und als systemd-Dienst betreiben.
- Mehrere Dienste als **virtuelle Hosts** hinter einem Reverse Proxy bündeln.
- **Automatisches HTTPS** via Let's Encrypt ohne manuelle Zertifikatsverwaltung nutzen.
- Einen Dienst mit **Basic Authentication** zusätzlich schützen.
- **HTTP-Sicherheits-Header** setzen und deren Schutzwirkung verstehen.

---

## Voraussetzungen

- Ein Linux-Server (Ubuntu 24.04 LTS) mit öffentlicher IPv4-Adresse, administrierbar per SSH
- Ein Domänenname mit DNS-Verwaltungszugriff
- Folgende DNS-A-Records zeigen bereits auf die IP-Adresse des Servers:
  - `cockpit.ihre-domain.de`
  - `dienst-a.ihre-domain.de`
  - `dienst-b.ihre-domain.de`
- SSH-Zugriff mit Key-Authentifizierung (Ergebnis aus Laborübung 01)

> **Hinweis:** Die DNS-Einträge müssen propagiert sein, bevor Caddy TLS-Zertifikate ausstellen kann. Prüfen Sie die Auflösung mit `dig cockpit.ihre-domain.de` bevor Sie fortfahren.

---

## Hintergrundwissen

### Was ist ein Reverse Proxy?

Ein Reverse Proxy ist ein Dienst, der zwischen dem Internet und den eigentlichen Anwendungen sitzt. Eingehende Anfragen erreichen ausschließlich den Proxy – dieser entscheidet anhand des angefragten Hostnamens, an welchen internen Dienst er die Anfrage weiterleitet. Für den Client im Internet ist dabei nur der Proxy sichtbar. Die internen Dienste selbst sind von außen nicht direkt erreichbar.

Das ermöglicht es, viele Dienste hinter einer einzigen IP-Adresse und einem einzigen Port (443 für HTTPS) zu bündeln, ohne dass jeder Dienst ein eigenes Zertifikat verwalten oder nach außen exponiert sein muss.

### Was ist Caddy?

Caddy ist ein moderner Webserver und Reverse Proxy, der sich durch drei Eigenschaften auszeichnet: eine sehr lesbare Konfigurationssprache (das sogenannte Caddyfile), automatisches HTTPS über das ACME-Protokoll (Let's Encrypt), und minimalen Betriebsaufwand. Caddy beantragt, erhält und erneuert TLS-Zertifikate vollständig selbständig – ohne Cronjobs, ohne manuelle Eingriffe.

### Was ist ufw und wie hängt es mit iptables zusammen?

Der Linux-Kernel enthält mit **netfilter** ein eingebautes Paketfiltersystem. **iptables** ist das klassische Kommandozeilenwerkzeug, um netfilter-Regeln zu verwalten – es ist mächtig, aber für einfache Szenarien unhandlich. **ufw** (*Uncomplicated Firewall*) ist ein vereinfachtes Frontend für iptables: Befehle wie `ufw allow https` werden intern in konkrete iptables-Regeln übersetzt. Die tatsächlich aktiven Regeln können jederzeit mit `iptables -L -n -v` eingesehen werden – ufw und iptables arbeiten auf derselben Regelgrundlage.

---

## Aufgaben

### Schritt 1: Firewall mit ufw einrichten

Bevor weitere Dienste installiert werden, schränken wir den eingehenden Datenverkehr auf das notwendige Minimum ein. Cockpit läuft aktuell noch direkt auf Port 9090 – nach dieser Übung wird es ausschließlich über Caddy auf Port 443 erreichbar sein. Port 9090 wird dann von außen nicht mehr benötigt.

1. Setzen Sie die Standardregeln – alles ablehnen, nur explizit Erlaubtes durchlassen:

```bash
ufw default deny incoming
ufw default allow outgoing
```

2. SSH muss weiterhin erreichbar sein:

```bash
ufw allow ssh
```

3. HTTP und HTTPS werden von Caddy benötigt – HTTP nur für den automatischen Let's Encrypt Challenge-Prozess:

```bash
ufw allow http
ufw allow https
```

4. Aktivieren Sie die Firewall:

```bash
ufw enable
```

5. Überprüfen Sie den Status:

```bash
ufw status verbose
```

Erwartete Ausgabe:
```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

6. Optional: Sehen Sie sich an, welche iptables-Regeln ufw im Hintergrund angelegt hat:

```bash
iptables -L -n -v
```

Sie erkennen darin die Regeln, die ufw aus Ihren Befehlen erzeugt hat – unter anderem die Erlaubnis für Port 22, 80 und 443 in der Kette `INPUT`.

> **Tipp zur Fehlerbehebung:** Wenn Sie nach `ufw enable` keinen SSH-Zugang mehr haben, hat SSH gefehlt. Nutzen Sie die Web-Konsole Ihres Anbieters (VNC/KVM) als Notfallzugang und ergänzen Sie die Regel mit `ufw allow ssh`.

---

### Schritt 2: Caddy installieren

Caddy wird über das offizielle APT-Repository installiert, damit Sicherheitsupdates einfach per `apt upgrade` eingespielt werden können.

1. Installieren Sie notwendige Hilfswerkzeuge:

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https curl
```

2. Fügen Sie den Caddy-GPG-Schlüssel und das Repository hinzu:

```bash
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' \
  | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' \
  | tee /etc/apt/sources.list.d/caddy-stable.list
```

3. Installieren Sie Caddy:

```bash
apt update && apt install caddy -y
```

4. Überprüfen Sie Installation und Dienststatus:

```bash
caddy version
systemctl status caddy
```

Caddy wird automatisch als systemd-Dienst registriert und gestartet. Die Konfigurationsdatei liegt unter `/etc/caddy/Caddyfile`.

> **Was ist systemd?**
> systemd ist das Init-System moderner Linux-Distributionen. Es verwaltet Dienste, die beim Systemstart automatisch gestartet, überwacht und bei Absturz neu gestartet werden. Mit `systemctl start | stop | restart | status caddy` steuern Sie den Caddy-Dienst.

---

### Schritt 3: Testdienste starten

Hinter dem Reverse Proxy sollen neben Cockpit zwei weitere Dienste erreichbar sein. Für diese Übung simulieren wir sie mit einfachen Python-HTTP-Servern. In einer realen Umgebung würden an dieser Stelle echte Anwendungen laufen – die Konfiguration von Caddy bliebe dabei identisch.

1. Erstellen Sie je ein Verzeichnis und eine einfache HTML-Seite für Dienst A und Dienst B:

```bash
mkdir -p /srv/dienst-a /srv/dienst-b

cat > /srv/dienst-a/index.html <<EOF
<!DOCTYPE html>
<html><body>
<h1>Dienst A</h1>
<p>Dieser Dienst ist öffentlich über Caddy erreichbar.</p>
</body></html>
EOF

cat > /srv/dienst-b/index.html <<EOF
<!DOCTYPE html>
<html><body>
<h1>Dienst B</h1>
<p>Dieser Dienst ist nur nach Authentifizierung erreichbar.</p>
</body></html>
EOF
```

2. Starten Sie beide Python-HTTP-Server als Hintergrunddienste auf verschiedenen Ports:

```bash
cd /srv/dienst-a && python3 -m http.server 8001 &
cd /srv/dienst-b && python3 -m http.server 8002 &
```

3. Prüfen Sie, ob beide Dienste intern erreichbar sind:

```bash
curl http://localhost:8001
curl http://localhost:8002
```

Beide Befehle sollten die jeweilige HTML-Seite zurückgeben.

> **Hinweis:** Die Python-Server laufen nur bis zum nächsten Neustart. In einer Produktionsumgebung würden diese Dienste als systemd-Units oder Docker-Container betrieben, die automatisch starten.

---

### Schritt 4: Basic-Auth-Passwort generieren

Dienst B soll passwortgeschützt sein. Caddy speichert Passwörter nicht im Klartext, sondern als **bcrypt-Hash**. Generieren Sie diesen Hash jetzt, bevor Sie das Caddyfile schreiben.

1. Generieren Sie den Hash für Ihr gewähltes Passwort:

```bash
caddy hash-password --plaintext 'IhrSicheresPasswort!'
```

Die Ausgabe ist ein Hash-String, der mit `$2a$` beginnt, z. B.:

```
$2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
```

2. Notieren Sie diesen Hash – er wird im nächsten Schritt in das Caddyfile eingetragen.

> **Sicherheitshinweis:** Basic Authentication überträgt Anmeldedaten Base64-kodiert. Ohne HTTPS wären diese trivial abfangbar. Da Caddy HTTPS erzwingt und automatisch auf HTTPS weiterleitet, ist die Kombination aus Basic Auth und TLS hier sicher und praxistauglich.

---

### Schritt 5: Caddy konfigurieren

Jetzt schreiben Sie das Herzstück dieser Übung: das **Caddyfile**. Es beschreibt, welcher Hostname auf welchen Dienst zeigt, wer eine Authentifizierung benötigt und welche Sicherheits-Header gesetzt werden.

Öffnen Sie die Konfigurationsdatei:

```bash
nano /etc/caddy/Caddyfile
```

Ersetzen Sie den gesamten Inhalt durch folgende Konfiguration. Passen Sie Domainnamen und Hash-Wert an Ihre Umgebung an:

```caddy
# -------------------------------------------------------
# Cockpit – Administrationsoberfläche
# -------------------------------------------------------
cockpit.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:9090 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}

# -------------------------------------------------------
# Dienst A – öffentlich erreichbar
# -------------------------------------------------------
dienst-a.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:8001
}

# -------------------------------------------------------
# Dienst B – nur nach Authentifizierung erreichbar
# -------------------------------------------------------
dienst-b.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    basicauth {
        # Benutzername: admin
        admin <HASH-AUS-SCHRITT-4-HIER-EINFÜGEN>
    }
    reverse_proxy localhost:8002
}
```

> **Hinweis zu Cockpit:** Cockpit betreibt intern selbst einen HTTPS-Dienst mit einem selbst signierten Zertifikat. Caddy kommuniziert über `localhost:9090` mit Cockpit und muss dabei dieses interne Zertifikat akzeptieren – daher `tls_insecure_skip_verify`. Nach außen hin stellt Caddy ein vollständig vertrauenswürdiges Let's Encrypt-Zertifikat bereit. Der unsichere Teil bleibt ausschließlich auf dem Server selbst und ist für den Browser des Benutzers nicht sichtbar.

Speichern Sie die Datei (`Strg+O`, `Enter`, `Strg+X`).

---

### Schritt 6: Konfiguration validieren und laden

1. Prüfen Sie die Syntax des Caddyfiles:

```bash
caddy validate --config /etc/caddy/Caddyfile
```

Bei korrekter Konfiguration erscheint:
```
Valid configuration
```

2. Laden Sie die Konfiguration neu – Caddy unterstützt Zero-Downtime-Reloads:

```bash
systemctl reload caddy
```

3. Beobachten Sie die Logs, um den automatischen Zertifikatsprozess zu verfolgen:

```bash
journalctl -u caddy -f
```

Sie sollten Einträge sehen, die den erfolgreichen Zertifikatsabruf bei Let's Encrypt bestätigen. Drücken Sie `Strg+C`, um die Ansicht zu beenden.

> **Tipp zur Fehlerbehebung:** Wenn Zertifikate nicht ausgestellt werden:
> - Prüfen Sie die DNS-Auflösung: `dig cockpit.ihre-domain.de`
> - Stellen Sie sicher, dass Port 80 in ufw offen ist: `ufw status`
> - Let's Encrypt hat Ratenlimits – prüfen Sie die Caddy-Logs auf genaue Fehlermeldungen, bevor Sie es erneut versuchen.

---

### Schritt 7: Ergebnis im Browser überprüfen

Rufen Sie nun alle drei Dienste im Browser auf und vergleichen Sie mit dem, was Sie zu Beginn dieser Übung gesehen haben.

**Cockpit:**
```
https://cockpit.ihre-domain.de
```
Der Browser zeigt jetzt ein gültiges Zertifikat, ausgestellt von **Let's Encrypt**. Es erscheint keine Sicherheitswarnung mehr. Die Login-Maske ist dieselbe wie zuvor – aber die Eingabe von Benutzername und Passwort ist nun durch TLS geschützt.

**Dienst A:**
```
https://dienst-a.ihre-domain.de
```
Die Seite lädt direkt, ohne Authentifizierung.

**Dienst B:**
```
https://dienst-b.ihre-domain.de
```
Der Browser zeigt einen Login-Dialog. Melden Sie sich mit dem Benutzernamen `admin` und dem Passwort aus Schritt 4 an.

Prüfen Sie abschließend die gesetzten HTTP-Sicherheits-Header mit `curl`:

```bash
curl -I https://dienst-a.ihre-domain.de
```

In der Ausgabe sollten alle konfigurierten Header sichtbar sein:
```
x-content-type-options: nosniff
x-frame-options: DENY
x-xss-protection: 1; mode=block
referrer-policy: strict-origin-when-cross-origin
strict-transport-security: max-age=31536000; includeSubDomains
```

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- **Cockpit** installiert und den unsicheren Direktzugriff mit selbst signiertem Zertifikat als konkretes Problem erlebt.
- Den Server mit **ufw** auf SSH, HTTP und HTTPS beschränkt und den Zusammenhang zwischen ufw und iptables nachvollzogen.
- **Caddy** als systemd-Dienst installiert und betrieben.
- Drei Dienste (Cockpit, Dienst A, Dienst B) als **virtuelle Hosts** hinter einem Reverse Proxy gebündelt.
- **Automatisches HTTPS via Let's Encrypt** ohne manuelle Zertifikatsverwaltung genutzt – Cockpit ist jetzt mit vertrauenswürdigem Zertifikat erreichbar.
- **Basic Authentication** für Dienst B eingerichtet und den Zusammenhang mit HTTPS als Voraussetzung verstanden.
- **HTTP-Sicherheits-Header** gesetzt und mit `curl` verifiziert.

---

### Das vollständige Caddyfile

```caddy
# -------------------------------------------------------
# Cockpit – Administrationsoberfläche
# -------------------------------------------------------
cockpit.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:9090 {
        transport http {
            tls_insecure_skip_verify
        }
    }
}

# -------------------------------------------------------
# Dienst A – öffentlich erreichbar
# -------------------------------------------------------
dienst-a.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:8001
}

# -------------------------------------------------------
# Dienst B – nur nach Authentifizierung erreichbar
# -------------------------------------------------------
dienst-b.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    basicauth {
        admin $2a$14$...IhrHashHier...
    }
    reverse_proxy localhost:8002
}
```

---

### Reflexion

- Welchen konkreten Unterschied haben Sie beim Aufruf von Cockpit vor und nach dieser Übung im Browser bemerkt – und was bedeutet das für einen Benutzer, der die Warnung nicht versteht?
- Warum ist es sinnvoll, dass die Backend-Dienste (Ports 8001, 8002, 9090) nur auf `localhost` gebunden sind und nicht direkt von außen erreichbar sind?
- `X-Frame-Options` ist bei Cockpit auf `SAMEORIGIN` gesetzt, bei den anderen Diensten auf `DENY`. Warum könnte das bei Cockpit notwendig sein?
- Was würde passieren, wenn jemand versucht, Dienst B direkt über `http://localhost:8002` aufzurufen – von außen, ohne Caddy?
- ufw erlaubt Port 80, obwohl alle Dienste über Port 443 erreichbar sind. Warum ist Port 80 trotzdem notwendig, und was passiert mit einer HTTP-Anfrage auf Port 80 nach der Caddy-Konfiguration?

---

## Aufräumarbeiten

1. Stoppen Sie die Python-Testserver:

```bash
kill $(lsof -t -i:8001) $(lsof -t -i:8002)
```

2. Entfernen Sie die Testinhalte:

```bash
rm -rf /srv/dienst-a /srv/dienst-b
```

3. Wenn der Server für weitere Übungen weitergenutzt wird, kann Caddy aktiv bleiben. Wenn nicht:

```bash
systemctl stop caddy
systemctl disable caddy
```

4. Falls der Server nicht mehr benötigt wird: Löschen Sie ihn im Dashboard Ihres Cloud-Anbieters, um weitere Kosten zu vermeiden.

---

## Weiterführende Ressourcen

- [Caddy Dokumentation](https://caddyserver.com/docs/) – vollständige Referenz aller Direktiven und Module
- [Caddy Caddyfile Konzepte](https://caddyserver.com/docs/caddyfile/concepts) – Erklärung der Grundstruktur des Caddyfiles
- [Let's Encrypt – Funktionsweise](https://letsencrypt.org/how-it-works/) – Hintergrundinformationen zum ACME-Protokoll und HTTP-01-Challenge
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) – Best-Practice TLS-Konfigurationen für verschiedene Servertypen
- [securityheaders.com](https://securityheaders.com) – Online-Tool zur Analyse der HTTP-Sicherheits-Header einer Domain
- [Cockpit Dokumentation](https://cockpit-project.org/documentation.html) – offizielle Dokumentation zur Einrichtung und Nutzung von Cockpit
- [ufw Manpage](https://manpages.ubuntu.com/manpages/noble/en/man8/ufw.8.html) – vollständige Referenz aller ufw-Optionen

---

## Autoren und Urheberrecht

- Erstellt von: *[Ihr Name]*
- Datum: 02/2026
- Version: v1.0

![line](images/banner.png)

<p align="center">
<a href="01_vm_domain_ssh.md"><img src="images/previous.png" width="150px"></a>
<a href="README.md"><img src="images/next.png" width="150px"></a>
</p>
