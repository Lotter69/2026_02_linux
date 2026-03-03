# Laborübung 08: Dienste als Container bereitstellen

![line](images/banner.png)

## Berufliche Aufgabenstellung

Sie sind als IT-Fachkraft in einem kleinen Betrieb tätig. Die Geschäftsleitung möchte zwei interne Dienste bereitstellen:

- Eine **interne Webseite** (statische HTML-Seiten, z. B. Abteilungsinfos oder ein Intranet-Startportal)
- Eine **Node-RED-Instanz** zur Automatisierung und Visualisierung von Betriebsdaten (z. B. Maschinenstatus, einfache Dashboards)

Beide Dienste sollen auf demselben Linux-Server laufen und über einen zentralen **Reverse Proxy (Caddy)** erreichbar sein – der Proxy nimmt alle eingehenden Anfragen entgegen und leitet sie je nach Pfad an den richtigen Container weiter.

Ihre Aufgabe: Die Dienste als Docker-Container bereitstellen, benennen, mit dem Proxy verbinden und die Erreichbarkeit überprüfen.

---

## Einführung

In dieser Laborübung erleben Sie, wie **containerisierte Dienste** in der Praxis bereitgestellt werden. Statt Dienste direkt auf dem Host zu installieren, laufen sie isoliert in Containern – reproduzierbar, leicht aktualisierbar und unabhängig voneinander.

Als Bindeglied nach außen dient **Caddy**: ein moderner Reverse Proxy, der eingehende HTTP-Anfragen anhand des Pfads an den richtigen Container weiterleitet.

```
Browser
   │
   ▼
Caddy (Port 80)
   ├── /          →  nginx-web  (Port 8080)
   └── /nodered/  →  nodered    (Port 1880)
```

> **Hinweis:** Alle Container laufen im Standard-Bridge-Netzwerk `172.17.0.0/16`. Das Routing zwischen Host und Containern erfolgt über interne IP-Adressen – kein benutzerdefiniertes Netzwerk wird in dieser Übung verwendet. Die sich daraus ergebenden Einschränkungen und Alternativen sind Teil der Reflexion.

---

## Lernziele

- Dienste als benannte Docker-Container bereitstellen und verwalten
- Eigene Inhalte über ein **Bind Mount** in einen Container einbinden
- Einen **Caddy Reverse Proxy** als Container konfigurieren und betreiben
- Container-IP-Adressen ermitteln und deren Herkunft verstehen
- Speicherbedarf von Containern analysieren
- Konfigurationsänderungen im Container nachverfolgen und deren Speicherort verstehen

---

## Voraussetzungen

- Docker ist installiert und läuft (siehe Lab 05)
- Grundkenntnisse aus Lab 05 (Container starten, benennen, Portweiterleitung)
- Texteditor auf dem Host (z. B. `nano`)

---

## Aufgaben

### Schritt 1: Arbeitsverzeichnis anlegen

Legen Sie eine saubere Verzeichnisstruktur für diese Übung an:

```bash
mkdir -p ~/lab08/{webseite,caddy}
cd ~/lab08
```

Überblick über die Struktur, die am Ende entstehen wird:

```
~/lab08/
├── webseite/
│   └── index.html       ← Inhalte für den Webserver
└── caddy/
    └── Caddyfile        ← Konfiguration des Reverse Proxy
```

---

### Schritt 2: Webseite vorbereiten

Erstellen Sie eine einfache HTML-Seite, die der Webserver ausliefern soll:

```bash
nano ~/lab08/webseite/index.html
```

Inhalt:

```html
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="UTF-8">
  <title>Internes Portal</title>
</head>
<body>
  <h1>Willkommen im internen Portal</h1>
  <p>Dieser Dienst läuft als Docker-Container.</p>
</body>
</html>
```

Speichern mit `Strg+O`, beenden mit `Strg+X`.

---

### Schritt 3: Nginx-Webserver-Container starten

Starten Sie einen **nginx**-Container, der die HTML-Datei vom Host einbindet:

```bash
sudo docker run -d \
  --name nginx-web \
  -p 8080:80 \
  -v ~/lab08/webseite:/usr/share/nginx/html:ro \
  nginx
```

| Option | Bedeutung |
|---|---|
| `--name nginx-web` | Container erhält einen sprechenden Namen |
| `-p 8080:80` | Port 8080 des Hosts leitet auf Port 80 des Containers |
| `-v ~/lab08/webseite:/usr/share/nginx/html:ro` | Lokales Verzeichnis wird eingebunden, `:ro` = read-only |

#### Webserver direkt testen

```bash
curl http://localhost:8080
```

Sie sollten den HTML-Inhalt sehen. Alternativ im Browser: `http://localhost:8080`

---

### Schritt 4: Node-RED-Container starten

Node-RED benötigt ein Volume, damit erstellte Flows und Einstellungen erhalten bleiben:

```bash
sudo docker run -d \
  --name nodered \
  -p 1880:1880 \
  -v nodered-data:/data \
  nodered/node-red
```

