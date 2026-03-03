# Kritik
## Berufliche Aufgabenstellung

- Was ist mit interner Dienst gemeint? Wir möchten, dass der Dienst aus dem Internet verfügbar ist und deshalb mit HTTPS abgesichert wird.
- Wir nutzen einen Cloud Provider wie z. B. Hetzner.
- Wir möchten statt unterschiedlicher Routen wie `/` und `/nodered` wollen wir Subdomains wie `www.meinserver.de` und `dashboard.meinserver.de`. 
- Wir wollen Caddy nicht im Container einrichten, sondern wollen den mit `apt install` bereits installierten Caddy nutzen.
- Docker ist noch nicht installiert.
- Anweisung für Lab 5, 6 und 7 verwerfen; Fortsetzung ab Lab_04
- Volume deutlich machen und erklären. Zum Beispiel beim Start des ngix-Servers muss klar werden, das es sich um ein Volume handelt.
- Frage: Was passiert, wenn der Container nginx-web aktualisiert wird? Wie bleibt das Volume vorhanden?
- Beim Schritt 3 fehlt die Erklärung für das Volume, wie sie z. B. in Schritt 4 erfolgt.
- Mache einen Exkurs, falls eine Person in Nodered eine Benutzerverwaltung haben möchte.
- Erkläre die Syntax von `-p 80:8080` und `-v host:container`.
- Erkläre, warum Nodered nicht verschlüsselt werden muss. Hinweis auf das Szenario mit Caddy.
- Test-Flow für NodeRed nicht nötig.
- Warum sind die IP-Adressen nötig? Genügt nicht `localhost:80` bzw. `localhost:1880` als Unterscheidungsmerkmal?
- Kann man anstelle von `docker inspect` auch in einem Terminal in die Container gehen und dort die IP-Adresse ermitteln?
- Der Begriff wird `Schicht` wird benutzt ohne ihn zuvor zu erklären.
- Begriffe "Bind Mount" und "Volume" in Beziehung bringen?
- Woher kommt `nodered-data`? Die Unterscheidung von Volumes, die auf Verzeichnisse im Dateisystem zeigen und Volumes, die von Docker verwaltet werden ist unklar.