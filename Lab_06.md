# Lab 06: Reverse Proxy ablösen und Docker-Netzwerke segmentieren für die ISO-27001-Zertifizierung

![line](images/banner.png)

## Berufliche Aufgabenstellung

Das Unternehmen bereitet sich auf die Zertifizierung nach ISO/IEC 27001 vor. Im Rahmen der Auditvorbereitung hat ein externer Pentest die bestehende Infrastruktur überprüft und zwei Feststellungen dokumentiert, die vor dem eigentlichen Zertifizierungsaudit behoben werden müssen.

Erstens: Die TLS-Zertifikate werden vollständig automatisiert über Caddy bezogen, ohne dass nachvollziehbar dokumentiert ist, über welches Protokoll und von welchem Anbieter dies geschieht. Für Control **A.8.24 (Use of Cryptography)** der ISO 27001:2022 verlangt der Auditor eine nachvollziehbare, bewusst getroffene und dokumentierte Entscheidung über die eingesetzten kryptografischen Verfahren – ein impliziter Automatismus reicht dafür nicht aus.

Zweitens: Sämtliche Docker-Container laufen im selben, nicht weiter unterteilten Standardnetzwerk; mehrere Backend-Dienste sind zudem über Host-Ports erreichbar, obwohl das nicht erforderlich wäre. Für Control **A.8.22 (Segregation of Networks)**, in Verbindung mit **A.8.20 (Networks Security)**, verlangt der Auditor eine erkennbare, begründete Trennung zusammengehöriger Dienste in eigene Netzwerksegmente.

Im Rahmen des Risikobehandlungsplans gibt die Leitungsebene die Umsetzung frei; das Betriebsteam wird als Maßnahmenverantwortlicher (Risk Owner) für beide Feststellungen benannt, mit dem Ziel, sie vor dem Zertifizierungsaudit zu beheben: Caddy wird durch nginx mit dem nativen ACME-Modul abgelöst, wodurch Zertifikatsanbieter und -protokoll explizit konfiguriert und damit auditierbar dokumentiert werden. Gleichzeitig werden zusammengehörige Container-Dienste bewusst in eigenen Docker-Netzwerken gebündelt, statt unkontrolliert im Default-Netz zu laufen.

---

## Einführung

In Lab 04 und Lab 05 hat Caddy die Zertifikatsverwaltung vollständig automatisch übernommen – komfortabel, aber für ein Audit eine Black Box: Welcher Anbieter wird genutzt? Über welches Protokoll? Wer hat das entschieden? In diesem Lab lösen Sie Caddy durch **nginx** ab und konfigurieren die Zertifikatsausstellung mit dem seit 2025 verfügbaren, nativen `ngx_http_acme_module` explizit selbst. Anschließend bündeln Sie zusammengehörige Docker-Container gezielt in einem eigenen Netzwerk, statt sie unkontrolliert im Default-Netz laufen zu lassen. Zum Abschluss richten Sie eine einfache, manuell gepflegte Lastverteilung über mehrere Container-Instanzen ein – und erleben dabei bewusst den Unterschied zu einer automatisierten Lösung wie Traefik.

## Lernziele

- ACME als offenes Protokoll verstehen und einen Zertifikatsanbieter (Issuer) bewusst und explizit konfigurieren
- nginx aus dem offiziellen Repository inklusive des nativen ACME-Moduls installieren und einrichten
- Mehrere virtuelle Hosts manuell als nginx-Server-Blöcke konfigurieren und den Unterschied zur automatisierten Caddy-Lösung nachvollziehen
- Ein eigenes Docker-Netzwerk anlegen, um zusammenhängende Container-Dienste gezielt zu bündeln und von anderen Diensten zu trennen
- Mehrere Container-Instanzen eines Dienstes manuell als nginx-Upstream-Gruppe für die Lastverteilung konfigurieren
- Die ISO-27001-Controls A.8.20, A.8.22 und A.8.24 mit konkreten technischen Maßnahmen in Verbindung bringen

