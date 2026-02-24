# Laborübung: Reverse Proxy mit Caddy

![line](images/banner.png)

## Einführung

In dieser Laborübung richten Sie einen **Reverse Proxy** auf einer Linux-VM bei einem Cloud-Anbieter (z. B. Hetzner) ein. Als Werkzeug kommt **Caddy** zum Einsatz – ein moderner Webserver und Reverse Proxy, der sich durch automatisches HTTPS via **Let's Encrypt**, eine lesbare Konfigurationssprache und minimalen Betriebsaufwand auszeichnet.

Das Szenario orientiert sich an einem realen Anwendungsfall: Sie betreiben mehrere interne Dienste (z. B. eine Webanwendung und ein Monitoring-Dashboard) auf einer VM und möchten diese sicher, zentral und ortsunabhängig über das Internet erreichbar machen – ohne dabei Abstriche bei der Sicherheit zu machen.

> **Was ist ein Reverse Proxy?**
> Ein Reverse Proxy nimmt eingehende Anfragen entgegen und leitet sie intern an den eigentlichen Dienst weiter. Für den Client ist dabei nur der Proxy sichtbar, nicht der Zieldienst dahinter. Dadurch lassen sich mehrere Dienste hinter einer einzigen IP-Adresse und einem einzigen Port (443/HTTPS) bündeln, absichern und zentral verwalten.

---

## Lernziele

- Verstehen, wie ein **Reverse Proxy** funktioniert und wann er eingesetzt wird.
- **Caddy** installieren und als systemd-Dienst betreiben.
- Mehrere **virtuelle Hosts (Virtual Hosts)** in einem Caddyfile konfigurieren.
- **Automatisches HTTPS** via Let's Encrypt mit Caddy nutzen.
- Dienste mit **Basic Authentication** zusätzlich absichern.
- Die VM mit einer **Firewall (ufw)** auf das notwendige Minimum beschränken.

---

## Voraussetzungen

- Eine **Linux-VM** (Ubuntu 22.04 LTS empfohlen) bei einem Cloud-Anbieter (z. B. Hetzner, DigitalOcean, Netcup)
  - Mindestens 1 vCPU, 1 GB RAM
  - Öffentlich erreichbare IPv4-Adresse
- **SSH-Zugriff** auf die VM (Root oder sudo-Berechtigungen)
- Zwei **DNS-A-Records**, die auf die IP-Adresse der VM zeigen:
  - `app.ihre-domain.de` → IP der VM
  - `monitor.ihre-domain.de` → IP der VM
  - *(Für die Übung ohne echte Domain kann alternativ `sslip.io` oder `nip.io` genutzt werden, z. B. `app.1-2-3-4.nip.io`)*
- Ein lokaler **SSH-Client** (Terminal unter macOS/Linux, PowerShell oder PuTTY unter Windows)

> **Hinweis:** Let's Encrypt benötigt öffentlich erreichbare DNS-Einträge, um TLS-Zertifikate auszustellen. Stellen Sie sicher, dass Ihre DNS-Einträge propagiert sind, bevor Sie mit Schritt 4 beginnen.

---

## Aufgaben

### Schritt 1: VM absichern – Firewall mit ufw einrichten

Bevor Caddy installiert wird, schränken wir den eingehenden Datenverkehr auf das notwendige Minimum ein. Eine korrekt konfigurierte Firewall ist die erste Verteidigungslinie.

1. Verbinden Sie sich per SSH mit Ihrer VM:
```bash
ssh root@<IP-ADRESSE-DER-VM>
```

2. Aktualisieren Sie das System:
```bash
apt update && apt upgrade -y
```

3. Installieren Sie `ufw` (falls noch nicht vorhanden):
```bash
apt install ufw -y
```

4. Setzen Sie die Standardregeln – alles ablehnen, außer explizit erlaubtem:
```bash
ufw default deny incoming
ufw default allow outgoing
```

5. Erlauben Sie SSH, damit Sie sich nicht aussperren:
```bash
ufw allow ssh
```

