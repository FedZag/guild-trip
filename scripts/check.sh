#!/usr/bin/env bash
# Project ONE: eine Pruefung fuer alles. Fuehrt JEDE Datei tests/*.lua aus.
# Aufruf: bash scripts/check.sh
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"
if grep -Eq '^(Navigation|RouteGraph|FlightPoints)\.lua$' src/ONE_Guild/ONE_Guild.toc; then
  echo 'FEHLER: Altes Navigationsmodul wird weiterhin geladen.' >&2
  exit 1
fi
runner=""
for candidate in lua5.1 luajit lua texlua; do
  if command -v "$candidate" >/dev/null 2>&1; then runner="$candidate"; break; fi
done
[[ -n "$runner" ]] || { echo 'FEHLER: kein Lua-Interpreter gefunden.' >&2; exit 2; }
failed=0
for test in tests/*.lua; do
  if out=$("$runner" "$test" src 2>&1); then
    printf 'OK    %s\n' "$test"
  else
    printf 'FEHLER %s\n%s\n' "$test" "$out" >&2
    failed=$((failed+1))
  fi
done
if (( failed > 0 )); then echo "$failed Test(s) fehlgeschlagen." >&2; exit 1; fi
printf 'OK: alle %d Prüfungen bestanden (%s)\n' "$(ls tests/*.lua | wc -l)" "$runner"
