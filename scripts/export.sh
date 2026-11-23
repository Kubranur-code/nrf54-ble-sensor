#!/usr/bin/env bash
# Rebuild all manufacturing/doc outputs with kicad-cli (KiCad 9).
set -euo pipefail
cd "$(dirname "$0")/.."
CLI="${KICAD_CLI:-kicad-cli}"
command -v "$CLI" >/dev/null || CLI="/c/Program Files/KiCad/9.0/bin/kicad-cli.exe"
N=nrf54-ble-sensor
mkdir -p fab/gerbers docs/img
PY=""
for c in "py -3" python3 python; do $c -c "import zipfile" >/dev/null 2>&1 && { PY="$c"; break; }; done
[ -n "$PY" ] || { echo "Python not found (needed for the Gerber zip)"; exit 1; }

"$CLI" sch erc --exit-code-violations -o fab/erc.rpt $N.kicad_sch
"$CLI" pcb drc --exit-code-violations --schematic-parity -o fab/drc.rpt $N.kicad_pcb

"$CLI" sch export pdf -o docs/$N-schematic.pdf $N.kicad_sch
"$CLI" pcb export gerbers -o fab/gerbers/ --board-plot-params $N.kicad_pcb
"$CLI" pcb export drill -o fab/gerbers/ --format excellon --excellon-separate-th $N.kicad_pcb
"$CLI" pcb export pos -o fab/$N-cpl.csv --format csv --units mm --side both --exclude-dnp $N.kicad_pcb
# JLCPCB CPL headers: Designator, Mid X, Mid Y, Layer, Rotation
$PY - fab/$N-cpl.csv <<'PYEOF'
import csv, sys
p = sys.argv[1]
rows = list(csv.DictReader(open(p, newline="")))
with open(p, "w", newline="") as f:
    w = csv.writer(f)
    w.writerow(["Designator", "Mid X", "Mid Y", "Layer", "Rotation"])
    for r in rows:
        w.writerow([r["Ref"], r["PosX"] + "mm", r["PosY"] + "mm", "Top" if r["Side"] == "top" else "Bottom", r["Rot"]])
PYEOF
"$CLI" sch export bom -o fab/$N-bom.csv \
  --fields 'Reference,Value,Footprint,${QUANTITY},LCSC Part' \
  --labels 'Designator,Comment,Footprint,Quantity,LCSC Part #' \
  --group-by 'Value,Footprint' --ref-range-delimiter '' --exclude-dnp $N.kicad_sch

rm -f fab/$N-gerbers.zip
(cd fab/gerbers && $PY -m zipfile -c ../$N-gerbers.zip *)

"$CLI" pcb render -o docs/img/render-top.png --side top --quality high -w 1600 -h 1200 $N.kicad_pcb
"$CLI" pcb render -o docs/img/render-bottom.png --side bottom --quality high -w 1600 -h 1200 $N.kicad_pcb
echo "Done: fab/ and docs/"
