# Lab 07: Erweiterung – Weitere eigene Images auf Basis von debian:trixie-slim

![line](images/banner.png)

## Berufliche Aufgabenstellung

Die Vorbereitung auf die Zertifizierung nach ISO/IEC 27001 wirft eine weitere Frage auf, die bisher unbeantwortet blieb: Die Sensordaten, die künftig über die IoT-Pipeline gesammelt werden, existieren ausschließlich in der laufenden InfluxDB-Instanz – es gibt keinerlei dokumentierte Sicherung dieser Daten. Control **A.8.13 (Information Backup)** verlangt jedoch eine definierte, nachvollziehbare Backup-Routine mit klarem Zeitplan.

Das Betriebsteam entscheidet, diese Anforderung mit genau dem Werkzeug zu lösen, das in Lab 07 bereits eingeführt wurde: einem eigenen, aus einem Betriebssystem-Image selbst zusammengestellten Docker-Image. Bevor die Lösung in den produktiven Compose-Stack aus Lab 08 übernommen wird, soll sie zunächst als eigenständiger Prototyp gegen die Wegwerf-Testumgebung aus Lab 07 entwickelt und erprobt werden – Sie übernehmen dabei die Rolle des Betriebsteams und entwerfen das Image eigenständig.

---

## Einführung

In Lab 07 haben Sie das Prinzip kennengelernt, ein eigenes Image nicht von einem fertigen Anwendungsimage, sondern von einem schlanken Betriebssystem-Image (`debian:trixie-slim`) aus aufzubauen und die benötigte Software selbst per `apt install` einzurichten – am Beispiel von nginx. Diese Erweiterung zeigt, dass sich dasselbe Muster auf praktisch jede Software übertragen lässt, die Debian als Paket bereitstellt. Als konkretes Beispiel bauen Sie diesmal ein Werkzeug, das *zeitgesteuert* arbeitet: einen Backup-Container, der in regelmäßigen Abständen die Testdaten aus InfluxDB sichert.

Im Unterschied zu den vorherigen Labs erhalten Sie diesmal **keine** vollständige Schritt-für-Schritt-Anleitung, sondern eine Anforderungsliste, wie sie auch in der Praxis als Auftrag formuliert würde. Der Weg zur Lösung – welche Dateien Sie anlegen, wie Sie das Dockerfile strukturieren – liegt bei Ihnen. Eine vollständige Musterlösung finden Sie am Ende dieses Labs verlinkt, falls Sie nicht weiterkommen oder Ihre eigene Lösung vergleichen möchten.

## Lernziele

- Das apt-install-Muster aus Lab 07 (Betriebssystem-Image + `apt install`) selbstständig auf ein neues, eigenes Problem übertragen
- Ein zeitgesteuertes Automatisierungswerkzeug (`cron`) innerhalb eines Containers einrichten und dessen Besonderheiten kennenlernen
- Ein Dockerfile eigenständig anhand einer Anforderungsliste entwerfen, statt einer Schritt-für-Schritt-Anleitung zu folgen
- Die eigene Lösung anhand klar definierter Abnahmekriterien selbst überprüfen
- Den Bezug zwischen einer technischen Lösung und einem ISO-27001-Control (A.8.13) herstellen

## Voraussetzungen

| Anforderung | Details |
|---|---|
| **Lab 07** | Vollständig durchgeführt – insbesondere das apt-install-Muster aus Schritt 2 und die Wegwerf-InfluxDB aus Schritt 4 |
| **Docker** | Installiert, inklusive Buildx-Plugin (aus Lab 05/07) |
| **Kenntnisse** | `FROM`/`RUN`/`COPY`/`ENV`/`CMD`, `docker build`/`run`/`network create` |

---

## Inhalt

