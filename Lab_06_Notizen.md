# Überlegungen zu Lab_06.md

## Nach Test der Laborübung am 18.6. von Michael Lotter: 
- Konzept der nginx-Konfiguration als Reverse Proxy ist klar
- Konzept der Dockernetze und deren Einsatz ist klar
- Lastverteilung mit Upstream-Gruppe (Nginx-Konfig) für stateless Dienste und Round Robin ist klar

- noch offen ist die Lastverteilung mit stateful-Diensten?
- wie ist das eigentlich mit den automatisch erzeugten IPs in den Docker-Netzen und gibt es ein Routing?

Schwierigkeiten für den Anfänger sind immer wieder Befehle, die häufig vorkommen um zum Bsp. etwas einer Datei hinzuzufügen 
mit echo ...
mit Filter | grep
mit curl und dann irgendwo ablegen 

hilfreich sind natürlich Übungen vom Einfachen zum Komplexen um das Konzept zu verstehen oder klar erkennbare und trennbare Elemente einer Befehlszeile (Befehl, Pfad, Schalter, ...)

wie in Schritt 2 

zudem werden die Seiten pro Laborübung lang. was gibt es für Ansätze der schnellern Navigation im Kursinhalt. z. B. am Anfang jeder Seite eine Verlinkung auf Überschriften und Teilschritte.

## Vorgehen

- Aufgabenstellung so formulieren, dass die Nutzung von Docker Netzen zwingend notwendig wird.
- Warum werden Dienste auf mehrere Container aufgteilt, die im selben Docker-Netz sind, wenn es auch möglich ist, diese Dienste in 1 Container zusammenzufassen?
- Wie wird ein Docker-Netz weitergegeben, wenn ich meine Container beim Kunden installieren möchte?
- 