6. Erlauben Sie HTTP und HTTPS (für Caddy und Let's Encrypt):
```bash
ufw allow http
ufw allow https
```

7. Aktivieren Sie die Firewall:
```bash
ufw enable
```

8. Überprüfen Sie den Status:
```bash
ufw status verbose
```

Die Ausgabe sollte in etwa so aussehen:
```
Status: active
To                         Action      From
--                         ------      ----
22/tcp                     ALLOW IN    Anywhere
80/tcp                     ALLOW IN    Anywhere
443/tcp                    ALLOW IN    Anywhere
```

> **Tipp zur Fehlerbehebung:** Wenn Sie nach `ufw enable` den SSH-Zugang verlieren, hatten Sie SSH vermutlich noch nicht erlaubt. Bei Hetzner und ähnlichen Anbietern gibt es eine Web-Konsole (VNC), über die Sie sich weiterhin einloggen und die Regel ergänzen können.

> **Warum Port 80 öffnen?**
> Let's Encrypt nutzt den HTTP-01-Challenge-Mechanismus: Es sendet eine Anfrage auf Port 80, um zu bestätigen, dass Sie die Domain kontrollieren. Caddy erledigt das vollautomatisch – Port 80 wird nur für diesen Handshake benötigt und anschließend automatisch auf HTTPS weitergeleitet.

---

### Schritt 2: Caddy installieren

Caddy wird über das offizielle APT-Repository installiert, damit zukünftige Updates einfach per `apt upgrade` eingespielt werden können.

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

3. Aktualisieren Sie die Paketlisten und installieren Sie Caddy:
```bash
apt update && apt install caddy -y
```

4. Überprüfen Sie die Installation und den Dienststatus:
```bash
caddy version
systemctl status caddy
```

Caddy wird automatisch als **systemd-Dienst** registriert und gestartet. Die Konfigurationsdatei liegt standardmäßig unter `/etc/caddy/Caddyfile`.

> **Was ist systemd?**
> systemd ist das Init-System moderner Linux-Distributionen. Es verwaltet Dienste (sog. Units), die beim Systemstart automatisch gestartet, überwacht und bei Absturz neu gestartet werden können. Mit `systemctl start/stop/restart/status caddy` steuern Sie den Caddy-Dienst.

---

### Schritt 3: Testdienste starten (Simulation von Backend-Anwendungen)

In der Praxis würden hinter dem Reverse Proxy echte Anwendungen laufen (z. B. eine Node.js-App, Grafana, Nextcloud). Für diese Übung simulieren wir zwei einfache HTTP-Dienste mit Python.

1. Erstellen Sie zwei einfache HTML-Seiten:
```bash
mkdir -p /srv/app /srv/monitor

echo "<h1>Willkommen bei der Hauptanwendung</h1>" > /srv/app/index.html
echo "<h1>Monitoring-Dashboard</h1>" > /srv/monitor/index.html
```

2. Starten Sie zwei Python-HTTP-Server als Hintergrunddienste auf verschiedenen Ports:
```bash
cd /srv/app && python3 -m http.server 8001 &
cd /srv/monitor && python3 -m http.server 8002 &
```

3. Überprüfen Sie, ob beide Dienste laufen:
```bash
curl http://localhost:8001
curl http://localhost:8002
```

> **Tipp:** In einer realen Umgebung würden diese Dienste ebenfalls als systemd-Units oder Docker-Container betrieben. Die Vorgehensweise beim Konfigurieren von Caddy bleibt dabei identisch – nur die Zieladressen im Caddyfile ändern sich.

---

### Schritt 4: Caddy als Reverse Proxy mit automatischem HTTPS konfigurieren

Jetzt kommt das Herzstück der Übung: das **Caddyfile**. Caddy liest diese Konfigurationsdatei und richtet automatisch TLS-Zertifikate ein, sobald gültige DNS-Einträge für die konfigurierten Domains vorhanden sind.

1. Öffnen Sie die Caddy-Konfigurationsdatei:
```bash
nano /etc/caddy/Caddyfile
```

2. Ersetzen Sie den gesamten Inhalt durch folgende Konfiguration. Passen Sie die Domainnamen an Ihre eigenen DNS-Einträge an:
```caddy
# Hauptanwendung
app.ihre-domain.de {
    reverse_proxy localhost:8001
}

# Monitoring-Dashboard (mit Basic Auth gesichert)
monitor.ihre-domain.de {
    basicauth {
        # Benutzername: admin
        # Passwort-Hash wird in Schritt 5 generiert
        admin <HASH-HIER-EINFÜGEN>
    }
    reverse_proxy localhost:8002
}
```

3. Speichern Sie die Datei (`Strg+O`, dann `Enter`, dann `Strg+X`).

> **Hinweis:** Lassen Sie den Platzhalter `<HASH-HIER-EINFÜGEN>` zunächst stehen. Das Passwort wird im nächsten Schritt generiert und dann eingetragen.

---

### Schritt 5: Basic Authentication einrichten

Caddy speichert Passwörter nicht im Klartext, sondern als **bcrypt-Hash**. Das Werkzeug `caddy hash-password` erzeugt diesen Hash.

1. Generieren Sie einen Hash für das gewünschte Passwort:
```bash
caddy hash-password --plaintext 'IhrSicheresPasswort!'
```

Die Ausgabe ist ein langer Hash-String, z. B.:
```
$2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
```

2. Öffnen Sie das Caddyfile erneut:
```bash
nano /etc/caddy/Caddyfile
```

3. Ersetzen Sie `<HASH-HIER-EINFÜGEN>` durch den generierten Hash. Das Ergebnis sieht so aus:
```caddy
monitor.ihre-domain.de {
    basicauth {
        admin $2a$14$Zkx19XLiW6VYouLHR5NmfOFU0z2GTNmpkT/5qqR7hx4IjWJPDhjvG
    }
    reverse_proxy localhost:8002
}
```

4. Speichern Sie die Datei.

> **Sicherheitshinweis:** Basic Authentication überträgt Anmeldedaten Base64-kodiert. Ohne HTTPS wären diese leicht abfangbar. Da Caddy **automatisch HTTPS erzwingt**, ist die Kombination aus Basic Auth und TLS hier sicher und praxistauglich.

---

### Schritt 6: Caddy-Konfiguration laden und testen

1. Überprüfen Sie die Syntax des Caddyfiles, bevor Sie es anwenden:
```bash
caddy validate --config /etc/caddy/Caddyfile
```

Bei einer korrekten Konfiguration erscheint:
```
Valid configuration
```

2. Laden Sie die Konfiguration neu (ohne Neustart – Caddy unterstützt Zero-Downtime-Reloads):
```bash
systemctl reload caddy
```

3. Beobachten Sie die Caddy-Logs, um den TLS-Zertifikatsprozess zu verfolgen:
```bash
journalctl -u caddy -f
```

Sie sollten Einträge sehen, die den Zertifikatsabruf bei Let's Encrypt bestätigen, z. B.:
```
certificate obtained successfully
```

Drücken Sie `Strg+C`, um die Live-Ansicht zu beenden.

4. Rufen Sie jetzt im Browser beide URLs auf:
   - `https://app.ihre-domain.de` → Die Hauptanwendung erscheint, Browser zeigt ein gültiges Schloss-Symbol.
   - `https://monitor.ihre-domain.de` → Ein Login-Dialog erscheint. Melden Sie sich mit `admin` und Ihrem Passwort an.

> **Tipp zur Fehlerbehebung:** Wenn das Zertifikat nicht ausgestellt wird:
> - Prüfen Sie mit `dig app.ihre-domain.de`, ob der DNS-Eintrag korrekt auf die VM-IP zeigt.
> - Stellen Sie sicher, dass Port 80 in der Firewall geöffnet ist (`ufw status`).
> - Let's Encrypt hat Ratenlimits: Bei wiederholten Fehlern prüfen Sie die Logs genau.

---

### Schritt 7: Erweiterung – Weiteren virtuellen Host hinzufügen

Ergänzen Sie nun eigenständig einen dritten virtuellen Host. Dies simuliert das Hinzufügen eines neuen Dienstes in der Praxis.

1. Starten Sie einen dritten Python-Testdienst:
```bash
mkdir -p /srv/intern
echo "<h1>Internes Portal</h1>" > /srv/intern/index.html
cd /srv/intern && python3 -m http.server 8003 &
```

2. Erstellen Sie einen weiteren DNS-A-Record:
   - `intern.ihre-domain.de` → IP der VM

3. Erweitern Sie das Caddyfile um den neuen Host:
```bash
nano /etc/caddy/Caddyfile
```

Fügen Sie am Ende hinzu:
```caddy
intern.ihre-domain.de {
    basicauth {
        admin <GLEICHER-ODER-NEUER-HASH>
    }
    reverse_proxy localhost:8003
}
```

4. Validieren und laden Sie die Konfiguration neu:
```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

5. Testen Sie `https://intern.ihre-domain.de` im Browser.

> **Reflexionsaufgabe:** Welchen Vorteil hat es, dass alle drei Dienste über Port 443 erreichbar sind, obwohl intern unterschiedliche Ports verwendet werden? Was würde sich ändern, wenn Sie keinen Reverse Proxy einsetzen würden?

---

### Schritt 8: Absicherung vertiefen – Sicherheits-Header setzen

Caddy ermöglicht es, HTTP-Sicherheits-Header für alle Antworten zu setzen. Diese Header verbessern den Schutz gegen häufige Angriffsvektoren wie Clickjacking oder Cross-Site-Scripting.

1. Öffnen Sie das Caddyfile:
```bash
nano /etc/caddy/Caddyfile
```

2. Fügen Sie dem Block der Hauptanwendung Sicherheits-Header hinzu:
```caddy
app.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:8001
}
```

3. Validieren und neu laden:
```bash
caddy validate --config /etc/caddy/Caddyfile && systemctl reload caddy
```

4. Überprüfen Sie die gesetzten Header mit `curl`:
```bash
curl -I https://app.ihre-domain.de
```

In der Ausgabe sollten alle konfigurierten Header sichtbar sein.

> **Was bewirken diese Header?**
> - `X-Frame-Options: DENY` – verhindert, dass die Seite in einem `<iframe>` eingebettet wird (Schutz gegen Clickjacking).
> - `Strict-Transport-Security` (HSTS) – weist den Browser an, die Seite dauerhaft nur über HTTPS aufzurufen.
> - `X-Content-Type-Options: nosniff` – verhindert, dass der Browser Dateitypen selbst errät, was Code-Injection erschwert.

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- Eine **VM-Firewall mit ufw** konfiguriert und auf das Minimum reduziert.
- **Caddy** als systemd-Dienst installiert und betrieben.
- Mehrere **virtuelle Hosts** hinter einem einzelnen Reverse Proxy gebündelt.
- **Automatisches HTTPS via Let's Encrypt** ohne manuelle Zertifikatsverwaltung genutzt.
- Dienste mit **Basic Authentication** zusätzlich geschützt.
- **HTTP-Sicherheits-Header** gesetzt und deren Wirkung nachvollzogen.

### Das vollständige Caddyfile im Überblick

```caddy
app.ihre-domain.de {
    header {
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "strict-origin-when-cross-origin"
        Strict-Transport-Security "max-age=31536000; includeSubDomains"
    }
    reverse_proxy localhost:8001
}

monitor.ihre-domain.de {
    basicauth {
        admin $2a$14$...
    }
    reverse_proxy localhost:8002
}

intern.ihre-domain.de {
    basicauth {
        admin $2a$14$...
    }
    reverse_proxy localhost:8003
}
```

### Reflexion

- Welche Vorteile bietet Caddy gegenüber NGINX oder Apache in diesem Szenario, insbesondere hinsichtlich der Zertifikatsverwaltung?
- Wie würde sich die Architektur verändern, wenn die Backend-Dienste als Docker-Container betrieben werden?
- Warum ist es sinnvoll, Backend-Dienste (Ports 8001–8003) nur auf `localhost` zu binden und nicht öffentlich zu exponieren?
- Welche zusätzlichen Sicherheitsmaßnahmen würden Sie in einer Produktionsumgebung ergreifen?

---

## Aufräumarbeiten

Versetzen Sie Ihre Umgebung wieder in einen aufgeräumten Zustand:

1. Beenden Sie die Python-Testserver:
```bash
kill $(lsof -t -i:8001) $(lsof -t -i:8002) $(lsof -t -i:8003)
```

2. Optional: Stoppen und deaktivieren Sie Caddy, wenn die VM nicht weiter genutzt wird:
```bash
systemctl stop caddy
systemctl disable caddy
```

3. Optional: Löschen Sie die Testinhalte:
```bash
rm -rf /srv/app /srv/monitor /srv/intern
```

4. Falls die VM nur für diese Übung erstellt wurde: Löschen Sie sie im Cloud-Dashboard, um weitere Kosten zu vermeiden.

---

## Weiterführende Ressourcen

- [Caddy Dokumentation](https://caddyserver.com/docs/) – offizielle Dokumentation mit allen Direktiven
- [Caddy Caddyfile Referenz](https://caddyserver.com/docs/caddyfile) – vollständige Übersicht aller Konfigurationsoptionen
- [Let's Encrypt Dokumentation](https://letsencrypt.org/docs/) – Hintergrundinformationen zum ACME-Protokoll
- [Mozilla SSL Configuration Generator](https://ssl-config.mozilla.org/) – Best-Practice TLS-Konfigurationen für verschiedene Server
- [securityheaders.com](https://securityheaders.com) – Online-Tool zur Überprüfung der HTTP-Sicherheits-Header einer Domain

---

## Autoren und Urheberrecht

- Erstellt von: *[Ihr Name]*
- Datum: 02/2026
- Version: v1.0

![line](images/banner.png)

<p align="center">
<a href="README.md"><img src="images/previous.png" width="150px"></a>
<a href="naechste_uebung.md"><img src="images/next.png" width="150px"></a>
</p>
