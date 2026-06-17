# Lab 05: Webdienste als Docker-Container bereitstellen

![line](images/banner.png)

## Berufliche Aufgabenstellung

Der Server läuft, Caddy ist eingerichtet, und die ersten Dienste sind per HTTPS erreichbar. Die nächste Anforderung aus dem Betrieb: Zwei weitere Dienste sollen bereitgestellt werden – eine öffentliche **Unternehmenswebseite** und ein internes **Automatisierungs-Dashboard** auf Basis von Node-RED. Anstatt diese Dienste direkt auf dem Host zu installieren, sollen sie als **Docker-Container** betrieben werden.

Docker ist auf dem Server noch nicht installiert. Das Deployment erfolgt auf dem bestehenden Cloud-Server (z. B. Hetzner) – die Dienste werden hinter dem bereits konfigurierten Caddy als neue Subdomains eingehängt:

- `www.ihre-domain.de` → Unternehmenswebseite (nginx)
- `dashboard.ihre-domain.de` → Node-RED Automatisierungs-Dashboard

Beide Dienste sind über HTTPS erreichbar – Caddy übernimmt dabei, wie bereits in Lab 04 eingerichtet, automatisch die Zertifikatsverwaltung.

---

## Einführung

Docker erlaubt es, Dienste in **Containern** zu verpacken: isolierte, portable Laufzeitumgebungen, die einen Dienst zusammen mit all seinen Abhängigkeiten enthalten. Statt einen Webserver oder eine Anwendung direkt auf dem Host zu installieren, wird ein fertiges **Image** aus einer Registry geladen und als Container gestartet.

Im Vergleich zur direkten Installation auf dem Host stellt sich dabei eine wichtige Frage zur **Datenpersistenz**: Ein Container ist von Natur aus kurzlebig – wird er gelöscht oder aktualisiert, gehen alle Änderungen am Container-Dateisystem verloren. Docker löst dieses Problem mit **Volumes** und **Bind Mounts**, die Daten außerhalb des Containers speichern und so auch über Container-Neustarts oder Updates hinaus verfügbar halten.

> **Hinweis**: Eine Registry ist im Docker-Kontext ein zentraler Speicherort, von dem fertige Container-Images heruntergeladen (und bei eigenen Images auch hochgeladen) werden können. 
---

## Lernziele

- Docker auf einem Ubuntu-Server installieren und konfigurieren
- Den Unterschied zwischen **Bind Mount** und **benanntem Volume** verstehen und praktisch anwenden
- Die Syntax von **`-p`** (Port-Mapping) und **`-v`** (Volume/Bind Mount) sicher anwenden
- Eigene Webinhalte über einen Bind Mount in einen Nginx-Container einbinden
- Node-RED-Daten dauerhaft in einem benannten Volume speichern
- Den bereits installierten Caddy um neue HTTPS-Subdomains erweitern

---

## Voraussetzungen

| Anforderung | Details |
|---|---|
| **Server** | Ubuntu 24.04 LTS, öffentliche IPv4-Adresse (aus Lab 03) |
| **Caddy** | Installiert und als systemd-Dienst aktiv (aus Lab 04) |
| **SSH-Zugriff** | Key-Authentifizierung |
| **DNS** | Verwaltungszugriff für Ihre Domain |

---

## Aufgaben

### Schritt 1: Docker installieren

Docker ist auf dem Server noch nicht vorhanden. In diesem Schritt binden Sie das offizielle Docker-Repository als Paketquelle ein und installieren Docker.

#### 1.1 Paketquellen vorbereiten

Falls ältere oder inoffizielle Docker-Pakete vorhanden sind, entfernen Sie diese zuerst:

```bash
apt remove -y docker.io docker-doc docker-compose docker-compose-v2 podman-docker containerd runc 2>/dev/null; true
```

Installieren Sie die benötigten Hilfswerkzeuge:

```bash
apt install -y ca-certificates curl
```

#### 1.2 Docker-Repository einbinden

