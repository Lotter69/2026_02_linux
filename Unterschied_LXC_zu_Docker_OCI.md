## Unterschied zwischen LXC und OCI-Containern

Hinweise:

- Text kommt von Claude Sonnet 4.6 auf den Prompt `Was ist der Unterschied zwischen LXC und OCI-Containern?`
- LXC ist die Technologie von [Proxmox](https://www.proxmox.com/)
- OCI-Container ist die Technologie von [Docker](https://www.docker.com/), [Podman](https://podman.io/) usw.
- Auf das Thema kamen wir durch eine Diskussion mit Thomas Stallinger, ALP.

### LXC (Linux Containers)

**LXC** ist eine **ältere, systemnahe Containertechnologie** (seit 2008), die direkt auf den Linux-Kernel-Features **cgroups** und **namespaces** aufsetzt.

- **Ziel:** Vollständige, leichtgewichtige Linux-Systemumgebung simulieren (ähnlich einer VM, aber ohne eigenen Kernel)
- **Einsatzzweck:** Systemcontainer – man betreibt darin ein vollständiges Linux-Betriebssystem (z. B. Ubuntu, Debian)
- **Verwaltung:** Direkt über `lxc`-Tools oder Proxmox VE
- **Isolation:** Prozesse, Dateisystem, Netzwerk, Nutzer werden isoliert
- **Persistenz:** Container sind typischerweise **langlebig** (ähnlich wie VMs)
- **Images:** Distributionsspezifische Root-Filesysteme

---

### OCI-Container (z. B. Docker, Podman)

**OCI** steht für **Open Container Initiative** – ein offener Standard (seit 2015), der das Format und die Laufzeitumgebung von Containern definiert.

- **Ziel:** **Anwendungscontainer** – einzelne Dienste oder Prozesse werden isoliert ausgeführt
- **Einsatzzweck:** Microservices, CI/CD-Pipelines, Cloud-native Anwendungen
- **Verwaltung:** Docker, Podman, containerd, Kubernetes etc.
- **Isolation:** Ebenfalls cgroups + namespaces, aber auf Anwendungsebene
- **Persistenz:** Container sind typischerweise **kurzlebig** (ephemeral) und können jederzeit neu erstellt werden
- **Images:** Schichtbasierte Images (Layer), portabel und über Registries (z. B. Docker Hub) verteilbar

---

### Vergleichstabelle

| Merkmal | LXC | OCI (Docker/Podman) |
|---|---|---|
| **Abstraktionsebene** | Betriebssystem | Anwendung / Prozess |
| **Inhalt** | Vollst. Linux-System | Einzelner Dienst/App |
| **Lebenszeit** | Langlebig (wie VM) | Kurzlebig (ephemeral) |
| **Portabilität** | Gering | Sehr hoch |
| **Image-Standard** | Kein universeller Standard | OCI Image Spec |
| **Typische Tools** | lxc, Proxmox | Docker, Podman, K8s |
| **Komplexität** | Mittel | Gering (einfache Nutzung) |
| **Overhead** | Gering | Sehr gering |

---

### Zusammenfassung

> - **LXC** eignet sich, wenn man eine **vollständige Linux-Umgebung** benötigt, z. B. für mehrere Dienste auf einem Server (klassischer Serveransatz).
> - **OCI-Container** eignen sich für **moderne, portable Anwendungen**, die in Microservices aufgeteilt sind und schnell skaliert oder deployt werden sollen.

In der Praxis werden beide Technologien oft ergänzend eingesetzt – z. B. LXC-Container auf Proxmox für Systemdienste, OCI-Container (Docker/Kubernetes) für Applikationen in der Cloud.