- [Hintergrundwissen](#hintergrundwissen)
  - [Das Muster verallgemeinern](#das-muster-verallgemeinern)
  - [Automatisierung im Container: cron](#automatisierung-im-container-cron)
  - [ISO 27001: Control A.8.13 – Information Backup](#iso-27001-control-a813-information-backup)
- [Übungsaufgabe](#übungsaufgabe)
  - [Ausgangslage](#ausgangslage)
  - [Anforderungen (Definition of Done)](#anforderungen-definition-of-done)
  - [Vorgehensvorschlag](#vorgehensvorschlag)
  - [Tipps, falls Sie nicht weiterkommen](#tipps-falls-sie-nicht-weiterkommen)
  - [Ihre Lösung testen](#ihre-lösung-testen)
- [Reflexion und weiterführende Fragen](#reflexion-und-weiterführende-fragen)
- [Wie geht es weiter?](#wie-geht-es-weiter)
- [Aufräumarbeiten](#aufräumarbeiten)
- [Autoren und Urheberrecht](#autoren-und-urheberrecht)

---

## Hintergrundwissen

### Das Muster verallgemeinern

Das Dockerfile-Skelett aus Lab 07 ist nicht an nginx gebunden – es funktioniert für praktisch jede Software, die als Debian-Paket verfügbar ist:

```dockerfile
FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends <PAKET(E)> && \
    rm -rf /var/lib/apt/lists/*

# ... COPY eigener Dateien, ENV, CMD je nach Anwendungsfall
```

Nur `<PAKET(E)>` und das, was danach passiert, ändert sich mit dem Anwendungsfall:

| Ziel | apt-Paket(e) | Ergebnis |
|---|---|---|
| Statische Webseite | `nginx-light` | Portal v1 aus Lab 07 |
| API-Testwerkzeug | `curl`, `jq` | Container zum Abfragen und Aufbereiten von JSON-APIs |
| Datenbank-Client | `postgresql-client` | Werkzeug für Verbindungen zu einer laufenden PostgreSQL-Instanz, ohne den vollen Server zu installieren |
| Datei-Synchronisation | `rsync`, `openssh-client` | Container, der Dateien zu einem anderen Host spiegelt |
| Zeitgesteuerte Aufgaben | `cron` | Container, der wiederkehrende Aufgaben nach Zeitplan ausführt – Gegenstand dieser Übung |

### Automatisierung im Container: cron

`cron` ist der klassische Linux-Zeitplaner: Eine **Crontab**-Datei legt fest, *wann* ein Befehl ausgeführt werden soll. Innerhalb eines Containers gilt es dabei, zwei Besonderheiten zu beachten:

- Der cron-**Daemon** muss im **Vordergrund** laufen (`cron -f`), da ein Container beendet wird, sobald sein Hauptprozess (PID 1) endet – ein daemonisierender Hintergrundprozess würde den Container sofort wieder stoppen lassen, genau wie bei nginx in Lab 07.
- Systemweite, wiederkehrende Aufgaben werden unter Debian nicht in der persönlichen Crontab eines Benutzers, sondern als eigene Datei in `/etc/cron.d/` abgelegt. Eine solche Datei braucht zusätzlich zum Zeitplan auch einen **Benutzernamen**, unter dem der Befehl läuft (z. B. `root`) – ein Detail, das bei der persönlichen `crontab -e` entfällt.

> **Hinweis:** cron-in-einem-Container ist eine pragmatische, weit verbreitete Lösung für einfache Zeitpläne – aber kein Selbstläufer. Produktivsysteme setzen dafür teils auf host-seitige Zeitsteuerung (`systemd`-Timer, der z. B. `docker exec` aufruft) oder dedizierte Scheduler-Container. Eine der Reflexionsfragen greift das auf.

### ISO 27001: Control A.8.13 – Information Backup

Control A.8.13 verlangt, dass Backups von Informationen, Software und Systemen gemäß einer vereinbarten Richtlinie erstellt, getestet und regelmäßig überprüft werden. Für die Aufgabenstellung in diesem Lab bedeutet das konkret: ein **definierter, automatisierter, protokollierter** Zeitplan – nicht ein gelegentliches, manuelles „Mal-eben-Sichern".

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Übungsaufgabe

### Ausgangslage

Sie benötigen dieselbe Testumgebung wie in Lab 07, Schritt 4: ein Docker-Netzwerk und einen darin laufenden, mit Testdaten gefüllten InfluxDB-Container. Falls Sie diese Umgebung bereits abgebaut haben, legen Sie sie mit genau den dortigen Befehlen erneut an (Netzwerk `portal-test`, Container `influxdb`, Org `alp`, Bucket `iot`, dieselben drei Testpunkte im Measurement `umwelt`).

### Anforderungen (Definition of Done)

1. Ein neues Image `iot-backup:1.0`, gebaut aus einem eigenen Dockerfile auf Basis von `debian:trixie-slim`.
2. Jede zusätzlich benötigte Software wird ausschließlich über `apt install` eingerichtet – keine manuell heruntergeladenen Programme.
3. Ein Container aus diesem Image fragt automatisiert und wiederkehrend (alle 1–5 Minuten, gesteuert über `cron`) die Testdaten aus der InfluxDB-Instanz ab – mit derselben Technik wie das Portal in Lab 07: einer Flux-Abfrage per `curl` gegen `/api/v2/query`.
4. Jeder Abfragelauf wird als eigene, mit Zeitstempel benannte, **komprimierte** Datei in einem über Bind Mount eingebundenen Host-Verzeichnis abgelegt, z. B. `iot-backup-20260718-1432.csv.gz`.
5. Das InfluxDB-Token wird – wie beim Portal in Lab 07 – ausschließlich zur Laufzeit übergeben und taucht an keiner Stelle im Image auf.
6. Jeder Backup-Lauf wird nachvollziehbar protokolliert (z. B. in einer Log-Datei im Container, einsehbar per `docker exec`).

### Vorgehensvorschlag

Kein verbindlicher Ablauf, aber eine mögliche Orientierung:

- Legen Sie ein neues Projektverzeichnis an, z. B. `/srv/iot-backup/`.
- Überlegen Sie zuerst, welche Dateien Sie brauchen, bevor Sie das Dockerfile schreiben: ein Skript, das die eigentliche Abfrage und Sicherung durchführt, eine Crontab-Datei, die es zeitgesteuert aufruft, und das Dockerfile, das beides zusammenfügt.
- Denken Sie an ein Host-Verzeichnis für die Backup-Dateien, das Sie beim `docker run` per `-v` einbinden.

### Tipps, falls Sie nicht weiterkommen

> **Tipp 1 – cron und Umgebungsvariablen:** Prüfen Sie, ob Ihr Skript die per `-e` übergebenen Variablen tatsächlich sieht, wenn es **von cron aus** gestartet wird (nicht, wenn Sie es zum Test manuell im Container ausführen!). Cron startet Prozesse standardmäßig mit einer eigenen, minimalen Umgebung – die zur Laufzeit des Containers gesetzten Variablen sind darin nicht automatisch enthalten.

> **Tipp 2 – Format von `/etc/cron.d`-Dateien:** Dateien in `/etc/cron.d/` benötigen zwingend eine abschließende Leerzeile und – anders als die persönliche Crontab eines Benutzers – ein Benutzerfeld vor dem eigentlichen Befehl (z. B. `root`). Fehlt eines von beidem, ignoriert cron die Datei stillschweigend, ohne eine Fehlermeldung auszugeben.

### Ihre Lösung testen

- Baut das Image ohne Fehler?
- Läuft der Container dauerhaft (`docker ps`, nicht `Exited`)?
- Erscheinen nach ein paar Minuten neue `.csv.gz`-Dateien im Host-Verzeichnis?
- Lässt sich eine Backup-Datei entpacken und enthält sie die erwarteten Messwerte (`zcat <datei> | head`)?
- Zeigt das Log jeden Lauf nachvollziehbar an?

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Reflexion und weiterführende Fragen

- Wie würden Sie diesen Backup-Container in den Compose-Stack aus Lab 08 integrieren – welcher Dienst müsste dort ergänzt werden, und welche Volumes/Netzwerke bräuchte er?
- cron im Container gilt als pragmatische, aber diskutierte Lösung. Welche Alternativen gäbe es, denselben Zeitplan umzusetzen (Stichwort: Host-Cron, systemd-Timer, dedizierter Scheduler-Container)?
- Was müsste sich an Ihrer Lösung ändern, damit alte Backups automatisch nach einer definierten Aufbewahrungsfrist gelöscht werden?
- Welche weiteren Werkzeuge könnten Sie sich vorstellen, mit demselben Grundmuster (`FROM debian:trixie-slim` + `apt install`) als eigenes Image zu bauen?

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Wie geht es weiter?

Versuchen Sie zunächst, die Aufgabe selbstständig zu lösen. Eine vollständige Musterlösung – mit Dockerfile, Skripten und Testschritten – finden Sie in [`Lab_07_ausbau_musterloesung.md`](Lab_07_ausbau_musterloesung.md). Nutzen Sie sie, um Ihre eigene Lösung zu vergleichen oder falls Sie an einer Stelle nicht weiterkommen.

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Aufräumarbeiten

```bash
# Backup-Container und Image entfernen
docker stop iot-backup
docker rm iot-backup
docker rmi iot-backup:1.0

# Falls die Testumgebung nur für diese Übung neu angelegt wurde
docker stop influxdb
docker rm influxdb
docker network rm portal-test

# Eigene Projekt- und Backup-Verzeichnisse entfernen
rm -rf /srv/iot-backup
rm -rf /srv/backups
```

[↑ Zum Inhaltsverzeichnis](#inhalt)

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter, Florian Reichl
- Datum: 07/2026
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab_07.md"><img src="images/previous.png" width="150px"></a>
<a href="Lab_08.md"><img src="images/next.png" width="150px"></a>
</p>