Laden Sie den GPG-Schlüssel des Docker-Projekts herunter. APT verwendet ihn, um die digitale Signatur jedes heruntergeladenen Docker-Pakets zu prüfen:

````bash
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc
````

Tragen Sie das Docker-Repository als Paketquelle ein:

```bash
echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" \
  | tee /etc/apt/sources.list.d/docker.list > /dev/null
```

#### 1.3 Docker installieren

```bash
apt update
apt install -y docker-ce docker-ce-cli containerd.io
```

Die drei Pakete erfüllen unterschiedliche Aufgaben:

| Paket | Aufgabe |
|---|---|
| `docker-ce` | Docker Engine (Community Edition) – der Daemon, der Container und Images verwaltet |
| `docker-ce-cli` | Kommandozeilen-Schnittstelle (`docker`-Befehl) |
| `containerd.io` | Container-Laufzeitumgebung, auf der Docker aufbaut |

#### 1.4 Installation prüfen

```bash
docker version
docker run --rm hello-world
```

`docker run --rm hello-world` lädt ein kleines Test-Image herunter, startet es, zeigt eine Erfolgsmeldung und löscht den Container danach automatisch (`--rm`). Wenn Sie die Meldung „Hello from Docker!" sehen, ist die Installation erfolgreich.

#### 1.5 Docker-Netzwerk und ufw

Docker erstellt für Container ein internes Brückennetzwerk (`docker0`). Damit IP-Pakete von diesem Netzwerk an die Container weitergeleitet werden können, muss ufw das Forwarding erlauben. Prüfen Sie die aktuelle Einstellung:

```bash
grep DEFAULT_FORWARD_POLICY /etc/default/ufw
```

Falls der Wert `"DROP"` ist, ändern Sie ihn auf `"ACCEPT"`:

```bash
sed -i 's/DEFAULT_FORWARD_POLICY="DROP"/DEFAULT_FORWARD_POLICY="ACCEPT"/' /etc/default/ufw
ufw reload
```

> **Warum ist das nötig?**
> Wenn ufw `DEFAULT_FORWARD_POLICY=DROP` setzt, werden IP-Pakete, die über die Docker-Netzwerkbrücke weitergeleitet werden sollen, stillschweigend verworfen. Container können dann nicht mehr nach außen kommunizieren – z. B. keine DNS-Abfragen stellen oder Images herunterladen.

---

### Schritt 2: DNS-Einträge für die neuen Subdomains anlegen

Die neuen Dienste sollen unter eigenen Subdomains erreichbar sein. Legen Sie beim DNS-Anbieter zwei neue A-Records an, die auf die IPv4-Adresse Ihres Servers zeigen:

| Typ | Name | Wert | TTL |
|---|---|---|---|
| `A` | `www` | `<IPv4 Ihres Servers>` | `300` |
| `A` | `dashboard` | `<IPv4 Ihres Servers>` | `300` |

**Hinweis: Wildcard-Eintrag prüfen, bevor Sie neue A-Records anlegen**
> Falls in Ihrer DNS-Zone bereits ein Wildcard-Eintrag (Name `*`, Typ `A`) existiert, lösen automatisch *alle* Subdomains auf dieselbe IP auf – auch ohne dass Sie für die hier benötigten Namen eigene Einträge anlegen. Prüfen Sie das vorab mit einer frei erfundenen Subdomain:
>
> ```powershell
> Resolve-DnsName -Name irgendwas-zufaelliges123.ihre-domain.de -Server 8.8.8.8
> ```
> Kommt hier eine IP-Adresse zurück, ist Ihre Zone bereits per Wildcard abgedeckt – Sie können diesen Schritt überspringen und direkt mit dem nächsten Schritt fortfahren. Kommt `NXDOMAIN` zurück, legen Sie die A-Records wie unten beschrieben einzeln an.

Prüfen Sie die Auflösung, bevor Sie mit Schritt 5 fortfahren:

