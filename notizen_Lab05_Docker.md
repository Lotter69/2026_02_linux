Installation unter Linux
- kostenlose Variante
- Installation systemweite Installation mit root-Rechten 
- nur offizielle Dockerpakete (ist das ein eigenes Repository?)

Schritte (siehe auch https://docs.docker.com/engine/install/ubuntu)
- ggf. bereits Installierte Paketquellen entfernen
- Installation der Basispakete mit kurzer Erklärung der Bedeutung
    - apt-transport-https
    - ca-certificates
    - curl
    - gpg
- Installation Schlüssel für neue Docker Paketquelle (Repository)
- Konfiguration der Paketquelle in /etc/apt/sources.list.d/docker.list
- apt update
- apt install docker -ce (Docker Community Edition, der eigentliche Docker Dämon, verwaltet Container, Images, Netzwerke, Volumes)
- apt install docker -ce-cli (Docker Kommandozeilen Schnittstelle)
- apt install containerd.io (Container-Laufzeitumgebung)

Achtung bei ufw-Nutzung ist keine Netzwerkbrücke zu DockerContainer möglich, daher
- in etc/default/ufw
DEFAULT_FORWARD_POLICY="ACCEPT"


Grundlagen erschließen mit interaktiven Übungen, d.h. docker Befehl nutzen (nicht nur Theorie)
- Image vs Container (Erklärung)
- Trennung von unveränderbaren und veränderbaren Anteilen
- Basisimage nutzen um ein neues Image zu erstellen
    - siehe auch Imgages für Programmieraufgaben, Imgages für ... bestimmte Schwerpunkte (wie Appliances in GNS3 Marketplace)
- Konzept der Volumes als getrennte Bauteile (Modul) vom Container und die daraus entstehenden Vorteile
    - Ort der Volumes (z. B. var/lib/docker/volumes)
    - Suche nach volumes mit docker inspect

Service, Stack (mehrere Services), Cluster bzw. Schwarm  mit mehreren Dockerinstanzen
- Docker-Swarm (für Docker-Container) oder Kubernetes verwalten Container in Clustern 
- für unser Ziel zunächst nicht relevant, da wir uns auf einen Rechner mit mehreren Containern zufrieden geben
- Docker-Compose hingegen ist wichtig, weil eine Gruppe von Containern (Cluster) gebündelt wird

Dämon bzw. Engine ist Server, Container ist Client.
Mit Befehl Docker wird die Engine gesteuert

Vertrautheit mit Docker Nomenklatur duch Übung
- Funktionalität: Image laden, Container erzeugen und Container starten mit **docker run hello world**
- Liste aller Container mit **docker ps -a**
- Löschen nicht benötigter Images **docker rm [name1, name2]**
- Verkettung **docker run --rm hello-world**

Erste Experimente mit Basis-Images (mehr als ein Dienst z. B. Debian, Ubuntu) als Startpunkt für eigene Entwicklungen ???

- ein Basisimage beziehen, einen Container draus erzeugen und ausführen und das Ergebnis sehen (CLI eines Ubuntu) und Umgebung erkunden (Hostname, Info zur Distribution, Umfang des Dateisystems, laufende Prozesse, IP ermitteln (Standard und wie gewohnt in Ubuntu, festgestellte IP-Adresse einordnen (privat, Bereich, Beziehung zur realen IP des Hosts, ) verlassen der CLI und beenden des Containers)  mit z. B. **docker run -it ubuntu** oder  **docker run -it ubuntu:21.04**

Übungen um den Unterschied von Container und Image besser zu verstehen
- Neuer Namen eines Containers nach Neustart? **strg+D oder exit und docker run**
- in ubuntu container eine speichernde Verändeurng vornehmen(z. B. Datei anlegen), Container neustart, Datei suchen und nichts finden, d.h. mit docker run imagename wird jedes mal ein neuer Container angelegt. Jeder Container hat eine andere UID
- Erkenntnis daraus: nicht imagenamen sonder containernamen (bzw. uid) mit **docker start** angeben nicht docker run
- Containernamen selbst vergeben mit docker run --name plus zusätzlich Vergabe eines Hostnamens für Basisimage z. B. myubuntu mit docker run -h myubuntu
- Container löschen (docker ps -a, docker rm [name][name]) vs. Image löschen (docker image rm [name]), wie und bei welchem Anlass




















- 
