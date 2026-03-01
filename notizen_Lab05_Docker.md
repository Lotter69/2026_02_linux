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
- Portweiterleitung: getting-started ist ein Image, veranschaulicht die Integration von Containern in ein **lokales Netzwerk** mit dem Fokus auf das Verhältnis von container-port zu lokalen port des Hosts.
            - docker run -d -p 80:80 docker/getting-started
            - docker ps 
            - url Eingabe im Browser mit localhost
            - Inhalt des Webservers nicht verwenden. Es ist nur ein Beispiel für die Ports. Der lokale Rechner Port 80 könnte auch schon belegt sein
            - Daher statt lokalen Port 80 z. B. 8080 verwenden (syntax -p hostport:containerport)
            - container getting-started wieder löschen mit docker ps um namen oder ID herauszufinden, dann docker stop mit z. B. ID, dann docker rm fürs Löschen mit docker rm -f wird auch ein nichtgestoppter Container gelöscht.

Datenspeicherung in Volumes
- Veranschaulichung mit einem Image und Anwendungsbeispiel, welches Speicherung erfordert, z. B. ein Datenbank mit MariaDB
- Installation:
- >   docker run -d --name mariadb-test \ -e MYSQL_ROOT_PASSWORD=geheim mariadb
- >docker ps
- Volume wir bei Installation automatisch in /var/lib/mysql angelegt. Es gibt in der Beschreibung des Image eine Kennzeichnung. Erkenntnis: Das Volume ist ein Verzeichnis außerhalb des Containers
- in Linux /var/lib/docker/volumes. Verifizieren mit `docker inspect mariadb-test1`
- Differenzierung von Daten im Container und Daten im Volume. Volume bleibt und ein anderer Container kann die Daten im Volume übernehmen. z. B. in der Sitiuation eines Updates des Containers für die MariaDB
- Es besteht auch die Möglichkeit lokale Verzeichnisse auf dem Rechner mit Volumes zu verbinden
- der Befehl docker inspect mit Format-Option -f '{{}}' für das Filtern der umfanreichen Ausgabe
- z.B. Filteroption .Mounts für alle Mounts
- dann mit Namen `docker volume inspect name`
- die Größe eines Volumes muss mit `docker system df -v`ermittelt werden
- MariaDB bietet keine Interaktive Nutzung. Das geht nur mit dem Terminal im Container `docker exec`und den sql-Anweisungen. 
- docker exec -it mariadb-test mysql -u root -p
- dann z.B. show status
- der Blick in den Container geht mit Zgriff auf die Container-Bash
- docker exec -it mariadb-tesr /bin/bash
- Logging der DB sieht man mit docker logs mariadb-test
- Wir der Container gelöscht, bleibt das Volume, um beides zu löschen, geht man wie folgt vor: `docker inspect -f '{{.Mounts}}' mariadb-test`, dann weiß man den Namen des Volumes, dann container stoppen und löschen, dann Vomume mit `docker volume rm namen` löschen
- ist der container schon gelöscht wird es schwer zu Volume-Zuornung herauszubekommen. Mit `docker volume prune`löscht man alle nichtzugeordneten Volumens. **Vorsicht!!** wenn die Volumes später genutzt werden sollen, geht das nicht mehr.

Volumes mit Namen:
- Automatisch erzeugte Volumes erhalten einen zufälligen Namen (64-stellige Hex-Ziffer).
- mit der Option -v <vname>:<containerdir> kann eine Zuordnung eines frei gewählten Volumnamens zu einem Verzeichnis des Containers stattfinden.
- docker run -d --name mariadb-test `-v myvolume:/var/lib/mysql` -e MYSQL_ROOT_PASSWORD=geheim mariadb 

- nun ist mit docker inspect ein schnelle Auffinden des Volumens möglich
`docker inspect -f '{{.Mounts}}' mariadb-test`

Container-Update ohne Datenverlust - Vorgehen
- docker stop containername (container stoppen)
- docker rm containername (container löschen)
- docker pull neues Image (neues Images ziehen)
- docker run -d --name mariadb-test -v myvolume://var/lib/mysql mariadb (starten und mit Volume verbinden)
































- 
