---
marp: true
theme: linux-theme
paginate: true
header: '![h:60](../images/logo.jpg)'
footer: 'Linux Administration 2026 | Kursüberblick'
---

<!-- _class: title -->

# Linux Administration
## Kursüberblick 2026

**Praxisorientierte Systemadministration**  
mit ISO 27001-Compliance

Florian Reichl, Michael Lotter

---

## Kursstruktur: 9 Labs in 3 Phasen

```mermaid
graph LR
    A["🖥️ Lab 01-02<br/>Lokale VM<br/>(Linux Mint)"] --> B["☁️ Lab 03-09<br/>Cloud Server<br/>(Debian)"]
    B --> C["🎓 Ausbau-Labs<br/>Vertiefung"]
    
    style A fill:#5B9BD5
    style B fill:#ED7D31
    style C fill:#70AD47
```

**Phase 1:** Linux Mint VM (lokal) - Labs 01-02  
**Phase 2:** Debian Cloud Server (remote) - Labs 03-09  
**Phase 3:** Spezialisierung & Vertiefung

---

## Technologie-Stack

<div class="columns">
<div>

**Basis**
- systemd
- SSH
- UFW Firewall

**Web**
- nginx + ACME
- Reverse Proxy
- TLS/HTTPS

</div>
<div>

**Container**
- Docker
- Docker Compose
- Netzwerke

**Monitoring**
- Cockpit
- journalctl
- Logs

</div>
</div>

---

<!-- _class: title -->

# Teil 1
## Lokale Umgebung

Labs 01-02 auf Linux Mint

---

<!-- _footer: 'Linux Administration 2026 | **Lab 01**: Cockpit & systemd' -->

## 🔧 Lab 01: Cockpit & systemd
### Lokale Systemverwaltung mit Web-UI

```mermaid
graph TB
    User[Browser] -->|Port 9090| Cockpit[Cockpit Web UI]
    Cockpit --> systemd[systemd]
    systemd --> Services[Dienste<br/>Status & Steuerung]
    systemd --> Journal[journalctl<br/>Logs]
    systemd --> System[Systemressourcen<br/>CPU, RAM, Disk]
    
    style Cockpit fill:#5B9BD5
    style systemd fill:#4472C4
```

**Lernziel:** Web-basierte Systemverwaltung

---

<!-- _footer: 'Linux Administration 2026 | **Lab 02**: systemd Units' -->

## ⚙️ Lab 02: systemd Units
### Eigene Services definieren

```mermaid
graph LR
    A[Unit File<br/>erstellen] --> B[systemctl<br/>enable]
    B --> C[Service<br/>starten]
    C --> D[Status<br/>prüfen]
    D --> E[Logs<br/>analysieren]
    
    style A fill:#5B9BD5
    style C fill:#70AD47
    style E fill:#ED7D31
```

**Lernziel:** Eigene Services definieren und verwalten

---

<!-- _class: title -->

# Teil 2
## Cloud Server

Labs 03-09 auf Debian Trixie

---

<!-- _footer: 'Linux Administration 2026 | **Lab 03**: Cloud-Setup' -->

## ☁️ Lab 03: Cloud-Setup
### Server, DNS & SSH-Keys

```mermaid
graph TB
    Domain[Domain] --> DNS[DNS A-Records]
    DNS --> Server[Cloud Server<br/>Debian]
    SSH[SSH Key] --> Server
    Server --> Firewall[UFW Firewall]
    
    style Server fill:#5B9BD5
    style DNS fill:#ED7D31
    style Firewall fill:#70AD47
```

**Lernziel:** Server-Grundkonfiguration & DNS

---

<!-- _footer: 'Linux Administration 2026 | **Lab 04**: Reverse Proxy mit Caddy' -->

## 🔀 Lab 04: Reverse Proxy (Caddy)
### Ein Gateway, viele Dienste

```mermaid
graph LR
    Internet[Internet<br/>Port 443] --> Caddy[Caddy<br/>Auto HTTPS]
    Caddy --> Service1[Cockpit<br/>:9090]
    Caddy --> Service2[Dienst A<br/>:8001]
    Caddy --> Service3[Dienst B<br/>:8002]
    
    style Caddy fill:#5B9BD5
    style Internet fill:#ED7D31
```

**Lernziel:** Ein Gateway für viele Dienste

---

<!-- _footer: 'Linux Administration 2026 | **Lab 05**: Docker Container' -->

## 📦 Lab 05: Docker Container
### Container-Grundlagen & Volumes

```mermaid
graph TB
    Hub[Docker Hub] -->|pull| Docker[Docker Engine]
    Docker --> Web[nginx-web<br/>Container]
    Docker --> NodeRed[Node-RED<br/>Container]
    Web --> Volume1[Volume<br/>www-data]
    NodeRed --> Volume2[Volume<br/>flows]
    
    style Docker fill:#5B9BD5
    style Hub fill:#4472C4
```

**Lernziel:** Container-Grundlagen & Volumes

---

