#!/usr/bin/env bash
# Feste Routen der Quest-Fuehrung vorab rechnen -> src/ONE_Leveling/Routes.lua, je Volk x Klasse ab Stufe 1 bis 60.
# Seit 24.11.2026 als Gebiets-Schleife (Nutzer: "wir nehmen nur noch die quests in den gebieten an, bauen daraus eine
# zuverlaessige schleife …"): scripts/build_loop.lua – je Gebiet alle passenden Quests (auch Elite), Runde fuer Runde
# annehmen -> Ziele -> abgeben, kein Speed-Leveling mehr (vorher Planer-Nachstellung + scripts/route_opt.lua).
# Aufruf: bash scripts/build_routes.sh <shortest-path-forever-Ordner>
# Umgebung: JOBS=<n> (gleichzeitige Bauten, Standard 3 – Laptop-Hitze), OUT=<ordner> (Protokolle behalten),
#           NOWRITE=1 (nur rechnen + pruefen, Routes.lua nicht schreiben), ONLY="16:1 1:8" (nur diese Routen neu,
#           die uebrigen aus OUT behalten)
spf="${1:?Aufruf: bash scripts/build_routes.sh <spf> [schritte]}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
out="${OUT:-${TMPDIR:-/tmp}/routes_loop_$$}"
jobs_max="${JOBS:-3}"
mkdir -p "$out"
for key in ${ONLY:-}; do sed -i "/^$key /d" "$out/summary.txt" 2>/dev/null; done
# Volk (Maske) Fraktion Start (Karte x y) Heimat (Karte x y) Klassen – alle Paare, die Forever erlaubt
# (wago.tools CharBaseInfo, Build 1.60.1.70959: dazu Mensch-Jaeger, Orc-Magier, Zwerg-Schamane, Untoter-Paladin,
# Gnom-Priester, Troll-Hexenmeister; die Forever-Voelker "Skyborne" 95/96 haben noch keine Route)
starts=(
  "Undead 16 Horde 1420 .303 .713 1420 .612 .526 WARRIOR ROGUE PRIEST MAGE WARLOCK PALADIN"
  "Orc 2 Horde 1411 .436 .689 1411 .519 .416 WARRIOR HUNTER ROGUE SHAMAN WARLOCK MAGE"
  "Troll 128 Horde 1411 .436 .689 1411 .519 .416 WARRIOR HUNTER ROGUE PRIEST SHAMAN MAGE WARLOCK"
  "Tauren 32 Horde 1412 .449 .772 1412 .469 .602 WARRIOR HUNTER SHAMAN DRUID"
  "Human 1 Alliance 1429 .484 .418 1429 .437 .658 WARRIOR PALADIN ROGUE PRIEST MAGE WARLOCK HUNTER"
  "Dwarf 4 Alliance 1426 .297 .717 1426 .474 .524 WARRIOR PALADIN HUNTER ROGUE PRIEST SHAMAN"
  "Gnome 64 Alliance 1426 .297 .717 1426 .474 .524 WARRIOR ROGUE MAGE WARLOCK PRIEST"
  "NightElf 8 Alliance 1438 .587 .424 1438 .556 .598 WARRIOR HUNTER ROGUE PRIEST DRUID"
)
declare -A CMASK=([WARRIOR]=1 [PALADIN]=2 [HUNTER]=4 [ROGUE]=8 [PRIEST]=16 [SHAMAN]=64 [MAGE]=128 [WARLOCK]=256 [DRUID]=1024)
for line in "${starts[@]}"; do
  set -- $line
  race=$1 rmask=$2 fac=$3 m=$4 x=$5 y=$6 hm=$7 hx=$8 hy=$9; shift 9
  for cls in "$@"; do
    key="$rmask:${CMASK[$cls]}"
    [[ -n "${ONLY:-}" && " $ONLY " != *" $key "* ]] && continue
    while (( $(jobs -rp | wc -l) >= jobs_max )); do wait -n; done
    ( nice -n 19 lua5.1 scripts/build_loop.lua "$spf" "$fac,$race,$cls,$m,$x,$y,$hm,$hx,$hy" "$out/$key.lua" > "$out/$key.log" 2>&1
      echo "$key $race $cls: $(grep ERGEBNIS "$out/$key.log" | cut -c1-200)" | tee -a "$out/summary.txt" ) &
  done
done
wait
dest=src/ONE_Leveling/Routes.lua
built="$out/Routes.lua"
{
  echo "-- Guild Trip Quest-Fuehrung: feste Routen je Volk:Klasse (Masken), Gebiets-Schleife – ERZEUGT von scripts/build_routes.sh, nicht von Hand aendern."
  echo "-- Je Schritt: {\"a12 t13 o14\" (annehmen/Ziel/abgeben; o14.2 = Teil 2 der Ziele, p = Ziel-Knoten), n = NPC/Ziel, l = erwartete Stufe, r = Beginn Runde Nr.} oder {k = \"bind\"|\"grind\"|\"fp\"|\"dungeon\", …}."
  echo "-- Gebaut mit scripts/build_loop.lua (je Gebiet alle Quests, Runde fuer Runde), harte Pruefung scripts/check_route_areas.lua; im Spiel wird nur noch gefolgt."
  echo "GuildTripQuestRoutes = GuildTripQuestRoutes or {}"
  echo "local R = GuildTripQuestRoutes"
  for f in "$out"/*:*.lua; do
    key=$(basename "$f" .lua)
    echo "R[\"$key\"] = "
    sed '1s/^return //' "$f"
  done
} > "$built"
# Bau-Rechnung: Hauen (soll 0 sein) und Routen unter 60
awk '{for(i=1;i<=NF;i++){if($i=="Hauen"){h+=$(i+1)} if($i=="St" && $(i+1)+0<60) low++}} END{printf "Hauen-Schritte gesamt %d (%d Routen unter 60)\n", h, low}' "$out/summary.txt" | tee "$out/zeit.txt"
# harte Pruefung: bricht eine Route sie, wird nicht ausgeliefert
if ! lua5.1 scripts/check_route_areas.lua "$spf" "$built" --hart > "$out/pruefung.txt"; then
  tail -20 "$out/pruefung.txt"
  echo "NICHT ausgeliefert: harte Pruefung (Protokolle in $out)" >&2
  exit 1
fi
tail -2 "$out/pruefung.txt"
if [[ -z "${NOWRITE:-}" ]]; then cp "$built" "$dest"; echo "geschrieben: $dest ($(wc -c < "$dest") Bytes)"; else echo "nur gerechnet: $built"; fi
