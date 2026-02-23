# Laborübung: Cockpit – Web-basiertes Systemmanagement

![line](images/banner.png)

## Einführung

In dieser Laborübung installieren und konfigurieren Sie **Cockpit** – eine moderne, webbasierte Verwaltungsoberfläche für Linux-Systeme, entwickelt von Red Hat. Sie lernen, wie ein Dienst über das Paketverwaltungssystem **apt** installiert, mit **systemd** dauerhaft aktiviert und betrieben wird und wie Konfigurationsänderungen unter `/etc` sicher gehandhabt werden.

Cockpit ist ein ideales Praxisbeispiel, um grundlegende Linux-Administration zu erlernen: Es verbindet Paketverwaltung, Dienstverwaltung und Konfigurationsmanagement in einem realen Anwendungsfall.

## Lernziele

- Einen Dienst mit **`apt install`** installieren und den Installationsstatus prüfen
- Den Dienst mit **`systemctl`** starten, stoppen und dauerhaft aktivieren
- Das **Startverhalten** des Dienstes mit systemd dauerhaft sicherstellen (`enable`)
- **Konfigurationsänderungen** unter `/etc` vornehmen und den Dienst gezielt neu starten
- Die **Funktionsweise von systemd** und Unit-Dateien verstehen
- Grundlegende Fragen zu **Verfügbarkeit, Sicherheit, Skalierbarkeit und Ausfallsicherheit** reflektieren

## Voraussetzungen

| Anforderung | Details |
|---|---|
| **Betriebssystem** | Linux Mint 21.x (Cinnamon, MATE oder XFCE) |
| **Benutzerrechte** | sudo-Berechtigung erforderlich |
| **Internetzugang** | Für apt-Paketinstallation |
| **Browser** | Firefox oder Chromium (lokal installiert) |
| **Terminal** | GNOME Terminal, Konsole oder vergleichbar |

## Aufgaben

### Schritt 1: System aktualisieren und Cockpit installieren

#### 1.1 Paketquellen aktualisieren

Bevor ein neues Paket installiert wird, synchronisieren Sie die lokale Paketdatenbank. Öffnen Sie ein Terminal und führen Sie aus:

```bash
sudo apt update
```

> **Was passiert hier?**  
> `apt update` lädt die aktuellen Paketlisten von den konfigurierten Quellen herunter. Es werden dabei **keine** Pakete installiert oder aktualisiert – nur die Metadaten (Paketname, Version, Abhängigkeiten) werden erneuert.

#### 1.2 Cockpit installieren

```bash
sudo apt install cockpit -y
```

Das `-y`-Flag bestätigt alle Rückfragen automatisch. apt löst Abhängigkeiten auf, lädt die Pakete herunter und legt dabei automatisch eine **systemd-Unit-Datei** für den Dienst an.

#### 1.3 Installation überprüfen

```bash
dpkg -l cockpit
```

> **Tipp:** Achten Sie auf den Status `ii` am Zeilenanfang – das bedeutet: **i**nstalliert und korrekt konfiguriert. Ein `rc` würde bedeuten, das Paket wurde entfernt, aber Konfigurationsdateien sind noch vorhanden.

---

### Schritt 2: Den Cockpit-Dienst mit systemd verwalten

> **Was ist systemd?**  
> **systemd** ist der Init-Prozess (PID 1) auf modernen Linux-Distributionen. Er ist verantwortlich für das Starten, Stoppen und Überwachen aller Dienste und wird direkt beim Hochfahren des Systems als erster Prozess gestartet. Dienste werden in sogenannten **Unit-Dateien** beschrieben, die systemd mitteilen, wie und wann ein Dienst gestartet werden soll. apt hat beim Installieren von Cockpit automatisch eine solche Unit-Datei angelegt – Sie müssen den Dienst nur noch aktivieren.

#### 2.1 Aktuellen Dienststatus prüfen

Nach der Installation ist Cockpit möglicherweise noch nicht aktiv. Prüfen Sie den Status:

```bash
sudo systemctl status cockpit
```

Relevante Ausgaben:
- `Active: active (running)` → Dienst läuft
- `Active: inactive (dead)` → Dienst ist gestoppt
- `Loaded: ... enabled` / `disabled` → Autostart-Verhalten beim Systemstart