| Option | Bedeutung |
|---|---|
| `--name nodered` | Containername |
| `-p 1880:1880` | Standardport von Node-RED |
| `-v nodered-data:/data` | Benanntes Volume für Flows und Einstellungen |

#### Node-RED direkt testen

Öffnen Sie im Browser:

```
http://localhost:1880
```

Sie sehen den Node-RED Editor. Erstellen Sie einen einfachen Test-Flow:

1. Ziehen Sie einen **Inject**-Node auf die Arbeitsfläche
2. Verbinden Sie ihn mit einem **Debug**-Node
3. Klicken Sie auf **Deploy**
4. Klicken Sie auf den Inject-Button – im Debug-Panel erscheint eine Ausgabe

> Dieser Flow bleibt dank des Volumes `nodered-data` auch nach einem Container-Neustart erhalten.

---

### Schritt 5: Container-IPs ermitteln

Bevor Caddy konfiguriert werden kann, benötigen Sie die internen IP-Adressen der Container im Standard-Bridge-Netzwerk:

```bash
sudo docker inspect -f '{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' nginx-web nodered
```

Notieren Sie die Adressen:

| Container | IP-Adresse |
|---|---|
| nginx-web | `172.17.0.___` |
| nodered | `172.17.0.___` |

> **Warum brauchen wir die IP?** Im Standard-Bridge-Netzwerk gibt es keine Namensauflösung zwischen Containern. Caddy muss die Ziel-Container daher über ihre IP-Adresse ansprechen. Was das bedeutet und welche Alternative es gibt, ist Teil der Reflexion am Ende dieser Übung.

---

### Schritt 6: Caddy konfigurieren

Erstellen Sie das Caddyfile mit den ermittelten IP-Adressen:

```bash
nano ~/lab08/caddy/Caddyfile
```

Inhalt (ersetzen Sie die IP-Adressen durch Ihre notierten Werte):

```
:80 {
    # Anfragen an /nodered/ werden an den Node-RED Container weitergeleitet
    handle /nodered/* {
        reverse_proxy 172.17.0.X:1880
    }

    # Alle anderen Anfragen gehen an den Nginx-Webserver
    handle {
        reverse_proxy 172.17.0.Y:80
    }
}
```

> **Hinweis:** Ersetzen Sie `172.17.0.X` und `172.17.0.Y` durch die tatsächlichen IP-Adressen aus Schritt 5.

---

### Schritt 7: Caddy-Container starten

```bash
sudo docker run -d \
  --name caddy \
  -p 80:80 \
  -v ~/lab08/caddy/Caddyfile:/etc/caddy/Caddyfile:ro \
  caddy
```

#### Routing testen

```bash
# Webserver über Caddy
curl http://localhost/

# Node-RED über Caddy
curl http://localhost/nodered/
```

Oder im Browser:

```
http://localhost/           → Interne Webseite
http://localhost/nodered/   → Node-RED Editor
```

#### Caddy-Logs prüfen

```bash
sudo docker logs caddy
```

> **Tipp zur Fehlerbehebung:** Wenn Caddy einen Verbindungsfehler meldet, prüfen Sie die IP-Adressen in Ihrem Caddyfile mit `docker inspect` erneut. Container können beim Neustart andere IPs erhalten.

---

### Schritt 8: Betrieb überprüfen und dokumentieren

#### 8.1 Alle laufenden Container anzeigen

```bash
sudo docker ps
```

Sie sollten drei laufende Container sehen: `caddy`, `nginx-web`, `nodered`.

#### 8.2 Speicherbedarf der Container ermitteln

```bash
# Speicherbedarf aller Container (inkl. beschreibbarer Schicht)
sudo docker ps -a -s
```

Die Spalte `SIZE` zeigt zwei Werte:

```
123kB (virtual 45MB)
```

| Wert | Bedeutung |
|---|---|
| `123kB` | Größe der **beschreibbaren Container-Schicht** (was sich seit Image-Start verändert hat) |
| `virtual 45MB` | Gesamtgröße inkl. Image (wird von allen Containern desselben Images geteilt) |

```bash
# Gesamtübersicht Speicher
sudo docker system df
```

#### 8.3 IP-Adressen aller Container tabellarisch ausgeben

```bash
sudo docker inspect \
  --format '{{.Name}}: {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' \
  caddy nginx-web nodered
```

---

### Schritt 9: Konfigurationsänderung nachverfolgen

In diesem Schritt erleben Sie, **wo und wie** Änderungen innerhalb eines Containers gespeichert werden – und was das für den Betrieb bedeutet.

#### 9.1 Nginx-Konfiguration im laufenden Container ändern

Öffnen Sie eine Shell im nginx-Container und schauen Sie sich die Standard-Konfiguration an:

```bash
sudo docker exec -it nginx-web bash

# Konfigurationsdatei anzeigen
cat /etc/nginx/nginx.conf

# Eine kleine Änderung vornehmen: eigenen Header hinzufügen
# (nur zur Demonstration – nicht produktiv empfohlen)
echo "# geaendert am $(date)" >> /etc/nginx/nginx.conf

# Änderung prüfen
tail -3 /etc/nginx/nginx.conf

exit
```