<!-- _footer: 'Linux Administration 2026 | **Lab 06**: nginx + ACME | ISO 27001 A.8.24' -->

## 🔐 Lab 06: nginx + ACME
### Explizite Zertifikatsverwaltung

```mermaid
graph LR
    LE[Let's Encrypt<br/>CA] -->|ACME| nginx[nginx<br/>+ ACME Module]
    nginx -->|TLS| Cockpit[Cockpit]
    nginx -->|TLS| Services[4 weitere<br/>Dienste]
    
    style nginx fill:#5B9BD5
    style LE fill:#70AD47
```

**Lernziel:** Explizite ACME-Konfiguration  
**ISO 27001:** Control A.8.24

---

<!-- _footer: 'Linux Administration 2026 | **Lab 07**: Docker-Netzwerke | ISO 27001 A.8.22' -->

## 🌐 Lab 07: Docker-Netzwerke
### Netzwerk-Segmentierung & Isolation

```mermaid
graph TB
    subgraph "Standard Network"
        nginx2[nginx]
        nodered[Node-RED]
    end
    
    subgraph "app-net (isoliert)"
        nodered
        redis[Redis<br/>❌ kein Host-Port]
    end
    
    Internet[Internet] --> nginx2
    
    style redis fill:#ED7D31
    style nodered fill:#5B9BD5
```

**Lernziel:** Netzwerk-Segmentierung  
**ISO 27001:** Control A.8.22

---

<!-- _footer: 'Linux Administration 2026 | **Lab 08**: Dockerfile | ISO 27001 A.8.9, A.8.32' -->

## 🏗️ Lab 08: Dockerfile
### Eigene Images bauen

```mermaid
graph TB
    Dockerfile[Dockerfile] -->|docker build| Image[Portal Image<br/>portal:2.0]
    Image --> Container[Container<br/>Portal]
    Base[debian:trixie-slim] --> Dockerfile
    App[app.py] --> Dockerfile
    
    style Dockerfile fill:#5B9BD5
    style Image fill:#4472C4
```

**Lernziel:** Eigene Images bauen  
**ISO 27001:** Control A.8.9, A.8.32

---

<!-- _footer: 'Linux Administration 2026 | **Lab 09**: Docker Compose | ISO 27001 A.5.37' -->

## 🎼 Lab 09: Docker Compose
### Multi-Container-Orchestrierung

```yaml
# compose.yaml
services:
  mosquitto:
    image: eclipse-mosquitto:2
  nodered:
    image: nodered/node-red
  influxdb:
    image: influxdb:2
  grafana:
    image: grafana/grafana
```

**Lernziel:** Multi-Container orchestrieren  
**ISO 27001:** Control A.5.37

---

<!-- _footer: 'Linux Administration 2026 | **Lab 09**: Docker Compose (Fortsetzung)' -->

## 🎼 Lab 09: IoT-Pipeline-Stack

```mermaid
graph TB
    MQTT[Mosquitto<br/>MQTT Broker] --> NodeRed[Node-RED<br/>Flows]
    NodeRed --> InfluxDB[(InfluxDB<br/>Zeitreihen-DB)]
    InfluxDB --> Grafana[Grafana<br/>Dashboard]
    Portal[Portal<br/>Custom Image] --> InfluxDB
    
    nginx[nginx] --> Grafana
    nginx --> Portal
    
    style MQTT fill:#70AD47
    style InfluxDB fill:#5B9BD5
    style Grafana fill:#ED7D31
```

---

## Lab-Progression: Von Lokal zu Cloud

```mermaid
graph LR
    Lab1["🔧 Lab 01-02<br/>systemd"] --> Lab3["☁️ Lab 03<br/>SSH+DNS"]
    Lab3 --> Lab4["🔀 Lab 04<br/>Caddy"]
    Lab4 --> Lab5["📦 Lab 05<br/>Docker"]
    Lab5 --> Lab6["🔐 Lab 06<br/>nginx+ACME"]
    Lab6 --> Lab7["🌐 Lab 07<br/>Networks"]
    Lab7 --> Lab8["🏗️ Lab 08<br/>Dockerfile"]
    Lab8 --> Lab9["🎼 Lab 09<br/>Compose"]
    
    style Lab1 fill:#E7E6E6
    style Lab5 fill:#5B9BD5
    style Lab9 fill:#70AD47
```

**Progression:** Vom lokalen Dienst zur Cloud-Infrastruktur

---

## ISO 27001 Controls im Kurs

| Lab | Icon | Control | Thema |
|-----|------|---------|-------|
| **Lab 06** | 🔐 | A.8.24 | Verwendung von Kryptographie |
| **Lab 07** | 🌐 | A.8.22 | Netzwerk-Segmentierung |
| **Lab 08** | 🏗️ | A.8.9, A.8.32 | Konfigurations- & Änderungsmanagement |
| **Lab 09** | 🎼 | A.5.37 | Dokumentierte Verfahren |

**Praxisnahe Zertifizierungsvorbereitung**

---

## Finale Architektur

