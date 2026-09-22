#!/bin/bash

# 1. Lokale Änderungen hinzufügen und committen
git add .
git commit -m "$(date)"

# 2. Änderungen vom Server holen und eigene Commits oben draufsetzen
if git pull --rebase; then
    # 3. Nur pushen, wenn das Pull/Rebase fehlerfrei war
    git push
    echo "Erfolgreich synchronisiert und hochgeladen."
else
    echo "Fehler beim Pull/Rebase! Wahrscheinlich gibt es einen Merge-Konflikt."
    echo "Bitte löse den Konflikt manuell und führe 'git rebase --continue' aus."
    exit 1
fi