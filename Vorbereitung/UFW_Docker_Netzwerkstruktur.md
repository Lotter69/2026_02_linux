# UFW und Docker: Netzwerkstruktur und Firewall-Interaktion

## Übersicht

Dieses Diagramm zeigt, wie UFW (Uncomplicated Firewall) und Docker auf Netzwerk- und iptables-Ebene interagieren.

```mermaid
flowchart TB
    subgraph Internet["🌐 Internet / Externes Netzwerk"]
        Client[Client-Anfrage]
    end
    
    subgraph Host["Linux Host (eth0 / enp0s3)"]
        NIC[Netzwerk-Interface]
        
        subgraph Netfilter["Netfilter / iptables"]
            direction TB
            Raw[RAW Table]
            Mangle[MANGLE Table]
            
            subgraph Filter["FILTER Table"]
                Input[INPUT Chain]
                Forward[FORWARD Chain]
                Output[OUTPUT Chain]
                
                subgraph UFW_Chains["UFW Chains"]
                    UFW_Before[ufw-before-input<br/>ufw-before-forward]
                    UFW_User[ufw-user-input<br/>ufw-user-forward]
                    UFW_After[ufw-after-input<br/>ufw-after-forward]
                end
                
                subgraph Docker_Chains["Docker Chains"]
                    Docker_User[DOCKER-USER<br/>🔧 Hier eigene Regeln einfügen!]
                    Docker_Filter[DOCKER-ISOLATION<br/>DOCKER]
                end
            end
            
            subgraph NAT["NAT Table"]
                PreRouting[PREROUTING]
                PostRouting[POSTROUTING]
                Docker_NAT[DOCKER Chain<br/>Port Publishing]
            end
        end
        
        subgraph Docker_Network["Docker Netzwerk-Stack"]
            Docker0[docker0 Bridge<br/>172.17.0.1/16]
            CustomNet[Custom Networks<br/>bridge / overlay]
        end
        
        subgraph Containers["Docker Container"]
            Container1[Container 1<br/>172.17.0.2<br/>Port 80 → 8080]
            Container2[Container 2<br/>172.17.0.3<br/>Port 443 → 8443]
        end
    end
    
    Client -->|Port 80/443| NIC
    NIC --> Raw
    Raw --> Mangle
    Mangle --> NAT
    
    NAT -->|DNAT für<br/>Published Ports| Docker_NAT
    Docker_NAT -->|Ziel-Port Umschreibung| Filter
    
    Filter --> Forward
    Forward -->|⚠️ UFW wird übersprungen!| Docker_User
    Docker_User --> Docker_Filter
    Docker_Filter --> Docker0
    
    Docker0 --> CustomNet
    CustomNet --> Container1
    CustomNet --> Container2
    
    Forward -.->|sollte gehen durch| UFW_Before
    UFW_Before -.-> UFW_User
    UFW_User -.-> UFW_After
    
    Container1 -->|Antwort| PostRouting
    Container2 -->|Antwort| PostRouting
    PostRouting -->|SNAT/MASQUERADE| NIC
    
    style Docker_User fill:#ff9999,stroke:#cc0000,stroke-width:3px
    style Docker_Chains fill:#ffe6e6,stroke:#cc0000
    style UFW_Chains fill:#e6f3ff,stroke:#0066cc
    style Docker_Filter fill:#ffcccc
    style Docker0 fill:#ccffcc
```

## Wichtige Erkenntnisse

### Problem: Docker umgeht UFW

1. **UFW arbeitet mit iptables**, fügt Regeln in INPUT, FORWARD und OUTPUT Chains ein
2. **Docker manipuliert iptables direkt** und erstellt eigene Chains
3. **Docker-Regeln haben Vorrang**: Die DOCKER Chain wird VOR den UFW-Regeln in der FORWARD Chain ausgewertet
4. **Port Publishing (`-p 80:80`)** erstellt NAT-Regeln, die externe Verbindungen direkt an Container weiterleiten

### Lösung: DOCKER-USER Chain verwenden

Die **DOCKER-USER** Chain ist der offizielle Einstiegspunkt für eigene Firewall-Regeln:

```bash
# Beispiel: Nur Zugriff von bestimmtem Netzwerk erlauben
iptables -I DOCKER-USER -i eth0 ! -s 192.168.1.0/24 -j DROP
iptables -I DOCKER-USER -i eth0 -s 192.168.1.0/24 -j RETURN

# Oder: Zugriff auf bestimmten Container-Port einschränken
iptables -I DOCKER-USER -p tcp --dport 8080 ! -s 10.0.0.0/8 -j DROP
```

### Netzwerk-Flow für Published Ports

1. **Eingehende Anfrage** → Host-Interface (z.B. eth0)
2. **PREROUTING (NAT)** → DOCKER Chain macht DNAT (Port 80 → 172.17.0.2:8080)
3. **FORWARD** → DOCKER-USER Chain (hier können eigene Regeln greifen)
4. **DOCKER-ISOLATION / DOCKER** → Isolation zwischen Netzwerken prüfen
5. **docker0 Bridge** → Weiterleitung an Container
6. **Container** → Verarbeitung der Anfrage
7. **Rückweg**: POSTROUTING → MASQUERADE → zurück zum Client

### Alternativen zur Absicherung

1. **Ports nicht publishen** → `-p 127.0.0.1:80:80` (nur localhost)
2. **Reverse Proxy verwenden** → Caddy/nginx als Gateway, Container nicht direkt exponiert
3. **Docker-eigene Firewall** → In DOCKER-USER Chain arbeiten
4. **UFW deaktivieren** → Nur iptables-Regeln verwenden (nicht empfohlen für Anfänger)

## Weiterführende Konfiguration

### UFW so konfigurieren, dass Docker-Traffic gefiltert wird

In `/etc/ufw/after.rules` können zusätzliche Regeln eingefügt werden, die auch Docker-Traffic betreffen. Allerdings ist die DOCKER-USER Chain die sauberere Lösung.

### Docker mit iptables=false starten

In `/etc/docker/daemon.json`:
```json
{
  "iptables": false
}
```

**⚠️ Warnung**: Dann funktioniert Port-Publishing nicht mehr automatisch!

---

**Autoren**: Florian Reichl  
**Version**: 1.0  
**Datum**: September 2026
