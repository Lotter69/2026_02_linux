# Docker-Zusatz: Rootless Docker mit Docker Compose

![line](images/banner.png)

## Einführung

Docker ermöglicht es, Anwendungen in isolierten Containern zu betreiben. Im „normalen" Modus läuft der Docker-Daemon als Root – ein Sicherheitsrisiko, denn ein kompromittierter Container könnte damit Kontrolle über das gesamte Host-System erlangen.

**Rootless Docker** löst dieses Problem: Der Docker-Daemon und alle Container laufen vollständig im Kontext Ihres normalen Benutzerkontos – ohne Root-Rechte. Ermöglicht wird das durch User-Namespaces und das Tool `rootlesskit`, das die Isolation zwischen Host- und Container-Benutzern herstellt.

Eine Besonderheit bei Linux Mint: Mint verwendet eigene Versionsnamen (z. B. „zena"), die Dockers Repository nicht kennt. Das Repository erwartet den zugrundeliegenden Ubuntu-Codenamen (z. B. „noble"). Dies müssen Sie bei der Konfiguration berücksichtigen.

In diesem Lab installieren Sie Rootless Docker und Docker Compose auf Linux Mint, konfigurieren die Umgebung korrekt und testen die Installation mit einem ersten Container.

## Lernziele

- Dockers offizielles APT-Repository korrekt für Linux Mint einrichten
- Den Unterschied zwischen normalem Docker-Betrieb und Rootless Mode erklären
- Rootless Docker installieren und als Benutzer-Systemdienst einrichten
- Umgebungsvariablen (`PATH`, `DOCKER_HOST`) verstehen und persistent konfigurieren
- Docker Compose als CLI-Plugin nutzen
- Die Installation mit einem Test-Container und `docker compose version` verifizieren

## Voraussetzungen

| Anforderung | Details |
|---|---|
| **Betriebssystem** | Linux Mint 21 oder 22 (Ubuntu-Basis: jammy oder noble) |
| **Benutzer** | Normales Benutzerkonto mit sudo-Rechten |
| **Internetzugang** | Benötigt für Download der Pakete |
| **Terminal** | Grundlegende Kenntnisse der Bash-Kommandozeile |

---

## Inhalt

