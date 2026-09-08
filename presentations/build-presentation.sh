#!/bin/bash
# build-presentation.sh
# Baut Marp-Präsentationen in verschiedene Formate

set -e

# Farben für Output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Prüfe ob marp installiert ist
if ! command -v marp &> /dev/null; then
    echo -e "${RED}✗ Marp CLI ist nicht installiert!${NC}"
    echo ""
    echo "Installiere Marp mit:"
    echo "  sudo apt install -y nodejs npm"
    echo "  npm install -g @marp-team/marp-cli"
    exit 1
fi

# Eingabe-Datei prüfen
if [ $# -eq 0 ]; then
    echo "Usage: $0 <presentation.md> [output-dir]"
    echo ""
    echo "Beispiel:"
    echo "  $0 lab06-beispiel.md"
    echo "  $0 lab06-beispiel.md ../output"
    exit 1
fi

INPUT_FILE="$1"
OUTPUT_DIR="${2:-.}"
BASENAME=$(basename "$INPUT_FILE" .md)

# Prüfe ob Input-Datei existiert
if [ ! -f "$INPUT_FILE" ]; then
    echo -e "${RED}✗ Datei nicht gefunden: $INPUT_FILE${NC}"
    exit 1
fi

# Output-Verzeichnis erstellen falls nötig
mkdir -p "$OUTPUT_DIR"

echo -e "${BLUE}Building presentation: $INPUT_FILE${NC}"
echo ""

# HTML
echo -ne "${BLUE}→${NC} HTML generieren... "
marp "$INPUT_FILE" -o "$OUTPUT_DIR/$BASENAME.html" --html --theme-set ../themes/linux-theme.css
echo -e "${GREEN}✓${NC}"

# PDF
echo -ne "${BLUE}→${NC} PDF generieren... "
marp "$INPUT_FILE" -o "$OUTPUT_DIR/$BASENAME.pdf" --allow-local-files --theme-set ../themes/linux-theme.css --pdf
echo -e "${GREEN}✓${NC}"

# PowerPoint
echo -ne "${BLUE}→${NC} PowerPoint generieren... "
marp "$INPUT_FILE" -o "$OUTPUT_DIR/$BASENAME.pptx" --allow-local-files --theme-set ../themes/linux-theme.css --pptx
echo -e "${GREEN}✓${NC}"

echo ""
echo -e "${GREEN}✓ Präsentation erfolgreich generiert!${NC}"
echo ""
echo "Output:"
echo "  - HTML:       $OUTPUT_DIR/$BASENAME.html"
echo "  - PDF:        $OUTPUT_DIR/$BASENAME.pdf"
echo "  - PowerPoint: $OUTPUT_DIR/$BASENAME.pptx"
echo ""
echo "Öffne HTML im Browser:"
echo "  xdg-open $OUTPUT_DIR/$BASENAME.html"