## Voraussetzungen

| Anforderung | Details |
|---|---|
| **Server** | Ubuntu 24.04 LTS, öffentliche IPv4-Adresse (aus Lab 03) |
| **Caddy** | Aktuell noch aktiv – wird in diesem Lab abgelöst |
| **Docker** | Installiert und betriebsbereit (aus Lab 05), inklusive der Container `nginx-web` und `nodered` |
| **SSH-Zugriff** | Key-Authentifizierung |
| **DNS** | Bestehende A-Records aus Lab 03–05 (`cockpit`, `dienst-a`, `dienst-b`, `www`, `dashboard`), zusätzlich ein neuer A-Record `demo.ihre-domain.de` |

---

## Hintergrundwissen

### ACME als offenes Protokoll

ACME (*Automated Certificate Management Environment*) ist ein offenes, standardisiertes Protokoll zur automatisierten Ausstellung und Erneuerung von TLS-Zertifikaten – ursprünglich von Let's Encrypt entwickelt, heute von zahlreichen Zertifizierungsstellen unterstützt. Caddy, Traefik, Certbot und nginx sind allesamt nur unterschiedliche **ACME-Clients**, die mit einem austauschbaren **Issuer** (der Zertifizierungsstelle) sprechen. Diese Trennung von Werkzeug und Anbieter ist genau der Punkt, der bei Caddys impliziter Automatik im Audit nicht sichtbar war – und den Sie in diesem Lab bewusst offenlegen.

### Das native ACME-Modul von nginx

Seit August 2025 bietet nginx mit `ngx_http_acme_module` ein offizielles, in Rust implementiertes Modul, das ACMEv2 direkt in der nginx-Konfiguration abbildet – sowohl für nginx Open Source als auch für NGINX Plus. Statt eines impliziten Automatismus definieren Sie einen benannten `acme_issuer`-Block mit der Server-URI der Zertifizierungsstelle, ordnen ihn explizit einem virtuellen Host über `acme_certificate` zu und richten einen eigenen Listener für die HTTP-01-Challenge ein. Aktuell wird ausschließlich die HTTP-01-Challenge unterstützt; DNS-01 ist für künftige Versionen angekündigt.

### Docker-Netzwerke als Bündelungskonzept

Im Default-Bridge-Netzwerk von Docker können sich grundsätzlich alle Container gegenseitig erreichen – unabhängig davon, ob sie inhaltlich zusammengehören. Ein eigenes, benutzerdefiniertes Netzwerk dient nicht primär der Automatisierung, sondern der bewussten **Bündelung zusammengehöriger Dienste** und der **Abgrenzung** gegenüber allem, was nicht dazugehört – genau das, was Control A.8.22 verlangt. In einer späteren Übung werden Sie dieses Prinzip in größerem Maßstab wiederverwenden: eine zeitbasierte Datenbank (z. B. InfluxDB), ein Connector-Dienst und eine Visualisierung (z. B. Grafana) werden dann gemeinsam in einem eigenen Netzwerk laufen, ohne dass die Datenbank selbst von außen erreichbar sein muss. In diesem Lab üben Sie das Prinzip bereits an einem kleinen Beispiel.

### Ein kurzer Rückblick: automatische vs. bewusste Konfiguration

Ein Werkzeug wie Traefik hätte neue Container automatisch über Labels erkannt und sofort in die Lastverteilung aufgenommen – komfortabel, aber für ein Audit schwer nachvollziehbar, *wann* und *wodurch* eine Änderung wirksam wurde. Die in diesem Lab bewusst gewählte, manuelle Konfiguration über nginx erzeugt mehr Aufwand, aber auch maximale Nachvollziehbarkeit: Jede Änderung ist ein dokumentierter Schritt in einer Konfigurationsdatei.

---

## Aufgaben

### Schritt 1: Caddy ablösen

