# Ideen und Notizen zum Docker-Lab

## Installation

Ein `apt install docker.io` scheint zu genügen.

## Überprüfung der Installation

Mit `docker version` erfährt man, welche Version installiert ist.

Mit `docker run hello-world` kann man einen ersten Funktionstest durchführen.

## Begriffe:

- __Docker__: Name einer Firma, [Docker Inc.](https://www.docker.com/), und der von ihr entwickelten Software zu Verwaltung und Betrieb von Containern.
- __OCI__: Open Container Initiative, Zusammenschluss von Software-Herstellern, die ähnliche Software wie Docker Inc. bereitstellen, z. B. [Podman](https://podman.io/).
- __Image__: Abbild eines Dateisystems in dem das Programm ist, welches man ausführen möchte.
- __Container__: Abbild eines Computers, der das Dateisystem im Image nutzt.

## Hinweise zur Installation

- Benutzer zur Benutzergruppe `docker` hinzufügen.

## Quellen für Docker Images

Typische Quellen
- [Docker Hub](https://hub.docker.com/)
- GHCR – Github Container Registry, vermutlich eng mit Microsoft verknüpft.

## Schritte

- Images laden
- Container aus Image starten und über Parameter konfigurieren
- Container regelmäßig starten über Unit-Files (systemd)
- Images (und damit Container) aktualisieren
- Container und Images wieder entfernen
- Container über Traefik starten und verwalten
- Eigene Images bauen (docker compose)

# Gliederung von Claude dazu:

## Modul 1: Grundlagen & Einstieg
- Docker-Architektur verstehen (Daemon, CLI, Registry; Unterschied zu VMs)
- Installation auf Linux (Debian/Ubuntu, RHEL/Rocky etc.)
- Post-Install-Schritte (z. B. Nutzer zur Docker-Gruppe hinzufügen)
- Docker Hub & alternative Registries (GitHub Container Registry, quay.io, etc.)
- Images suchen, bewerten und laden (offizielle vs. Community-Images, Tags, Image-Größe)

## Modul 2: Container starten & konfigurieren
- Container aus einem Image starten (`docker run`)
- Konfiguration über Parameter (Umgebungsvariablen, Port-Mapping, Volumes)
- Container verwalten (`docker ps`, `docker stop`, `docker rm`)
- Container und Images entfernen (`docker rmi`, `docker system prune`)

## Modul 3: Netzwerk & Datenpersistenz
- Netzwerkmodi verstehen (`bridge`, `host`, `none`, benutzerdefinierte Netzwerke)
- Container-Kommunikation im selben Netzwerk
- Volumes & Bind Mounts (persistente Datenspeicherung, Unterschiede)
- Port-Mapping im Detail

## Modul 4: Docker Compose & Multi-Container-Setups
- Docker Compose Grundlagen (`compose.yaml`-Syntax, `docker compose up/down/logs`)
- Multi-Container-Setups (z. B. Web-App + Datenbank + Cache)
- Umgebungsvariablen & `.env`-Dateien

## Modul 5: Eigene Images bauen
- Dockerfile schreiben (`FROM`, `RUN`, `COPY`, `CMD`, `ENTRYPOINT`, `ENV`, `EXPOSE`)
- Layer-Konzept & Caching verstehen
- Multi-Stage Builds für schlanke Produktions-Images
- Best Practices (Image-Größe minimieren, non-root User)
- Images in einer Registry veröffentlichen (`docker push`, Tagging-Strategien)

## Modul 6: Automatisierung mit systemd
- Container regelmäßig/automatisch starten über Unit-Files
- systemd vs. `docker compose` als Alternative
- Automatischer Neustart bei Ausfall (`restart`-Policy)
- Health Checks (`HEALTHCHECK` im Dockerfile)

## Modul 7: Reverse Proxy mit Traefik
- Traefik-Grundlagen & Architektur
- Container über Traefik starten und verwalten
- Konfiguration über Labels in `compose.yaml`
- TLS & automatische Zertifikate mit Let's Encrypt
- Middlewares (Authentifizierung, Redirects, Rate Limiting)

## Modul 8: Sicherheit
- Least-Privilege-Prinzip & non-root Container
- Read-only Dateisysteme
- Ressourcenlimits (CPU, RAM)
- Secrets-Management (keine Secrets in Images!)
- Image-Scanning mit `trivy` oder `docker scout`

## Modul 9: Betrieb, Monitoring & Backup
- Logging (`docker logs`, Log-Treiber: journald, syslog)
- Monitoring & Ressourcenüberwachung (`docker stats`, Prometheus/Grafana)
- Updates: Images und Container aktualisieren
- Backup-Strategien für Volumes