```bash
dig www.ihre-domain.de +short
dig dashboard.ihre-domain.de +short
```

Beide Befehle sollten die IPv4-Adresse Ihres Servers ausgeben.

---

### Schritt 3: Unternehmenswebseite mit nginx-Container bereitstellen

#### 3.1 Webinhalte vorbereiten

Legen Sie ein Verzeichnis auf dem Host für die Webseiten-Dateien an:

```bash
mkdir -p /srv/www
nano /srv/www/index.html
```

Fügen Sie folgenden Inhalt ein und passen Sie ihn frei an:

```html
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <title>Mein Unternehmen</title>
</head>
<body>
  <h1>Willkommen</h1>
  <p>Diese Seite läuft als Docker-Container hinter Caddy.</p>
</body>
</html>
```

Speichern mit `Strg+O`, `Enter`, beenden mit `Strg+X`.

#### 3.2 Was ist ein Bind Mount?

Wenn Sie einen Container starten, enthält er zunächst nur das Dateisystem des Images. Um eigene Dateien – in diesem Fall Ihre HTML-Seite – in den Container einzubinden, verwenden Sie einen **Bind Mount**: Das Verzeichnis `/srv/www` auf dem Host wird direkt in das Verzeichnis `/usr/share/nginx/html` im Container eingehängt. Der Container liest die Dateien unmittelbar vom Host-Dateisystem.

```
Host:                    Container:
/srv/www/           ←→   /usr/share/nginx/html/
  index.html                index.html
```

Im Unterschied zu einem **benannten Volume** (siehe Schritt 4) bestimmen Sie beim Bind Mount selbst, wo die Daten auf dem Host liegen. Docker verwaltet diesen Pfad nicht.

#### 3.3 Nginx-Container starten

```bash
docker run -d \
  --name nginx-web \
  --restart unless-stopped \
  -p 8080:80 \
  -v /srv/www:/usr/share/nginx/html:ro \
  nginx
```

**Erklärung der Optionen:**

| Option | Bedeutung |
|---|---|
| `-d` | Container läuft im Hintergrund (detached) |
| `--name nginx-web` | Eindeutiger Name für den Container |
| `--restart unless-stopped` | Container startet automatisch neu (siehe Hinweis unten) |
| `-p 8080:80` | Port-Mapping: Port 8080 des Hosts leitet auf Port 80 im Container |
| `-v /srv/www:/usr/share/nginx/html:ro` | Bind Mount: Host-Verzeichnis → Container-Verzeichnis, `:ro` = read-only |

> **Automatischer Neustart mit `--restart`**
> Ohne diese Option startet ein Container nach einem Serverneustart **nicht** automatisch wieder. Docker kennt vier Restart-Richtlinien:
>
> | Wert | Verhalten |
> |---|---|
> | `no` | Kein automatischer Neustart (Standardwert) |
> | `always` | Immer neu starten – auch nach manuellem `docker stop` |
> | `unless-stopped` | Neu starten, außer wenn der Container manuell gestoppt wurde |
> | `on-failure` | Nur neu starten, wenn der Container mit einem Fehler beendet wurde |
>
> Für Produktivdienste ist `unless-stopped` die empfohlene Wahl: Der Container startet nach einem Serverneustart automatisch, lässt sich aber für Wartungsarbeiten mit `docker stop` ohne unerwünschte Neustarts anhalten.

> **Syntax `-p <host-port>:<container-port>`**
> Der erste Wert ist der Port, über den der Dienst auf dem **Host** erreichbar ist. Der zweite Wert ist der Port, auf dem der Dienst **im Container** lauscht. Mit `-p 8080:80` ist nginx im Container auf Port 80 aktiv – von außen ist er über Port 8080 auf dem Host erreichbar. Caddy, das auf dem Host läuft, kann den Container damit einfach über `localhost:8080` ansprechen.

