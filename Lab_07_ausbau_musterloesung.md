# Lab 07: Erweiterung – Musterlösung

![line](images/banner.png)

> Diese Datei enthält eine vollständige Musterlösung zur Übungsaufgabe aus [`Lab_07_ausbau.md`](Lab_07_ausbau.md). Es gibt nicht die eine richtige Lösung – vergleichen Sie Ihre eigene Umsetzung mit dieser, statt sie als einzig gültigen Weg zu betrachten.

## Inhalt

- [Projektstruktur](#projektstruktur)
- [Die Dateien im Einzelnen](#die-dateien-im-einzelnen)
  - [entrypoint.sh](#entrypointsh)
  - [backup.sh](#backupsh)
  - [crontab.txt](#crontabtxt)
  - [Dockerfile](#dockerfile)
- [Bauen und testen](#bauen-und-testen)
- [Design-Entscheidungen im Überblick](#design-entscheidungen-im-überblick)
- [Autoren und Urheberrecht](#autoren-und-urheberrecht)

---

## Projektstruktur

```bash
mkdir -p /srv/iot-backup
cd /srv/iot-backup
```

```
/srv/iot-backup/
├── Dockerfile
├── entrypoint.sh
├── backup.sh
└── crontab.txt
```

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Die Dateien im Einzelnen

### entrypoint.sh

```bash
nano entrypoint.sh
```

```bash
#!/bin/bash
set -e

# cron startet Prozesse mit einer eigenen, minimalen Umgebung - die per
# "docker run -e" gesetzten Variablen kommen dort NICHT automatisch an.
# Deshalb werden sie hier einmalig beim Containerstart in eine Datei
# geschrieben, die backup.sh bei jedem Lauf selbst einliest.
printenv | grep -E '^INFLUX_' > /etc/backup-env

exec cron -f
```

> **Was passiert hier?**  
> `printenv | grep -E '^INFLUX_'` filtert aus allen beim Containerstart gesetzten Umgebungsvariablen genau die drei heraus, die mit `INFLUX_` beginnen (`INFLUX_URL`, `INFLUX_ORG`, `INFLUX_BUCKET`, `INFLUX_TOKEN`), und schreibt sie in `/etc/backup-env`. `exec cron -f` ersetzt anschließend den Shell-Prozess durch `cron` im Vordergrund – dadurch bleibt `cron` Prozess 1 im Container und empfängt Signale (z. B. bei `docker stop`) direkt, statt über eine Zwischenschicht.

### backup.sh

```bash
nano backup.sh
```

```bash
#!/bin/bash
set -e

# Von entrypoint.sh beim Containerstart hinterlegte INFLUX_*-Variablen einlesen,
# da cron sie nicht automatisch zur Verfuegung stellt
source /etc/backup-env

ZEITSTEMPEL=$(date +%Y%m%d-%H%M%S)
ZIEL="/backup/iot-backup-${ZEITSTEMPEL}.csv.gz"

FLUX_QUERY="from(bucket: \"${INFLUX_BUCKET}\") |> range(start: -24h)"

curl -s -X POST "${INFLUX_URL}/api/v2/query?org=${INFLUX_ORG}" \
  -H "Authorization: Token ${INFLUX_TOKEN}" \
  -H "Content-Type: application/json" \
  -d "{\"query\": \"${FLUX_QUERY}\", \"dialect\": {\"annotations\": []}}" \
  | gzip > "${ZIEL}"

echo "$(date '+%Y-%m-%d %H:%M:%S') Backup geschrieben: ${ZIEL}" >> /var/log/backup.log
```

> **Was passiert hier?**  
> Dieselbe Flux-Abfrage und derselbe HTTP-POST wie im Portal aus Lab 07, Schritt 5.1 – nur dass die Antwort hier nicht in eine HTML-Tabelle gerendert, sondern direkt per Pipe an `gzip` übergeben und komprimiert in eine mit Datum und Uhrzeit benannte Datei geschrieben wird. Jeder Lauf erzeugt so eine eigene, unveränderliche Sicherungsdatei.

### crontab.txt

```bash
nano crontab.txt
```

```
*/2 * * * * root /usr/local/bin/backup.sh >> /var/log/cron.log 2>&1

```

> **⚠️ Wichtig:** Beachten Sie die **Leerzeile am Dateiende** – Dateien in `/etc/cron.d/` werden von cron ohne abschließenden Zeilenumbruch stillschweigend ignoriert. Das Feld `root` (zwischen Zeitplan und Befehl) ist bei `/etc/cron.d`-Dateien ebenfalls Pflicht; es legt fest, unter welchem Benutzer der Befehl läuft – anders als bei der persönlichen Crontab eines einzelnen Benutzers (`crontab -e`), wo dieses Feld entfällt.
>
> `*/2 * * * *` bedeutet „alle 2 Minuten" (Minute, Stunde, Tag, Monat, Wochentag – `*/2` in der ersten Spalte: jede zweite Minute). Für ein Produktivsystem wäre ein selteneres Intervall (z. B. stündlich oder täglich) realistischer; die 2 Minuten hier dienen nur dazu, das Ergebnis im Rahmen dieser Übung zügig beobachten zu können.

### Dockerfile

```bash
nano Dockerfile
```

```dockerfile
FROM debian:trixie-slim

RUN apt-get update && \
    apt-get install -y --no-install-recommends cron curl && \
    rm -rf /var/lib/apt/lists/*

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
COPY backup.sh /usr/local/bin/backup.sh
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/backup.sh

COPY crontab.txt /etc/cron.d/iot-backup
RUN chmod 0644 /etc/cron.d/iot-backup

RUN mkdir -p /backup && \
    touch /var/log/cron.log /var/log/backup.log

ENV INFLUX_URL=http://influxdb:8086 \
    INFLUX_ORG=alp \
    INFLUX_BUCKET=iot

CMD ["/usr/local/bin/entrypoint.sh"]
```

| Zeile | Bedeutung |
|---|---|
| `apt-get install ... cron curl` | Nur diese beiden Pakete werden zusätzlich benötigt. `gzip` ist Teil des Debian-Basissystems (Priorität `required`) und muss nicht eigens installiert werden – auch die `-slim`-Variante entfernt nur Dokumentation und ähnlichen Ballast, keine essenziellen Werkzeuge |
| `COPY .../crontab.txt /etc/cron.d/iot-backup` | Legt die Cron-Konfiguration am von Debian erwarteten Ort ab; der Dateiname selbst ist frei wählbar |
| `chmod 0644 /etc/cron.d/iot-backup` | cron verlangt für Dateien in `/etc/cron.d/` genau diese Berechtigung – nicht ausführbar, nur für den Eigentümer beschreibbar |
| `mkdir -p /backup` | Zielverzeichnis für die Backup-Dateien – wird beim `docker run` per Bind Mount mit einem Host-Verzeichnis verbunden |
| `ENV INFLUX_URL=... INFLUX_ORG=... INFLUX_BUCKET=...` | Dieselben Vorgabewerte wie beim Portal aus Lab 07 – nur `INFLUX_TOKEN` fehlt bewusst, da es niemals im Image stehen darf |
| `CMD [".../entrypoint.sh"]` | Startet den Wrapper, der die Umgebungsvariablen sichert und anschließend cron im Vordergrund startet |

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Bauen und testen

Testumgebung wie in Lab 07, Schritt 4 (bei Bedarf neu anlegen):

```bash
docker network create portal-test 2>/dev/null; true
docker run -d --name influxdb --network portal-test \
  -e DOCKER_INFLUXDB_INIT_MODE=setup \
  -e DOCKER_INFLUXDB_INIT_USERNAME=admin \
  -e DOCKER_INFLUXDB_INIT_PASSWORD='<SICHERES-PASSWORT>' \
  -e DOCKER_INFLUXDB_INIT_ORG=alp \
  -e DOCKER_INFLUXDB_INIT_BUCKET=iot \
  -e DOCKER_INFLUXDB_INIT_ADMIN_TOKEN='<TOKEN>' \
  influxdb:2
```

Image bauen:

```bash
docker build -t iot-backup:1.0 .
```

Host-Verzeichnis für die Backups anlegen und Container starten:

```bash
mkdir -p /srv/backups
docker run -d --name iot-backup \
  --restart unless-stopped \
  --network portal-test \
  -e INFLUX_TOKEN='<TOKEN>' \
  -v /srv/backups:/backup \
  iot-backup:1.0
```

Nach ein bis zwei Minuten prüfen:

```bash
docker ps                              # iot-backup laeuft dauerhaft, kein Exited
ls -la /srv/backups                    # erste .csv.gz-Datei sollte erscheinen
zcat /srv/backups/iot-backup-*.csv.gz | head    # Inhalt der aeltesten Sicherung ansehen
docker exec iot-backup cat /var/log/backup.log  # Protokoll aller Laeufe
docker exec iot-backup cat /var/log/cron.log    # Ausgabe/Fehler von cron selbst
```

> **Tipp zur Fehlerbehebung:** Bleibt `/srv/backups` leer, prüfen Sie zuerst `docker exec iot-backup cat /var/log/cron.log` – erscheint dort gar nichts, hat cron die Datei `/etc/cron.d/iot-backup` vermutlich wegen eines Formatfehlers (fehlende Leerzeile, fehlendes `root`-Feld) ignoriert. Erscheinen Fehlermeldungen zu leeren Variablen, prüfen Sie `docker exec iot-backup cat /etc/backup-env` – ist die Datei leer oder fehlt sie, ist `entrypoint.sh` nicht wie vorgesehen gelaufen.

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Design-Entscheidungen im Überblick

- **`cron` statt einer Endlosschleife mit `sleep`:** Beide Wege wären technisch möglich. `cron` wurde hier bewusst gewählt, weil es das in der Praxis geläufigere Werkzeug für zeitgesteuerte Aufgaben ist und zusätzlich das apt-install-Muster auf ein neues Paket überträgt.
- **Umgebungsvariablen-Datei statt direktem `docker exec`-Aufruf:** Die Umleitung über `/etc/backup-env` ist der Standardweg, um cron-Jobs in Containern Zugriff auf zur Laufzeit gesetzte Variablen zu geben. Alternativ ließe sich `INFLUX_TOKEN` auch fest in die Crontab-Zeile schreiben – das würde das Geheimnis jedoch für jeden lesbar machen, der `docker exec iot-backup cat /etc/cron.d/iot-backup` ausführt, und widerspräche damit demselben Prinzip wie in Lab 07.
- **Komprimierung mit `gzip` statt unkomprimiert:** Spart Speicherplatz auf Dauer und ist mit einem einzigen Pipe-Befehl umsetzbar – kein zusätzliches Paket nötig.
- **Kein automatisches Löschen alter Backups:** Bewusst nicht Teil dieser Musterlösung, sondern als Reflexionsfrage offengelassen – ein produktives System bräuchte eine explizite Aufbewahrungsfrist (Retention Policy), die je nach Kontext unterschiedlich ausfallen kann.

[↑ Zum Inhaltsverzeichnis](#inhalt)

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter, Florian Reichl
- Datum: 07/2026
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab_07_ausbau.md"><img src="images/previous.png" width="150px"></a>
<a href="Lab_08.md"><img src="images/next.png" width="150px"></a>
</p>
