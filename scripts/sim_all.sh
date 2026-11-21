#!/usr/bin/env bash
# Alle Nachstellungen der Quest-Fuehrung parallel: Stufe-1-Starts 300 Schritte, sonst 80.
# Aufruf: bash scripts/sim_all.sh <shortest-path-forever-Ordner> [SIM_PLANNER=<anderer Planer>]
spf="${1:?Aufruf: bash scripts/sim_all.sh <spf>}"
cd "$(dirname "${BASH_SOURCE[0]}")/.."
keys=$(grep -o 'key = "[^"]*"' scripts/sim_leveling.lua | cut -d'"' -f2)
for k in $keys; do
  n=80; [[ $k == *-1 ]] && n=300
  ( lua5.1 scripts/sim_leveling.lua "$spf" "$k" "$n" | head -1 | cut -c1-260 > "${TMPDIR:-/tmp}/sim_$$_$k.txt" ) &
done
wait
for k in $keys; do cat "${TMPDIR:-/tmp}/sim_$$_$k.txt"; rm -f "${TMPDIR:-/tmp}/sim_$$_$k.txt"; done