Stoppen und deaktivieren Sie Caddy. Das Caddyfile bleibt als Referenz erhalten, wird aber nicht mehr verwendet.

```bash
systemctl stop caddy
systemctl disable caddy
```

Prüfen Sie, dass die Ports 80 und 443 frei sind:

```bash
ss -tlnp | grep -E ':80 |:443 '
```

Die Ausgabe sollte leer sein.

---

### Schritt 2: nginx aus dem offiziellen Repository installieren

Wie schon bei Caddy (Lab 04) und Docker (Lab 05) installieren Sie nginx nicht aus den Ubuntu-Standardquellen, sondern aus dem offiziellen nginx-Repository – nur dort ist das aktuelle ACME-Modul verfügbar.

```bash
apt install -y curl gnupg2 ca-certificates lsb-release

curl -fsSL https://nginx.org/keys/nginx_signing.key \
  | gpg --dearmor | tee /usr/share/keyrings/nginx-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/ubuntu $(lsb_release -cs) nginx" \
  | tee /etc/apt/sources.list.d/nginx.list
```

> **Tipp zur Fehlerbehebung:** Bricht `apt update` anschließend mit einer Meldung wie „The repository ... does not have a Release file" ab, prüfen Sie zunächst die tatsächliche Distribution Ihres Systems:
> ```bash
> cat /etc/os-release
> ```
> Steht dort `ID=ubuntu`, muss `VERSION_CODENAME` einen echten Ubuntu-Codename liefern (für 24.04 LTS: `noble`) – weicht der von `lsb_release -cs` gelieferte Wert davon ab, tragen Sie „noble" händisch in die Repository-Zeile ein. Steht dort hingegen `ID=debian` (z. B. `VERSION_CODENAME=trixie` für Debian 13), testen Sie auf einem Debian- statt einem Ubuntu-System wie in Lab 03 vorgesehen. nginx.org pflegt für Debian einen eigenen Pfad – ersetzen Sie in der Repository-Zeile `/ubuntu` durch `/debian`:
> ```bash
> rm /etc/apt/sources.list.d/nginx.list
> echo "deb [signed-by=/usr/share/keyrings/nginx-archive-keyring.gpg] http://nginx.org/packages/mainline/debian $(lsb_release -cs) nginx" \
>   | tee /etc/apt/sources.list.d/nginx.list
> apt update
> ```

Damit apt bei künftigen Updates konsequent das offizielle nginx-Paket statt der älteren Distributionsvariante bevorzugt, legen Sie eine Pinning-Regel an:

```bash
printf 'Package: *\nPin: origin nginx.org\nPin-Priority: 900\n' \
  | tee /etc/apt/preferences.d/99nginx
```

Paketliste aktualisieren und nginx mitsamt ACME-Modul installieren:

```bash
apt update
apt install -y nginx nginx-module-acme
```

Prüfen Sie die Installation:

```bash
nginx -v
systemctl enable --now nginx
curl http://localhost
```

Die letzte Zeile sollte die Standard-Begrüßungsseite von nginx liefern.

---

### Schritt 3: ACME-Modul aktivieren und Issuer konfigurieren

Das Modul muss als Erstes im Hauptkontext von nginx geladen werden:

```bash
nano /etc/nginx/nginx.conf
```

Fügen Sie als erste Zeile der Datei ein:

```nginx
load_module modules/ngx_http_acme_module.so;
```

> **Warum ganz oben?**  
> `load_module` muss im Hauptkontext stehen, bevor `events {}` oder `http {}` beginnen – nginx lädt dynamische Module beim Start, nicht zur Laufzeit.

Legen Sie ein Verzeichnis für die Zertifikatsdaten an und übergeben Sie es dem nginx-Benutzer (das offizielle nginx-Paket führt Worker-Prozesse unter dem Benutzer `nginx`, nicht `www-data`- das wäre der Benutzer bei der Debian-eigenen nginx-Variante):

```bash
mkdir -p /var/lib/nginx/acme-letsencrypt
chown -R nginx:nginx /var/lib/nginx/acme-letsencrypt
```