> **Syntax `-v <quelle>:<ziel>[:ro]`**
> Beim Bind Mount ist `<quelle>` ein Pfad auf dem **Host**, `<ziel>` ein Pfad **im Container**. Das optionale `:ro` macht den Mount read-only – der Container kann die Dateien lesen, aber nicht verändern. Dies schützt die Webinhalte, die ausschließlich vom Host aus gepflegt werden.

#### 3.4 Webserver testen

```bash
curl http://localhost:8080
```

Sie sollten den HTML-Inhalt Ihrer Seite sehen.

#### 3.5 Was passiert beim Container-Update?

Wenn nginx aktualisiert wird – Sie also den alten Container löschen und einen neuen aus einem neueren Image starten –, bleiben die Webinhalte in `/srv/www` vollständig erhalten. Sie liegen auf dem Host und werden durch den Bind Mount lediglich eingehängt. Der Container-Neustart hat keinen Einfluss auf das Host-Verzeichnis:

```bash
docker stop nginx-web && docker rm nginx-web
docker pull nginx
docker run -d \
  --name nginx-web \
  --restart unless-stopped \
  -p 8080:80 \
  -v /srv/www:/usr/share/nginx/html:ro \
  nginx
```

---

### Schritt 4: Node-RED-Container starten

#### 4.1 Was ist ein benanntes Volume?

Node-RED speichert erstellte Flows, Einstellungen und installierte Erweiterungen im Verzeichnis `/data` des Containers. Diese Daten müssen auch dann erhalten bleiben, wenn der Container aktualisiert oder neu erstellt wird.

Dafür wird ein **benanntes Volume** verwendet: Sie vergeben einen Namen (`nodered-data`), und Docker legt das zugehörige Verzeichnis automatisch auf dem Host an – standardmäßig unter `/var/lib/docker/volumes/nodered-data/`. Den genauen Speicherort verwaltet Docker; Sie müssen ihn nicht selbst anlegen.

```
Docker-Volume:           Container:
nodered-data/       ←→   /data/
  flows.json               flows.json
  settings.js              settings.js
```

> **Bind Mount vs. benanntes Volume**
>
> | | Bind Mount | Benanntes Volume |
> |---|---|---|
> | Speicherort | Frei gewählter Pfad auf dem Host | Von Docker verwaltet (`/var/lib/docker/volumes/`) |
> | Anlegen | Pfad muss angegeben werden | Docker legt das Volume beim ersten Start automatisch an |
> | Portabilität | Pfad ist host-spezifisch | Volume kann mit `docker volume`-Befehlen verwaltet werden |
> | Typischer Einsatz | Konfigurationsdateien und Inhalte, die vom Host gepflegt werden | Anwendungsdaten (Flows, Datenbanken) |

#### 4.2 Node-RED starten

```bash
docker run -d \
  --name nodered \
  --restart unless-stopped \
  -p 1880:1880 \
  -v nodered-data:/data \
  nodered/node-red
```

| Option | Bedeutung |
|---|---|
| `--restart unless-stopped` | Automatischer Neustart nach Serverneustart (siehe Schritt 3.3) |
| `-p 1880:1880` | Port 1880 des Hosts leitet auf Port 1880 im Container |
| `-v nodered-data:/data` | Benanntes Volume `nodered-data` wird in `/data` im Container eingehängt |

Das Volume `nodered-data` existiert zu diesem Zeitpunkt noch nicht – Docker legt es beim ersten Start automatisch an. Prüfen Sie anschließend:

```bash
docker volume ls
docker volume inspect nodered-data
```

`docker volume inspect` zeigt unter `Mountpoint` den tatsächlichen Pfad auf dem Host, an dem Docker die Daten speichert.

#### 4.3 Node-RED direkt testen

```bash
curl http://localhost:1880
```

Sie sollten eine HTML-Antwort erhalten. Der Port 1880 ist von außen nicht direkt zugänglich – ufw lässt ihn nicht durch – und das ist gewollt: Der Zugriff aus dem Internet soll ausschließlich über Caddy erfolgen.