#### 9.2 Änderung im Container-Dateisystem sichtbar machen

Docker speichert alle Änderungen gegenüber dem Original-Image in einer **beschreibbaren Schicht** (Container Layer). Diese Änderungen können angezeigt werden:

```bash
sudo docker diff nginx-web
```

Die Ausgabe zeigt alle veränderten Dateien mit Kennzeichnung:

| Buchstabe | Bedeutung |
|---|---|
| `A` | Added – neu hinzugefügt |
| `C` | Changed – verändert |
| `D` | Deleted – gelöscht |

🔍 **Beobachten Sie:** Die geänderte Konfigurationsdatei erscheint mit `C` – sie existiert als Kopie in der Container-Schicht, das Original-Image bleibt unverändert.

#### 9.3 Was passiert beim Löschen des Containers?

```bash
# Container stoppen und löschen
sudo docker stop nginx-web
sudo docker rm nginx-web

# Container neu aus dem Image starten
sudo docker run -d \
  --name nginx-web \
  -p 8080:80 \
  -v ~/lab08/webseite:/usr/share/nginx/html:ro \
  nginx

# Änderung prüfen – sie ist weg
sudo docker exec nginx-web tail -3 /etc/nginx/nginx.conf
```

🔍 **Erkenntnis:** Änderungen direkt im Container sind **flüchtig** – sie verschwinden, wenn der Container gelöscht wird. Nur Daten in Volumes oder Bind Mounts überleben das Löschen eines Containers.

---

## Reflexion und weiterführende Fragen

Die folgenden Fragen greifen die Beobachtungen aus der Übung auf und öffnen den Blick auf vertiefende Themen:

---

**Zu den IP-Adressen:**

- Aus welchem Netz stammen die IP-Adressen der Container – und warum?
- Was passiert mit den IP-Adressen, wenn die Container neu gestartet werden?
- Warum ist es problematisch, IP-Adressen fest in das Caddyfile einzutragen?
- Wie könnte das Problem der wechselnden IPs gelöst werden?

> 💡 *Hinweis: Die Antwort führt zum Thema **benutzerdefinierte Docker-Netzwerke**, in denen Container über ihre Namen angesprochen werden können – Thema der nächsten Laborübung.*

---

**Zum Speicher:**

- Was ist der Unterschied zwischen der kleinen und der großen Zahl in der `SIZE`-Spalte von `docker ps -s`?
- Wo auf dem Host liegt die beschreibbare Container-Schicht?
- Warum ist es sinnvoll, Konfigurationsdateien nicht im Container zu ändern, sondern über Bind Mounts einzubinden?
- Was spricht dafür, Node-RED-Daten in einem Volume zu speichern?

> 💡 *Hinweis: Die Antworten führen zu den Themen **Docker Volumes**, **Bind Mounts** und dem **Union Filesystem** – dem Schichtsystem, auf dem Container-Images aufgebaut sind.*

---

**Zum Reverse Proxy:**

- Warum ist es sinnvoll, einen Reverse Proxy vor die Container zu schalten, statt alle Ports direkt freizugeben?
- Was müsste geändert werden, wenn ein dritter Dienst hinzukommt?
- Caddy unterstützt auch automatisches HTTPS – wann wäre das relevant?

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- Zwei Dienste (**nginx**, **Node-RED**) als benannte Docker-Container bereitgestellt
- Eigene HTML-Inhalte über einen **Bind Mount** in den Webserver-Container eingebunden
- **Caddy** als Reverse Proxy konfiguriert und das Routing über Pfade eingerichtet
- Container-**IP-Adressen** ermittelt und deren Herkunft im Standard-Bridge-Netzwerk verstanden
- Den **Speicherbedarf** von Containern analysiert und die beschreibbare Container-Schicht erkundet
- Erlebt, dass direkte Änderungen im Container **flüchtig** sind

### Zentrale Befehle dieser Übung

| Befehl | Bedeutung |
|---|---|
| `docker run --name <n>` | Container mit Name starten |
| `docker run -v <host>:<container>:ro` | Bind Mount (read-only) einbinden |
| `docker inspect -f '{{...}}' <c>` | Gezielt Informationen auslesen |
| `docker ps -s` | Container mit Speicherbedarf anzeigen |
| `docker system df` | Gesamtübersicht Speicher |
| `docker diff <c>` | Änderungen im Container-Dateisystem anzeigen |
| `docker exec -it <c> bash` | Shell im laufenden Container öffnen |
| `docker logs <c>` | Container-Logs anzeigen |

---

## Aufräumarbeiten

```bash
# Container stoppen und löschen
sudo docker stop caddy nginx-web nodered
sudo docker rm caddy nginx-web nodered

# Volume löschen
sudo docker volume rm nodered-data

# Arbeitsverzeichnis löschen (optional)
rm -rf ~/lab08
```

## Autoren und Urheberrecht
- Erstellt für den Einsatz im Unterricht
- Date: 09/2025
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab07_Docker_Netzwerk.md"><img src="images/previous.png" width="150px"></a>
<a href="Lab09.md"><img src="images/next.png" width="150px"></a>
</p>