Erstellen Sie die ACME-Konfiguration:

```bash
nano /etc/nginx/conf.d/acme.conf
```

```nginx
resolver 8.8.8.8 valid=300s;

acme_shared_zone zone=acme_shared:1M;

acme_issuer letsencrypt {
    uri https://acme-v02.api.letsencrypt.org/directory;
    contact mailto:admin@ihre-domain.de;
    state_path /var/lib/nginx/acme-letsencrypt;
    accept_terms_of_service;
}
```

> **Was passiert hier?**  
> `resolver` wird benötigt, damit das Modul die Adresse der Zertifizierungsstelle außerhalb der normalen Anfragebearbeitung selbst auflösen kann. `acme_issuer` definiert explizit, welcher Anbieter über welches Protokoll angesprochen wird – genau die Nachvollziehbarkeit, die im Audit gefordert ist. `accept_terms_of_service` ist eine bewusste, im Klartext sichtbare Zustimmung zu den Nutzungsbedingungen von Let's Encrypt.

Richten Sie zusätzlich einen Listener für die HTTP-01-Challenge ein, der gleichzeitig unverschlüsselte Anfragen auf HTTPS umleitet:

```bash
nano /etc/nginx/conf.d/challenge.conf
```

```nginx
# Virtueller Host für unverschlüsselte HTTP-Anfragen (Port 80)
server {
    # Lauscht auf Port 80. "default_server" macht diesen Block zum
    # Auffangbecken für ALLE Anfragen auf Port 80, die keinem anderen
    # Server-Block (z. B. cockpit.conf, dienst-a.conf) über server_name
    # zugeordnet werden können.
    listen 80 default_server;

    # Gilt für jeden angefragten Pfad - "/" fängt alles ab, was nicht
    # durch eine spezifischere location-Regel abgedeckt ist.
    location / {
        # Antwortet mit HTTP-Statuscode 301 (dauerhafte Weiterleitung)
        # und leitet auf dieselbe Adresse, aber über HTTPS, um.
        # $host        = der angefragte Hostname, z. B. cockpit.ihre-domain.de
        # $request_uri = der vollständige ursprüngliche Pfad inkl. Query-String
        # Beispiel: http://dienst-a.ihre-domain.de/seite?x=1
        #        -> https://dienst-a.ihre-domain.de/seite?x=1
        return 301 https://$host$request_uri;
    }
}
```

Da `load_module` nur beim vollständigen Start eingelesen wird, genügt hier kein einfaches Reload:

```bash
nginx -t
systemctl restart nginx
```

> **Tipp zur Fehlerbehebung:** Falls die spätere Zertifikatsausstellung fehlschlägt, prüfen Sie zunächst, ob der Redirect in `challenge.conf` die Challenge-Anfrage blockiert. Ersetzen Sie ihn zum Testen vorübergehend durch `return 404;` und prüfen Sie erneut.

---

### Schritt 4: Cockpit als nginx-Server-Block migrieren

Erstellen Sie die Konfiguration für Cockpit:

```bash
nano /etc/nginx/conf.d/cockpit.conf
```

```nginx
server {
    listen 443 ssl;
    server_name cockpit.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass https://127.0.0.1:9090;
        proxy_ssl_verify off;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```
#### Diese Konfiguration im Detail

`listen 443 ssl;` lässt diesen Server-Block verschlüsselte Verbindungen auf Port 443 annehmen – das `ssl` weist nginx an, hier einen TLS-Handshake durchzuführen, bevor irgendein Inhalt ausgeliefert wird. 

`server_name cockpit.ihre-domain.de;` legt fest, dass dieser Block nur für Anfragen mit genau diesem Hostnamen zuständig ist – anhand des SNI beim TLS-Handshake entscheidet nginx, welcher von mehreren Server-Blöcken auf Port 443 eine konkrete Anfrage bearbeitet.