#### 2.2 Dienst starten

```bash
sudo systemctl start cockpit
sudo systemctl status cockpit
```

#### 2.3 Dienst dauerhaft beim Systemstart aktivieren

Damit Cockpit nach einem Neustart automatisch startet, muss der Dienst **aktiviert** werden:

```bash
sudo systemctl enable --now cockpit
```

> **`enable` vs. `start`**  
> - `systemctl start` → startet den Dienst **sofort**, nur für die aktuelle Sitzung  
> - `systemctl enable` → aktiviert den **Autostart** beim nächsten Systemstart  
> - `systemctl enable --now` → kombiniert beides in einem Schritt

#### 2.4 Neustart simulieren und Persistenz prüfen

Starten Sie den Rechner neu:

```bash
sudo reboot
```

Prüfen Sie nach dem Neustart, ob Cockpit automatisch gestartet wurde:

```bash
sudo systemctl status cockpit
```

> **Tipp zur Fehlerbehebung:** Falls Cockpit nach dem Neustart nicht aktiv ist, prüfen Sie mit `sudo systemctl is-enabled cockpit`, ob `enable` korrekt ausgeführt wurde.

#### 2.5 Cockpit im Browser aufrufen

Öffnen Sie Ihren Browser und rufen Sie auf:

```
https://localhost:9090
```

Melden Sie sich mit Ihrem Linux-Benutzernamen und -Passwort an. Da das Zertifikat selbstsigniert ist, müssen Sie im Browser eine **Sicherheitsausnahme** bestätigen.

---

### Schritt 3: Konfigurationsänderungen und sicherer Dienstneustart

#### 3.1 Konfigurationsverzeichnis kennenlernen

Konfigurationsdateien von Cockpit liegen unter `/etc/cockpit/`. Erkunden Sie das Verzeichnis:

```bash
ls -la /etc/cockpit/
```

> **Hinweis:** Das Verzeichnis existiert, ist aber zunächst leer – Cockpit läuft nach der Installation mit seinen eingebauten Standardwerten, ohne dass eine eigene Konfigurationsdatei vorhanden ist. Eigene Einstellungen werden erst durch das Anlegen einer `cockpit.conf` aktiv.

#### 3.2 Neue Konfigurationsdatei anlegen

Die Datei `/etc/cockpit/cockpit.conf` existiert noch nicht und muss neu erstellt werden. Öffnen Sie nano mit dem gewünschten Dateipfad – nano legt die Datei beim Speichern automatisch an:

```bash
sudo nano /etc/cockpit/cockpit.conf
```

Fügen Sie folgenden Inhalt ein:

```ini
[WebService]
Origins = https://localhost:9090

[Session]
Banner = /etc/cockpit/issue.cockpit
```

Speichern Sie mit `Strg+O`, bestätigen mit `Enter`, beenden mit `Strg+X`.

#### 3.3 Login-Banner erstellen

```bash
echo 'Willkommen – nur für autorisierte Benutzer!' \
  | sudo tee /etc/cockpit/issue.cockpit
```

#### 3.4 Dienst nach Konfigurationsänderung neu starten

```bash
sudo systemctl restart cockpit
```

> **Warum `restart` statt `stop` + `start`?**  
> `systemctl restart` führt Stopp und Start **atomar** in einem kontrollierten Schritt durch. Bei manuell hintereinander ausgeführten Befehlen `stop`/`start` entsteht ein kurzes Zeitfenster, in dem der Dienst nicht erreichbar ist. Zudem kann systemd bei Diensten mit `Type=notify` sicherstellen, dass der neue Prozess vollständig gestartet ist, bevor der alte beendet wird.

#### 3.5 Ergebnis überprüfen

```bash
sudo systemctl status cockpit

# Port-Erreichbarkeit prüfen:
ss -tlnp | grep 9090
```

Rufen Sie `https://localhost:9090` erneut im Browser auf und prüfen Sie, ob das Banner beim Login erscheint.

---

### Schritt 4: systemd – Unit-Datei analysieren und Befehle nachschlagen

#### 4.1 Die Unit-Datei von Cockpit analysieren

Jeder mit apt installierte Dienst bringt eine Unit-Datei mit, die systemd beschreibt, wie der Dienst zu starten ist. Sehen Sie sich die Unit-Datei von Cockpit an:

```bash
systemctl cat cockpit.service
```

Die drei wichtigsten Abschnitte sind:

| Abschnitt | Bedeutung |
|---|---|
| `[Unit]` | Beschreibung und Abhängigkeiten (`Requires=`, `After=`) |
| `[Service]` | Startbefehl (`ExecStart=`), Neustartverhalten (`Restart=`) |
| `[Install]` | Autostart-Ziel (`WantedBy=multi-user.target`) |

Neben `.service`-Dateien kennt systemd weitere Unit-Typen, die in späteren Erweiterungsaufgaben relevant werden:

| Typ | Beispiel | Funktion |
|---|---|---|
| `.service` | `cockpit.service` | Hintergrundprozess / Daemon |
| `.socket` | `cockpit.socket` | Socket-Aktivierung: Dienst startet erst bei eingehender Verbindung |
| `.timer` | `apt-daily.timer` | Geplante Ausführung (Ersatz für cron) |
| `.target` | `multi-user.target` | Gruppeneinheit, vergleichbar mit einem Runlevel |

#### 4.2 Wichtige systemctl-Befehle im Überblick

```bash
sudo systemctl start cockpit       # Sofort starten
sudo systemctl stop cockpit        # Sofort stoppen
sudo systemctl restart cockpit     # Neu starten
sudo systemctl reload cockpit      # Konfiguration neu laden (ohne Prozessneustart)
sudo systemctl enable cockpit      # Autostart aktivieren
sudo systemctl disable cockpit     # Autostart deaktivieren
sudo systemctl status cockpit      # Status und letzte Logs
sudo systemctl is-active cockpit   # Gibt 'active' oder 'inactive' zurück
sudo systemctl is-enabled cockpit  # Gibt 'enabled' oder 'disabled' zurück

journalctl -u cockpit              # Alle Logs des Dienstes
journalctl -u cockpit -f           # Logs live verfolgen (follow)
journalctl -b -u cockpit           # Logs nur vom aktuellen Boot
```

---

### Schritt 5: Reflexion und Erweiterungsaufgaben

Nachdem Sie Cockpit lokal auf einem einzelnen Rechner betrieben haben – ohne weitere Absicherung, Redundanz oder Skalierungsmaßnahmen – ist es Zeit für eine strukturierte Reflexion.

#### 5.1 Reflexionsfragen

**Verfügbarkeit**
- Was passiert, wenn der Server, auf dem Cockpit läuft, ausfällt oder neu gestartet wird?
- Cockpit ist aktuell nur über `localhost` erreichbar. Was wäre notwendig, damit andere Geräte im Netzwerk darauf zugreifen können?
- Wie können Sie sicherstellen, dass Cockpit nach einem unerwarteten Absturz automatisch neu startet? *(Hinweis: `Restart=` in der Unit-Datei)*

**Sicherheit**
- Das Zertifikat ist selbstsigniert. Welche Risiken birgt das in einem produktiven Umfeld?
- Cockpit lauscht standardmäßig auf Port 9090. Welche Maßnahmen würden Sie ergreifen, um den Zugriff auf autorisierte Clients zu beschränken? *(Stichwort: Firewall, `ufw`)*
**Skalierbarkeit & Energieeffizienz**
- Cockpit läuft permanent im Hintergrund. Welche Alternative bietet systemd, um einen Dienst nur dann zu starten, wenn tatsächlich eine Verbindung eingeht? *(Stichwort: Socket-Aktivierung, `cockpit.socket`)*
- Wie verhält sich Ihr Setup, wenn Sie 50 Server statt eines verwalten möchten? Welche Werkzeuge würden Sie dann einsetzen?

**Ausfallsicherheit**
- Was wäre notwendig, um Cockpit hochverfügbar zu betreiben (kein Single Point of Failure)?
- Welche Rolle spielen Backups der `/etc/cockpit/`-Konfiguration für die Wiederherstellung nach einem Systemausfall?

---

#### 5.2 Erweiterungsaufgabe A: Socket-Aktivierung

Deaktivieren Sie `cockpit.service` und aktivieren Sie stattdessen `cockpit.socket`, damit Cockpit erst bei einer eingehenden Verbindung gestartet wird:

```bash
sudo systemctl disable --now cockpit
sudo systemctl enable --now cockpit.socket
```