> **Warum braucht Node-RED kein eigenes HTTPS?**
> Node-RED kommuniziert intern zwischen Container und Caddy ausschließlich über `localhost:1880` – eine lokale Verbindung auf dem Server, die nicht das Internet berührt. Die HTTPS-Verschlüsselung gegenüber dem Browser des Benutzers übernimmt vollständig Caddy: Er empfängt die verschlüsselte Anfrage auf Port 443, entschlüsselt sie und leitet sie unverschlüsselt an `localhost:1880` weiter. Node-RED selbst muss sich nicht um Zertifikate kümmern.

#### 4.4 Was passiert beim Container-Update?

Das benannte Volume bleibt beim Update des Containers vollständig erhalten:

```bash
docker stop nodered && docker rm nodered
docker pull nodered/node-red
docker run -d \
  --name nodered \
  --restart unless-stopped \
  -p 1880:1880 \
  -v nodered-data:/data \
  nodered/node-red
```

`nodered-data` besteht unabhängig vom Container. Es bleibt so lange bestehen, bis es mit `docker volume rm nodered-data` explizit gelöscht wird. Alle Flows und Einstellungen sind nach dem Update unverändert vorhanden.

---

> **Exkurs: Benutzerverwaltung in Node-RED**
>
> Standardmäßig ist der Node-RED Editor ohne Authentifizierung zugänglich. Wer den Zugriff auf autorisierte Benutzer beschränken möchte, kann in der Konfigurationsdatei `settings.js` eine Benutzerverwaltung aktivieren.
>
> Die Datei liegt im Volume und ist direkt auf dem Host bearbeitbar:
>
> ```bash
> nano /var/lib/docker/volumes/nodered-data/_data/settings.js
> ```
>
> Suchen Sie den auskommentierten Abschnitt `adminAuth` und aktivieren Sie ihn:
>
> ```javascript
> adminAuth: {
>     type: "credentials",
>     users: [{
>         username: "admin",
>         password: "$2b$08$...",  // bcrypt-Hash des Passworts
>         permissions: "*"
>     }]
> },
> ```
>
> Den bcrypt-Hash für Ihr Passwort erzeugen Sie direkt im Container:
>
> ```bash
> docker exec -it nodered node-red admin hash-pw
> ```
>
> Starten Sie den Container nach der Änderung neu:
>
> ```bash
> docker restart nodered
> ```
>
> Der Node-RED Editor verlangt beim nächsten Aufruf Benutzername und Passwort.

---

### Schritt 5: Caddy für die neuen Subdomains konfigurieren

Die Container laufen und sind intern über `localhost:8080` bzw. `localhost:1880` erreichbar. Erweitern Sie nun das Caddyfile um die beiden neuen Subdomains.

Öffnen Sie die Konfigurationsdatei:

```bash
nano /etc/caddy/Caddyfile
```

Fügen Sie am Ende der Datei die folgenden Blöcke hinzu:

```caddy
# Unternehmenswebseite
www.ihre-domain.de {
    reverse_proxy localhost:8080
}

# Node-RED Dashboard
dashboard.ihre-domain.de {
    reverse_proxy localhost:1880
}
```

> **Warum funktioniert `localhost:8080` – und sind keine Container-IP-Adressen nötig?**
> Mit `-p 8080:80` bindet Docker den Container-Port 80 an den Host-Port 8080. Caddy läuft auf demselben Host und erreicht den Container daher einfach über `localhost:8080` – genau wie jeder andere lokale Prozess. Container-IP-Adressen werden nur benötigt, wenn Container direkt miteinander kommunizieren sollen, ohne Port-Mapping über den Host.

Validieren und laden Sie die Konfiguration:

```bash
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

Caddy fordert nun automatisch TLS-Zertifikate für `www.ihre-domain.de` und `dashboard.ihre-domain.de` bei Let's Encrypt an.

> **Tipp zur Fehlerbehebung:** Die DNS-Einträge aus Schritt 2 müssen propagiert sein, bevor Caddy Zertifikate ausstellen kann. Beobachten Sie die Logs mit `journalctl -u caddy -f`.

---

### Schritt 6: Ergebnis im Browser überprüfen

#### 6.1 Laufende Container prüfen

```bash
docker ps
```

Sie sollten zwei laufende Container sehen: `nginx-web` und `nodered`.

#### 6.2 Dienste im Browser aufrufen

```
https://www.ihre-domain.de          →  Ihre Unternehmenswebseite
https://dashboard.ihre-domain.de    →  Node-RED Editor
```

Beide Seiten müssen mit einem gültigen Let's Encrypt-Zertifikat geladen werden – ohne Sicherheitswarnung im Browser.

---

## Reflexion und weiterführende Fragen

**Zu Volumes und Bind Mounts:**

- Warum wird für die Webseite ein Bind Mount verwendet, für Node-RED-Daten aber ein benanntes Volume? Welche Anforderungen bestimmen diese Wahl?
- Was passiert, wenn Sie `docker rm nodered` ausführen? Was passiert zusätzlich, wenn Sie `docker volume rm nodered-data` ausführen?
- Wie können Sie die Daten eines benannten Volumes sichern?

**Zu den Containern und Caddy:**

- Was müsste sich ändern, wenn Sie Caddy ebenfalls als Container betreiben wollten – warum wäre `localhost:8080` dann nicht mehr ausreichend?
- Was spricht dafür, Caddy auf dem Host zu installieren statt als Container – insbesondere im Hinblick auf systemd-Integration und TLS?

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- **Docker** aus dem offiziellen Repository installiert und die Paketstruktur verstanden
- Den Unterschied zwischen **Bind Mount** und **benanntem Volume** verstanden und praktisch angewendet
- Die Syntax von **`-p`** (Port-Mapping) und **`-v`** (Volume/Bind Mount) sicher angewendet
- Nginx mit eigenem HTML-Inhalt über einen **Bind Mount** bereitgestellt
- Node-RED-Daten dauerhaft in einem **benannten Volume** gespeichert
- Den bereits installierten **Caddy** um zwei neue HTTPS-Subdomains erweitert
- Verstanden, warum **`localhost`** ausreicht und Container-IP-Adressen hier nicht benötigt werden

### Zentrale Befehle dieser Übung

| Befehl | Bedeutung |
|---|---|
| `docker run -d --name <n>` | Container im Hintergrund starten und benennen |
| `docker run --restart unless-stopped` | Container nach Serverneustart automatisch starten |
| `docker run -p <host>:<container>` | Port des Hosts an Container weiterleiten |
| `docker run -v <pfad>:<ziel>:ro` | Bind Mount (read-only) einbinden |
| `docker run -v <name>:<ziel>` | Benanntes Volume einbinden (wird ggf. automatisch angelegt) |
| `docker ps` | Laufende Container anzeigen |
| `docker volume ls` | Vorhandene Volumes anzeigen |
| `docker volume inspect <name>` | Speicherort und Details eines Volumes anzeigen |
| `docker stop <n> && docker rm <n>` | Container stoppen und löschen |
| `docker pull <image>` | Aktuelles Image herunterladen |
| `docker restart <n>` | Container neu starten |

---

## Aufräumarbeiten

```bash
# Container stoppen und löschen
docker stop nginx-web nodered
docker rm nginx-web nodered

# Volume löschen (Achtung: alle Node-RED-Daten gehen verloren)
docker volume rm nodered-data

# Webinhalte löschen
rm -rf /srv/www

# Caddy-Konfiguration: die hinzugefügten Blöcke für www und dashboard entfernen
nano /etc/caddy/Caddyfile
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter, Florian Reichl
- Datum: 02/2026
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab_04.md"><img src="images/previous.png" width="150px"></a>
<a href="Lab_06.md"><img src="images/next.png" width="150px"></a>
</p>