`acme_certificate letsencrypt;` ist die zentrale Anweisung: Sie teilt dem ACME-Modul mit, für `cockpit.ihre-domain.de` (der Name wird automatisch aus `server_name` übernommen) jederzeit ein gültiges Zertifikat über den zuvor definierten Issuer `letsencrypt` bereitzuhalten. Das Modul überwacht die Restlaufzeit selbst und stößt die Erneuerung rechtzeitig vor **Ablauf der 90 Tage** an, ohne dass Sie eingreifen müssen.

`ssl_certificate $acme_certificate;` und `ssl_certificate_key $acme_certificate_key;` verweisen – im Unterschied zu sonst üblichen, statischen Dateipfaden – auf **Variablen**, die das ACME-Modul bereitstellt. Bei einer Erneuerung tauscht das Modul den Inhalt dieser Variablen aus; neue Verbindungen erhalten sofort das aktuelle Zertifikat, ohne dass ein `nginx -t` oder `systemctl reload` nötig wäre. Das unterscheidet diese Lösung von einer klassischen, statischen Konfiguration mit Certbot (alter Lösungsansatz für ACME), bei der nach jeder Erneuerung ein Reload erforderlich ist. 

`ssl_certificate_cache max=2;` ist eine reine Performance-Einstellung: nginx hält bis zu zwei geparste Zertifikate im Cache vor, unter anderem für die kurze Übergangsphase zwischen altem und neu ausgestelltem Zertifikat.

Damit diese Automatik dauerhaft funktioniert, müssen drei Voraussetzungen erhalten bleiben: Port 80 muss über `ufw` weiterhin für die HTTP-01-Challenge erreichbar sein, die DNS-A-Records müssen weiterhin auf diesen Server zeigen, und das Verzeichnis `/var/lib/nginx/acme-letsencrypt` darf nicht gelöscht werden, da dort Konto-Schlüssel und Status liegen.

Im `location`-Block regelt `proxy_pass https://127.0.0.1:9090;` die Weiterleitung an Cockpit. 
`proxy_ssl_verify off;` ist das nginx-Äquivalent zu Caddys `tls_insecure_skip_verify` aus Lab 04 – Cockpit betreibt intern weiterhin ein selbst signiertes Zertifikat auf Port 9090, das nur für diese lokale Verbindung akzeptiert werden muss; unkritisch, da diese Verbindung nie den Server verlässt. 
`proxy_set_header X-Real-IP $remote_addr;` gibt die tatsächliche Client-IP an Cockpit weiter – ohne diese Zeile würde Cockpit in seinen eigenen Logs nur die IP von nginx selbst sehen, was der im Audit geforderten Nachvollziehbarkeit widerspräche. Das wäre bei einem Zugriff aus einem Heimnetz über den Heimrouter die öffentliche IP des Heimrouters.
Die drei Zeilen `proxy_http_version 1.1;`, `proxy_set_header Upgrade $http_upgrade;` und `proxy_set_header Connection "upgrade";` ermöglichen WebSocket-Verbindungen durch den Proxy hindurch, die Cockpit für Live-Updates (z. B. Terminal, Ressourcen-Graphen) benötigt.


Validieren und laden Sie die Konfiguration:

```bash
nginx -t
systemctl reload nginx
```

Beobachten Sie die Ausstellung des Zertifikats:

```bash
journalctl -u nginx -f
```

Rufen Sie anschließend `https://cockpit.ihre-domain.de` im Browser auf und prüfen Sie im Zertifikat: Aussteller Let's Encrypt, keine Sicherheitswarnung.

---

### Schritt 5: Die übrigen Dienste analog migrieren

Wiederholen Sie das Muster für die restlichen vier Dienste.

**Dienst A** (`/etc/nginx/conf.d/dienst-a.conf`):