Beobachten Sie mit `journalctl -u cockpit -f`, **wann** der Dienst startet. Was stellen Sie fest? Welche Auswirkungen hat das auf den Ressourcenverbrauch?

---

#### 5.3 Erweiterungsaufgabe B: Firewall mit ufw konfigurieren

Installieren und konfigurieren Sie `ufw` (Uncomplicated Firewall), sodass Port 9090 nur aus dem lokalen Netzwerk erreichbar ist:

```bash
sudo apt install ufw -y
sudo ufw allow from 192.168.0.0/24 to any port 9090
sudo ufw enable
sudo ufw status verbose
```

> **Tipp zur Fehlerbehebung:** Passen Sie das Subnetz `192.168.0.0/24` an Ihr tatsächliches lokales Netzwerk an. Prüfen Sie Ihre IP-Adresse mit `ip addr show`.

---

#### 5.4 Erweiterungsaufgabe C: Automatischen Neustart konfigurieren

Erstellen Sie eine systemd-**Drop-in-Datei**, die Cockpit bei einem Absturz automatisch neu startet:

```bash
sudo mkdir -p /etc/systemd/system/cockpit.service.d/
sudo nano /etc/systemd/system/cockpit.service.d/restart.conf
```

Inhalt der Datei:

```ini
[Service]
Restart=on-failure
RestartSec=5s
```

Änderungen aktivieren:

```bash
sudo systemctl daemon-reload
sudo systemctl restart cockpit
```

Testen Sie den automatischen Neustart, indem Sie den Prozess gezielt beenden:

```bash
sudo kill -9 $(pgrep cockpit)
sleep 6
sudo systemctl status cockpit
```

---

#### 5.5 Erweiterungsaufgabe D: Logs mit journalctl analysieren

```bash
journalctl -u cockpit --since '1 hour ago'
journalctl -u cockpit --no-pager | grep -i error
journalctl -b -u cockpit
```

Beantworten Sie: Welche Informationen finden Sie in den Logs? Wann und aus welchem Grund wurde Cockpit gestartet oder gestoppt?

---

## Rückblick und Zusammenfassung

### Was Sie erreicht haben

- Einen Dienst mit **`apt install`** installiert und den Status geprüft
- **systemd** verstanden: start, stop, restart, enable – und den Unterschied zwischen sofortigem Start und persistentem Autostart
- Konfigurationsänderungen unter **`/etc`** vorgenommen und den Dienst sicher neu gestartet
- **Unit-Dateien** analysiert und die Struktur von systemd-Diensten verstanden
- Die **Grenzen eines einfachen lokalen Setups** reflektiert und Ansätze zur Erweiterung erarbeitet

### Reflexion

– In welchen Szenarien ist ein dauerhaft laufender Dienst sinnvoll – und wann ist Socket-Aktivierung die bessere Wahl?  
– Wie würden Sie dieses Setup automatisiert auf mehreren Servern ausrollen? *(Stichwort: Ansible)*  
– Was würde sich ändern, wenn Cockpit in einem Container statt direkt auf dem Host betrieben würde?

---

## Aufräumarbeiten

Versetzen Sie Ihr System in den ursprünglichen Zustand:

```bash
# Dienst stoppen und deaktivieren
sudo systemctl disable --now cockpit cockpit.socket

# Paket vollständig entfernen
sudo apt purge cockpit -y
sudo apt autoremove -y

# Eigene Konfigurationsdateien löschen
sudo rm -rf /etc/cockpit/cockpit.conf /etc/cockpit/issue.cockpit
sudo rm -rf /etc/systemd/system/cockpit.service.d/
```

> **Tipp:** Mit `dpkg -l cockpit` können Sie nach dem Aufräumen prüfen, ob das Paket vollständig entfernt wurde. Der Status `rc` zeigt an, dass das Paket entfernt wurde, aber Konfigurationsdateien noch vorhanden sind (entfernt werden diese mit `purge`).

## Autoren und Urheberrecht

- Erstellt von: Michael Lotter
- Datum: 2025
- Version: v1.0

![line](images/banner.png)
<p align="center">
<a href="README.md"><img src="images/previous.png" width="150px"></a>
<a href="02_erweiterung_dienste_skalierung.md"><img src="images/next.png" width="150px"></a>
</p>