- [Aufgaben](#aufgaben)
  - [Schritt 1: Voraussetzungen installieren](#schritt-1-voraussetzungen-installieren)
  - [Schritt 2: Ältere Docker-Pakete entfernen](#schritt-2-ältere-docker-pakete-entfernen)
  - [Schritt 3: Dockers offizielles APT-Repository einrichten](#schritt-3-dockers-offizielles-apt-repository-einrichten)
    - [3.1 GPG-Schlüssel hinzufügen](#31-gpg-schlüssel-hinzufügen)
    - [3.2 Repository eintragen](#32-repository-eintragen)
  - [Schritt 4: Docker Engine und Compose installieren](#schritt-4-docker-engine-und-compose-installieren)
  - [Schritt 5: Rootless Docker einrichten](#schritt-5-rootless-docker-einrichten)
  - [Schritt 6: Installation prüfen](#schritt-6-installation-prüfen)
- [Reflexion und weiterführende Fragen](#reflexion-und-weiterführende-fragen)
- [Rückblick und Zusammenfassung](#rückblick-und-zusammenfassung)
- [Aufräumarbeiten](#aufräumarbeiten)
- [Autoren und Urheberrecht](#autoren-und-urheberrecht)

---

## Aufgaben

### Schritt 1: Voraussetzungen installieren

Installieren Sie die benötigten Pakete. Das Paket `uidmap` ist für den Rootless-Betrieb zwingend erforderlich – es ermöglicht das User-Namespace-Mapping, das die Isolation zwischen Host- und Container-Benutzern herstellt:

```bash
sudo apt update
sudo apt install -y curl ca-certificates fuse uidmap
```

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

### Schritt 2: Ältere Docker-Pakete entfernen

Falls auf dem System bereits ältere oder inoffizielle Docker-Pakete vorhanden sind, entfernen Sie diese zuerst, um Konflikte zu vermeiden:

```bash
for pkg in docker.io docker-doc docker-compose podman-docker containerd runc; do
  sudo apt-get remove -y $pkg
done
```

| Segment | Bedeutung |
|---|---|
| `for pkg in <liste>` | Schleifenkopf: die Variable `pkg` nimmt nacheinander jeden Wert aus der Liste an |
| `do ... done` | Rahmen: alles dazwischen wird einmal **pro Wert** der Liste ausgeführt |
| `sudo apt-get remove -y $pkg` | Schleifenrumpf: `$pkg` wird durch den jeweils aktuellen Listenwert ersetzt (erster Durchlauf: `docker.io`, zweiter: `docker-doc`, …) |

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

### Schritt 3: Dockers offizielles APT-Repository einrichten

Docker wird nicht über die Standard-Paketquellen von Linux Mint installiert, sondern direkt aus Dockers offiziellem Repository. Dieses Repository signiert seine Pakete kryptografisch – APT prüft die Signatur bei jedem Download anhand des GPG-Schlüssels.

#### 3.1 GPG-Schlüssel hinzufügen

```bash
sudo install -m 0755 -d /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \    # Erzeugen: Schlüssel-Datei laden
  sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  # Filtern/Umwandeln: in Binärformat wandeln, per -o direkt in Datei schreiben

sudo chmod a+r /etc/apt/keyrings/docker.gpg
```

> **Hinweis zu `chmod a+r`**  
> `sudo chmod a+r` setzt Leserechte für alle Benutzer auf den GPG-Schlüssel. APT läuft nicht immer als Root – ohne dieses Recht kann APT den Schlüssel nicht lesen und verweigert die Installation der Docker-Pakete.

#### 3.2 Repository eintragen

Linux Mint verwendet eigene Versionsnamen. Dockers Repository kennt nur Ubuntu-Codenamen. Daher müssen Sie den Ubuntu-Codenamen manuell ermitteln und eintragen:

```bash
. /etc/os-release
UBUNTU_CODENAME=$(cat /etc/upstream-release/upstream-codename \
  2>/dev/null || echo $VERSION_CODENAME)

echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  ${UBUNTU_CODENAME} stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```

| Segment | Bedeutung |
|---|---|
| `. /etc/os-release` | Systemvariablen (u. a. `$VERSION_CODENAME`) in die aktuelle Shell laden |
| `UBUNTU_CODENAME=$(...)` | Variable anlegen, Wert kommt aus einer Command Substitution |
| `cat .../upstream-codename 2>/dev/null` | Versuch, den Ubuntu-Codenamen aus einer Mint-spezifischen Datei zu lesen; Fehlermeldungen werden unterdrückt |
| `\|\| echo $VERSION_CODENAME` | Fallback: nur wenn der `cat`-Befehl fehlschlägt (`\|\|` = „oder, falls vorheriger Befehl scheitert"), wird stattdessen der Mint-Codename ausgegeben |
| `$(dpkg --print-architecture)` | Command Substitution: liefert die CPU-Architektur |
| `${UBUNTU_CODENAME}` | Einsetzen der zuvor ermittelten Variable in den Text |
| `\| sudo tee ... > /dev/null` | Ablegen: in Datei schreiben, Bildschirmausgabe unterdrückt |

> **Warum nicht den Mint-Codenamen verwenden?**  
> Dockers Repository kennt Codenamen wie „noble" (Ubuntu 24.04) oder „jammy" (Ubuntu 22.04), aber nicht „zena" (Linux Mint 22). Das Skript versucht zuerst, den Ubuntu-Codenamen aus einer Mint-spezifischen Datei zu lesen. Schlägt das fehl, wird auf `$VERSION_CODENAME` zurückgegriffen – liefert dieser den Mint-Namen, müssen Sie `noble` (für Mint 22) oder `jammy` (für Mint 21) manuell eintragen.

Prüfen Sie nach dem Eintragen, welcher Codename in der Datei steht:

```bash
cat /etc/apt/sources.list.d/docker.list
```

Die Ausgabe muss einen Ubuntu-Codenamen enthalten (`noble` oder `jammy`), nicht `zena`. Falls `zena` steht, korrigieren Sie die Datei:

```bash
echo "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu noble stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
```
(gleiche Befehlsstruktur wie oben – nur `${UBUNTU_CODENAME}` durch den fest eingetragenen Codenamen `noble` ersetzt)

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

### Schritt 4: Docker Engine und Compose installieren

```bash
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras
```

| Paket | Aufgabe |
|---|---|
| `docker-ce` | Docker Engine – der Daemon, der Container verwaltet |
| `docker-ce-cli` | Kommandozeilen-Tool (`docker`-Befehl) |
| `containerd.io` | Container-Laufzeitumgebung |
| `docker-buildx-plugin` | Erweitertes Build-System |
| `docker-compose-plugin` | Docker Compose als CLI-Plugin |
| `docker-ce-rootless-extras` | Zusätzliche Tools für den Rootless-Betrieb |

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

### Schritt 5: Rootless Docker einrichten

> **⚠️ Wichtig:** Führen Sie diesen Schritt als normaler Benutzer aus – nicht mit `sudo`!

```bash
dockerd-rootless-setuptool.sh install
```

Das Setup-Skript gibt am Ende die benötigten Umgebungsvariablen aus. Tragen Sie diese in Ihre `~/.bashrc` ein:

```bash
echo 'export PATH=/usr/bin:$PATH' >> ~/.bashrc
  # Erzeugen: Zeile mit PATH-Erweiterung | Ablegen: ans Ende der Datei anhängen (>>)
echo 'export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock' >> ~/.bashrc
  # $(id -u): Command Substitution, liefert die eigene Benutzer-ID | Ablegen: ebenfalls anhängen
source ~/.bashrc
```

> **Was bedeuten diese Umgebungsvariablen?**  
> `PATH=/usr/bin:$PATH` stellt sicher, dass der `docker`-Befehl gefunden wird.  
> `DOCKER_HOST` teilt dem `docker`-CLI mit, wo der Rootless-Daemon lauscht. Ohne `DOCKER_HOST` würde `docker` versuchen, den Root-Daemon anzusprechen (über `/var/run/docker.sock`) und eine Fehlermeldung erhalten.

Aktivieren Sie den Docker-Dienst für Ihren Benutzer:

```bash
systemctl --user enable --now docker
sudo loginctl enable-linger $USER
```

> **`loginctl enable-linger`**  
> Standardmäßig werden Benutzer-Systemdienste (`systemd --user`) beendet, sobald sich der Benutzer abmeldet. `enable-linger` verhindert das: Ihr Docker-Daemon läuft auch ohne aktive Anmeldesitzung weiter.

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

### Schritt 6: Installation prüfen

Testen Sie Docker mit einem einfachen Container:

```bash
docker run hello-world
```

Wenn Sie die Meldung „Hello from Docker!" sehen, läuft Rootless Docker korrekt.

Prüfen Sie Docker Compose:

```bash
docker compose version
```

Die Ausgabe sollte die Versionsnummer des Compose-Plugins zeigen, z. B. `Docker Compose version v2.x.x`.

> **`docker-compose` vs. `docker compose`**  
> Docker Compose v1 war ein eigenständiges Programm (`docker-compose` mit Bindestrich). Ab Version 2 ist Compose direkt in die Docker CLI integriert und wird als Subcommand ohne Bindestrich aufgerufen: `docker compose`. Das alte `docker-compose` ist nicht mehr verfügbar.

Prüfen Sie zusätzlich den Status des Rootless-Dienstes:

```bash
systemctl --user status docker
```

Der Dienst muss als `active (running)` gemeldet sein.

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Reflexion und weiterführende Fragen

**Zum Rootless-Betrieb**

- Warum ist Rootless Docker sicherer als der normale Betrieb? Was kann ein Angreifer im Rootless-Modus nicht tun, was im normalen Modus möglich wäre?
- Was ist der Zweck von `DOCKER_HOST`? Was passiert, wenn Sie `docker` ohne diese Variable aufrufen?
- Warum benötigt Rootless Docker das Paket `uidmap`? Was passiert ohne es?

**Zur Installation**

- Warum kann man Docker auf Linux Mint nicht direkt aus den Standard-Paketquellen installieren? Was ist der Vorteil der offiziellen Docker-Paketquelle?
- Was bedeutet `2>/dev/null` in einem Shell-Befehl? Warum wird es beim Ermitteln des Ubuntu-Codenamens verwendet?
- Was ist der Unterschied zwischen `systemctl --user` und `sudo systemctl`? Wann wird welches verwendet?

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- Dockers offizielles APT-Repository für Linux Mint korrekt eingerichtet (Ubuntu-Codename statt Mint-Codename)
- Docker Engine, Docker Compose Plugin und Rootless-Extras installiert
- Rootless Docker konfiguriert: Docker-Daemon läuft ohne Root-Rechte
- Umgebungsvariablen `PATH` und `DOCKER_HOST` persistent in `~/.bashrc` eingetragen
- Docker-Dienst als Benutzer-Systemdienst aktiviert und Linger eingerichtet
- Installation mit `hello-world` und `docker compose version` verifiziert

### Zentrale Befehle dieser Übung

| Befehl | Bedeutung |
|---|---|
| `sudo apt install -y ... docker-ce-rootless-extras` | Docker mit Rootless-Unterstützung installieren |
| `dockerd-rootless-setuptool.sh install` | Rootless-Modus einrichten (als normaler User) |
| `export DOCKER_HOST=unix:///run/user/$(id -u)/docker.sock` | Docker-CLI auf Rootless-Daemon zeigen lassen |
| `systemctl --user enable --now docker` | Docker-Daemon für den eigenen Benutzer starten und aktivieren |
| `sudo loginctl enable-linger $USER` | Benutzer-Dienste auch ohne aktive Sitzung am Laufen halten |
| `docker run hello-world` | Erster Test-Container |
| `docker compose version` | Compose-Plugin prüfen |
| `systemctl --user status docker` | Status des Rootless-Daemons prüfen |

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Aufräumarbeiten

Falls Sie die Installation rückgängig machen möchten:

```bash
# Rootless-Setup entfernen
dockerd-rootless-setuptool.sh uninstall

# Pakete deinstallieren
sudo apt remove -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras

# Repository und GPG-Schlüssel entfernen
sudo rm /etc/apt/sources.list.d/docker.list
sudo rm /etc/apt/keyrings/docker.gpg

# Umgebungsvariablen aus ~/.bashrc entfernen (manuell mit nano)
nano ~/.bashrc
```

[↑ Zum Inhaltsverzeichnis](#inhalt)

---

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter, Florian Reichl
- Datum: 06/2026
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="Lab_05.md"><img src="images/previous.png" width="150px"></a>
<a href="README.md"><img src="images/next.png" width="150px"></a>
</p>
