#!/usr/bin/env bash
# Feste Routen der Quest-Fuehrung vorab rechnen (Neubau 21.11.2026, "wie RestedXP"): je Volk x Klasse ab Stufe 1 im
# Startgebiet bis 60, mit fester Gebietsfolge (SIM_FLOW), aufgezeichnet mit SIM_RECORD -> src/ONE_Leveling/Routes.lua
# Aufruf: bash scripts/build_routes.sh <shortest-path-forever-Ordner> [Schritte=3000]
# Umgebung: JOBS=<n> (gleichzeitige Nachstellungen, Standard 8 – Laptop-Hitze; je Route ~6 min mit Ueberarbeiten), OUT=<ordner> (Protokolle behalten),
#           NOWRITE=1 (nur rechnen + pruefen, Routes.lua nicht schreiben, z. B. fuer den Vorher-Vergleich)
# Eine Route, die schnellste (Nutzer 22.11.2026 "ich moechte weiterhin speed-leveln"): Schwelle "all" – im Vergleich
# need/balanced/all (22.11.) war sie am schnellsten und hatte die wenigsten Rueckwege
spf="${1:?Aufruf: bash scripts/build_routes.sh <spf> [schritte]}"
steps="${2:-3000}"
tempo=all
cd "$(dirname "${BASH_SOURCE[0]}")/.."
out="${OUT:-${TMPDIR:-/tmp}/routes_${tempo}_$$}"
jobs_max="${JOBS:-8}"
mkdir -p "$out"
# Volk (Maske) Fraktion Start (Karte x y) Heimat (Karte x y) Klassen
starts=(
  "Undead 16 Horde 1420 .303 .713 1420 .612 .526 WARRIOR ROGUE PRIEST MAGE WARLOCK"
  "Orc 2 Horde 1411 .436 .689 1411 .519 .416 WARRIOR HUNTER ROGUE SHAMAN WARLOCK"
  "Troll 128 Horde 1411 .436 .689 1411 .519 .416 WARRIOR HUNTER ROGUE PRIEST SHAMAN MAGE"
  "Tauren 32 Horde 1412 .449 .772 1412 .469 .602 WARRIOR HUNTER SHAMAN DRUID"
  "Human 1 Alliance 1429 .484 .418 1429 .437 .658 WARRIOR PALADIN ROGUE PRIEST MAGE WARLOCK"
  "Dwarf 4 Alliance 1426 .297 .717 1426 .474 .524 WARRIOR PALADIN HUNTER ROGUE PRIEST"
  "Gnome 64 Alliance 1426 .297 .717 1426 .474 .524 WARRIOR ROGUE MAGE WARLOCK"
  "NightElf 8 Alliance 1438 .587 .424 1438 .556 .598 WARRIOR HUNTER ROGUE PRIEST DRUID"
)
declare -A CMASK=([WARRIOR]=1 [PALADIN]=2 [HUNTER]=4 [ROGUE]=8 [PRIEST]=16 [SHAMAN]=64 [MAGE]=128 [WARLOCK]=256 [DRUID]=1024)
for line in "${starts[@]}"; do
  set -- $line
  race=$1 rmask=$2 fac=$3 m=$4 x=$5 y=$6 hm=$7 hx=$8 hy=$9; shift 9
  for cls in "$@"; do
    key="$rmask:${CMASK[$cls]}"
    while (( $(jobs -rp | wc -l) >= jobs_max )); do wait -n; done
    ( SIM_SCEN="$fac,$race,$cls,$m,$x,$y,$hm,$hx,$hy" SIM_TEMPO="$tempo" SIM_FLOW=1 SIM_NOKIPP=1 SIM_RECORD="$out/$key.lua" \
        nice -n 19 lua5.1 scripts/sim_leveling.lua "$spf" custom "$steps" > "$out/$key.log" 2>&1
      echo "$key $race $cls: $(tail -2 "$out/$key.log" | head -1 | cut -c1-200)" | tee -a "$out/summary.txt" ) &
  done
done
wait
dest=src/ONE_Leveling/Routes.lua
built="$out/Routes.lua"
{
  echo "-- Guild Trip Quest-Fuehrung: feste Routen je Volk:Klasse (Masken), die schnellste (Tempo $tempo) – ERZEUGT von scripts/build_routes.sh, nicht von Hand aendern."
  echo "-- Je Schritt: {\"a12 t13 o14\" (annehmen/Ziel/abgeben; o14.2 = Teil 2 der Ziele, p = Ziel-Knoten), n = NPC/Ziel, l = erwartete Stufe} oder {k = \"bind\"|\"grind\"|\"fp\", …}."
  echo "-- Gerechnet mit dem Planer (feste Gebietsfolge), danach als Ganzes ueberarbeitet (scripts/route_opt.lua), harte Pruefung scripts/check_route_areas.lua; im Spiel wird nur noch gefolgt."
  echo "GuildTripQuestRoutes = GuildTripQuestRoutes or {}"
  echo "local R = GuildTripQuestRoutes"
  for f in "$out"/*:*.lua; do
    key=$(basename "$f" .lua)
    echo "R[\"$key\"] = "
    sed '1s/^return //' "$f"
  done
} > "$built"
# Spielzeit bis 60 (Summe der Nachstellungen) – Vergleich vorher/nachher
awk '{for(i=1;i<=NF;i++){if($i=="bis60"){m+=$(i+1)} if($i~/^St$/){split($(i+1),a,"->"); if(a[2]<60) low++}}} END{printf "Spielzeit bis 60 gesamt %.0f min (%d Routen unter 60)\n", m, low}' "$out/summary.txt" | tee "$out/zeit.txt"
# harte Pruefung: bricht eine Route sie, wird nicht ausgeliefert
if ! lua5.1 scripts/check_route_areas.lua "$spf" "$built" --hart > "$out/pruefung.txt"; then
  tail -20 "$out/pruefung.txt"
  echo "NICHT ausgeliefert: harte Pruefung (Protokolle in $out)" >&2
  exit 1
fi
tail -2 "$out/pruefung.txt"
if [[ -z "${NOWRITE:-}" ]]; then cp "$built" "$dest"; echo "geschrieben: $dest ($(wc -c < "$dest") Bytes)"; else echo "nur gerechnet: $built"; fi