```nginx
server {
    listen 443 ssl;
    server_name dienst-a.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass http://127.0.0.1:8001;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Dienst B** benötigt zusätzlich Basic Authentication. Erzeugen Sie zunächst eine Passwortdatei:

```bash
apt install -y apache2-utils
htpasswd -B -c /etc/nginx/.htpasswd admin
```

> **Vergleich mit Caddy:** Caddy hat den bcrypt-Hash mit `caddy hash-password` direkt ins Caddyfile geschrieben. nginx benötigt dafür eine separate Datei und das Werkzeug `htpasswd` aus den Apache-Hilfsprogrammen – derselbe Hash-Algorithmus (bcrypt, Option `-B`), aber ein anderer Aufbewahrungsort.

`/etc/nginx/conf.d/dienst-b.conf`:

```nginx
server {
    listen 443 ssl;
    server_name dienst-b.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    auth_basic "Geschützter Bereich";
    auth_basic_user_file /etc/nginx/.htpasswd;

    location / {
        proxy_pass http://127.0.0.1:8002;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Unternehmenswebseite** (`/etc/nginx/conf.d/www.conf`), Container aus Lab 05 auf Host-Port 8080:

```nginx
server {
    listen 443 ssl;
    server_name www.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Node-RED Dashboard** (`/etc/nginx/conf.d/dashboard.conf`), Container aus Lab 05 auf Host-Port 1880:

```nginx
server {
    listen 443 ssl;
    server_name dashboard.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass http://127.0.0.1:1880;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

Validieren und laden Sie nach jeder Datei neu:

```bash
nginx -t
systemctl reload nginx
```

Verschaffen Sie sich am Ende einen Überblick über alle angelegten Konfigurationsdateien:

```bash
ls -la /etc/nginx/conf.d/
```

| Datei | Zuständigkeit |
|---|---|
| `acme.conf` | ACME-Issuer und Shared Zone |
| `challenge.conf` | HTTP-01-Challenge und Redirect auf HTTPS |
| `cockpit.conf` | Cockpit-Weboberfläche |
| `dienst-a.conf` | Öffentlich erreichbarer Demo-Dienst |
| `dienst-b.conf` | Demo-Dienst mit Basic Authentication |
| `www.conf` | Unternehmenswebseite (Docker-Container) |
| `dashboard.conf` | Node-RED-Dashboard (Docker-Container) |

---

### Schritt 6: Ergebnis im Browser prüfen

Rufen Sie alle fünf Domains auf und prüfen Sie jeweils das Zertifikat (Aussteller: Let's Encrypt, keine Browserwarnung):

```
https://cockpit.ihre-domain.de
https://dienst-a.ihre-domain.de
https://dienst-b.ihre-domain.de
https://www.ihre-domain.de
https://dashboard.ihre-domain.de
```

Vergewissern Sie sich, dass Caddy nicht mehr läuft:

```bash
systemctl status caddy
```

Der Dienst muss als `inactive (dead)` gemeldet sein.

---

### Schritt 7: Eigenes Docker-Netzwerk anlegen und Dienste bewusst bündeln

Legen Sie ein eigenes Netzwerk für zusammengehörige Dienste an:

```bash
docker network create app-net
```

Hängen Sie den bereits laufenden `nodered`-Container zusätzlich an dieses Netzwerk an – ohne ihn neu erstellen zu müssen, ein Container kann mehreren Netzwerken gleichzeitig angehören:

```bash
docker network connect app-net nodered
```

Starten Sie einen kleinen, rein internen Datenhaltungsdienst, der **bewusst keinen Host-Port** veröffentlicht – er soll ausschließlich innerhalb von `app-net` erreichbar sein:

```bash
docker run -d \
  --name redis-cache \
  --restart unless-stopped \
  --network app-net \
  redis:7
```

> **Vorgriff:** In einer späteren Übung übernehmen eine Zeitreihendatenbank (z. B. InfluxDB), ein Connector-Dienst und eine Visualisierung (z. B. Grafana) genau dieses Muster – mehrere zusammenspielende Container in einem eigenen Netzwerk, von denen nur die Visualisierung nach außen erreichbar sein muss. `redis-cache` steht hier stellvertretend für diesen späteren Datenhaltungsdienst.

Prüfen Sie die Namensauflösung innerhalb von `app-net` mit einem flüchtigen Test-Container:

```bash
docker run --rm --network app-net alpine getent hosts redis-cache
```

Die Ausgabe zeigt die interne IP-Adresse von `redis-cache`. Prüfen Sie nun zur Gegenprobe, ob ein Container **außerhalb** von `app-net` denselben Namen auflösen kann:

```bash
docker run --rm alpine getent hosts redis-cache
```

Dieser Befehl liefert keine Auflösung – der Name ist nur innerhalb des Netzwerks bekannt, dem `redis-cache` zugewiesen wurde.

Bestätigen Sie zusätzlich, dass `redis-cache` auf dem Host selbst keinen offenen Port hinterlässt:

```bash
ss -tlnp | grep 6379
```

Die Ausgabe sollte leer sein – im Unterschied zu den Containern aus Lab 05, die bewusst über `-p` veröffentlicht wurden, ist hier gar kein Host-Port nötig, weil nur `nodered` als Partner im selben Netzwerk darauf zugreifen muss.

---

### Schritt 8: Lastverteilung einrichten und Last erzeugen

Ergänzen Sie zunächst den DNS-A-Record `demo.ihre-domain.de` analog zu den bisherigen Einträgen und prüfen Sie die Auflösung:

```bash
dig demo.ihre-domain.de +short
```

Starten Sie drei Instanzen eines einfachen Demo-Dienstes, der bei jeder Antwort seinen eigenen Containernamen zurückgibt:

```bash
docker run -d --name demo1 --restart unless-stopped -p 9001:80 traefik/whoami
docker run -d --name demo2 --restart unless-stopped -p 9002:80 traefik/whoami
docker run -d --name demo3 --restart unless-stopped -p 9003:80 traefik/whoami
```

Tragen Sie alle drei Instanzen händisch als Upstream-Gruppe in nginx ein:

```bash
nano /etc/nginx/conf.d/demo.conf
```

```nginx
upstream demo_backend {
    server 127.0.0.1:9001;
    server 127.0.0.1:9002;
    server 127.0.0.1:9003;
}

server {
    listen 443 ssl;
    server_name demo.ihre-domain.de;

    acme_certificate letsencrypt;
    ssl_certificate $acme_certificate;
    ssl_certificate_key $acme_certificate_key;
    ssl_certificate_cache max=2;

    location / {
        proxy_pass http://demo_backend;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

```bash
nginx -t
systemctl reload nginx
```

Erzeugen Sie mehrere Anfragen und beobachten Sie die Verteilung anhand des jeweils zurückgegebenen Containernamens:

```bash
for i in $(seq 1 12); do curl -s https://demo.ihre-domain.de | grep Hostname; done
```

Sie sollten alle drei Container-Hostnamen im Round-Robin-Wechsel sehen. Optional können Sie mit einem echten Lasttest-Werkzeug eine größere Anfragenzahl erzeugen:

```bash
ab -n 100 -c 10 https://demo.ihre-domain.de/
```

Fügen Sie nun bewusst eine vierte Instanz hinzu:

```bash
docker run -d --name demo4 --restart unless-stopped -p 9004:80 traefik/whoami
```

Tragen Sie sie händisch in die Upstream-Gruppe ein:

```bash
nano /etc/nginx/conf.d/demo.conf
```

```nginx
upstream demo_backend {
    server 127.0.0.1:9001;
    server 127.0.0.1:9002;
    server 127.0.0.1:9003;
    server 127.0.0.1:9004;
}
```

```bash
nginx -t
systemctl reload nginx
```

Wiederholen Sie den Testlauf aus diesem Schritt – `demo4` erscheint erst jetzt in der Verteilung, und zwar genau deshalb, weil Sie es bewusst eingetragen und neu geladen haben, nicht weil es automatisch erkannt wurde.

---

## Reflexion und weiterführende Fragen

**Zur ISO-27001-Vorbereitung**

- Welche der beiden Pentest-Feststellungen lässt sich anhand der nginx-Konfiguration jetzt konkret nachweisen – und was genau würde ein Auditor dafür sehen wollen?
- Warum reicht für Control A.8.22 nicht allein die technische Netzwerktrennung, sondern auch eine dokumentierte Begründung, welche Dienste zusammengehören?
- Vergleichen Sie den Aufwand für eine neue Subdomain bei Caddy (Lab 04) mit dem Aufwand bei nginx mit ACME-Modul – was hat sich an Übersicht und Kontrolle verändert, was an Komfort?

**Zu Docker-Netzwerken**

- Was unterscheidet die Situation von `redis-cache` von den Containern aus Lab 05, die über `-p` veröffentlicht wurden? Welches Risiko wird durch das Fehlen eines Host-Ports konkret reduziert?
- Wie würde sich das Vorgehen ändern, wenn statt zwei künftig drei oder vier zusammenspielende Dienste in einem Netzwerk gebündelt werden müssten?

**Zur Lastverteilung**

- Was unterscheidet das manuelle Eintragen von `demo4` in die Upstream-Gruppe vom automatischen Verhalten, das Traefik bieten würde?
- Für welche Art von Produktivsystem würden Sie die manuelle, für welche die automatische Variante empfehlen – und warum?

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- Caddy abgelöst und durch nginx mit dem nativen ACME-Modul ersetzt
- ACME als offenes Protokoll verstanden und einen Zertifikatsanbieter explizit und nachvollziehbar konfiguriert
- Fünf virtuelle Hosts manuell als nginx-Server-Blöcke eingerichtet, inklusive Basic Authentication für einen geschützten Dienst
- Ein eigenes Docker-Netzwerk angelegt und einen Dienst bewusst ohne Host-Port-Exposition gebündelt
- Die Namensauflösung innerhalb und außerhalb eines Docker-Netzwerks praktisch nachvollzogen
- Eine manuell gepflegte Lastverteilung über mehrere Container-Instanzen eingerichtet und live erweitert
- Die technischen Maßnahmen den ISO-27001-Controls A.8.20, A.8.22 und A.8.24 zugeordnet

### Zentrale Befehle dieser Übung

| Befehl | Bedeutung |
|---|---|
| `load_module modules/ngx_http_acme_module.so;` | ACME-Modul beim Start von nginx laden |
| `acme_issuer name { uri ...; }` | Zertifizierungsstelle explizit definieren |
| `acme_certificate issuer;` | Zertifikat für den aktuellen Server-Block anfordern |
| `nginx -t` | Konfiguration auf Syntaxfehler prüfen |
| `systemctl reload nginx` | Konfiguration ohne Prozessneustart übernehmen |
| `docker network create <name>` | Eigenes Docker-Netzwerk anlegen |
| `docker network connect <netz> <container>` | Laufenden Container zusätzlich an ein Netzwerk anhängen |
| `docker run --network <netz>` | Container von Anfang an einem bestimmten Netzwerk zuweisen |
| `getent hosts <name>` | Namensauflösung innerhalb eines Containers prüfen |

---

## Aufräumarbeiten

```bash
# Lastverteilungs-Demo entfernen
docker stop demo1 demo2 demo3 demo4
docker rm demo1 demo2 demo3 demo4
rm /etc/nginx/conf.d/demo.conf

# Bündelungs-Demo entfernen
docker stop redis-cache
docker rm redis-cache
docker network disconnect app-net nodered
docker network rm app-net

nginx -t
systemctl reload nginx
```

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter, Florian Reichl
- Datum: 07/2026
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab_05.md"><img src="images/previous.png" width="150px"></a>
<a href="Lab_07.md"><img src="images/next.png" width="150px"></a>
</p>