```mermaid
graph TB
    Internet[Internet] --> UFW[UFW Firewall<br/>Port 80/443]
    UFW --> nginx[nginx<br/>Reverse Proxy<br/>+ ACME/TLS]
    
    nginx --> Cockpit[Cockpit<br/>:9090]
    nginx --> Compose[Docker Compose Stack]
    
    subgraph "iot-net (isoliert)"
        Compose --> MQTT[Mosquitto]
        Compose --> NodeRed[Node-RED]
        Compose --> InfluxDB[(InfluxDB)]
        Compose --> Grafana[Grafana]
        Compose --> Portal[Portal]
    end
    
    style nginx fill:#5B9BD5
    style Compose fill:#ED7D31
    style InfluxDB fill:#4472C4
```

---

## Ausbau-Labs & Spezialisierung

**Lab 01 Ausbau**
- Socket Activation
- UFW Firewall Details
- Drop-in Files
- journalctl Deep-Dive

**Lab 08 Ausbau**
- Backup-Image mit Cron
- Pattern-Verallgemeinerung

**Lab Docker Rootless**
- Rootless Docker auf Linux Mint
- Sicherheits-Härtung

---

## Lernmethodik

<div class="columns">
<div>

**Praxisnah**
- Jedes Lab = Praxis
- Reale Server
- Produktionsnahe Szenarien

**Dokumentiert**
- Markdown-Anleitungen
- Schritt-für-Schritt
- Mit Erklärungen

</div>
<div>

**ISO-konform**
- Controls integriert
- Audit-Vorbereitung
- Best Practices

**Wiederholbar**
- Git-versioniert
- Reproduzierbar
- Nachvollziehbar

</div>
</div>

---

## Voraussetzungen

**Hardware**
- Laptop/PC für VirtualBox (Labs 1-2)
- Cloud Server (Labs 3-9)

**Vorkenntnisse**
- Linux-Grundlagen
- Kommandozeile
- Text-Editor (nano/vim)

**Software**
- Linux Mint 21/22 VM
- SSH-Client
- Webbrowser

---

## Ressourcen & Tools

**Dokumentation**
- Lab-Markdown-Dateien
- CLAUDE.md (Repository-Kontext)
- Inline-Erklärungen

**Tools**
- systemd / systemctl
- Docker / Docker Compose
- nginx / Caddy
- SSH / UFW
- Cockpit

---

## Kurs-Zeitplan

```mermaid
gantt
    title Linux Administration Kurs
    dateFormat  YYYY-MM-DD
    
    section Lokal
    Labs 01-02           :a1, 2026-02-01, 7d
    
    section Cloud-Setup
    Lab 03               :a2, 2026-02-08, 3d
    Lab 04               :a3, 2026-02-11, 3d
    
    section Docker
    Lab 05               :a4, 2026-02-14, 3d
    Lab 06-07            :a5, 2026-02-17, 5d
    Lab 08-09            :a6, 2026-02-22, 7d
```

**Flexibel anpassbar an Gruppe**

---

## Best Practices aus dem Kurs

✅ **Niemals** Root-Passwort-Login über SSH  
✅ **Immer** SSH-Key-Authentifizierung  
✅ **Immer** Firewall (UFW) aktiv  
✅ **Immer** TLS/HTTPS für Web-Services  
✅ **Container** ohne Root laufen lassen  
✅ **Secrets** in `.env`-Dateien, nie in Git  
✅ **Netzwerke** segmentieren  
✅ **Logs** zentral sammeln (journalctl)

---

## Häufige Stolpersteine

**SSH**
- Firewall-Regel vor SSH-Config!
- Key-Permissions: 600

**Docker**
- Ports nur lokal binden: `-p 127.0.0.1:8080:80`
- UFW vs. Docker: DOCKER-USER Chain

**nginx**
- `load_module` muss VOR `events {}`
- ACME braucht Port 80 offen

**systemd**
- `daemon-reload` nach Unit-Änderungen
- `--now` = enable + start gleichzeitig

---

## Erfolgs-Checkpoints

Nach dem Kurs können Sie:

✓ Eigene Cloud-Server aufsetzen & sichern  
✓ Web-Services mit TLS veröffentlichen  
✓ Docker-Container produktiv betreiben  
✓ Dienste mit systemd verwalten  
✓ Logs analysieren & Fehler beheben  
✓ ISO 27001-Anforderungen umsetzen  
✓ Infrastructure as Code (Compose)

---

<!-- _class: title -->

# Lab-Materialien

**Alle Markdown-Dateien verfügbar**

- Detaillierte Schritt-für-Schritt Anleitungen
- Code-Beispiele zum Copy & Paste
- Erklärungen & Hintergrundwissen
- Reflexionsfragen
- Zusammenfassungen

📁 Siehe Repository: `Lab_01.md` bis `Lab_09.md`

---

<!-- _class: title -->

# Viel Erfolg!

## Fragen vor dem Start?

**Weiter:** Lab 01 – Cockpit installieren

