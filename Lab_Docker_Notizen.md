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

- Image laden
- Container aus Image starten und über Parameter konfigurieren
- Eigene Images bauen (docker compose)
- (Später: Container über Traefik starten oder verwalten)