#!/usr/bin/env bash
# Usage: bash scripts/install-forever.sh [optional path to the _forever_ folder]
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
# Laeuft WoW, wird trotzdem installiert (Nutzer 21.11.2026): Code (.lua/.xml) liest WoW bei /reload neu.
# Neue Dateien, geaenderte Bilder/Toene und .toc-Aenderungen sieht WoW erst nach einem kompletten
# Neustart – dann meldet das Skript "NEUSTART NOETIG" mit den Gruenden. Jedes Addon wird erst fertig
# daneben kopiert und dann in einem Schritt getauscht (kein halber Ordner). Einstellungen (WTF) bleiben
# unberuehrt. Nicht waehrend des Kopierens /reload druecken – erst nach "Fertig".
running=0
if [[ -n "${GT_WOW_RUNNING:-}" ]]; then running="$GT_WOW_RUNNING"
elif ps -eo cmd | grep -qi "[w]ow.exe"; then running=1; fi
forever="${1:-$HOME/.local/share/Steam/steamapps/compatdata/3370188812/pfx/drive_c/Program Files (x86)/World of Warcraft/_forever_}"
if [[ "$(basename "$forever")" != "_forever_" || ! -d "$forever/Interface" ]]; then
  echo 'STOP: Der angegebene Ordner ist keine geprüfte _forever_-Installation.' >&2
  exit 2
fi
for addon in ONE_Core ONE_Guild ONE_Nav ONE_Dungeons ONE_Crafting ONE_Classes ONE_Chat ONE_QuestDB ONE_Routes ONE_Leveling ONE_Dev; do
  toc="$project/src/$addon/$addon.toc"
  if [[ ! -f "$toc" ]] || ! grep -qx '## Interface: 16001' "$toc"; then
    echo "STOP: $addon ist nicht für Forever 16001 vorbereitet." >&2
    exit 3
  fi
done
addons="$forever/Interface/AddOns"
mkdir -p "$addons"
# Was braucht einen Neustart? (neue Datei, geaenderte Nicht-Code-Datei, neues Addon)
restart=()
for addon in ONE_Core ONE_Guild ONE_Nav ONE_Dungeons ONE_Crafting ONE_Classes ONE_Chat ONE_QuestDB ONE_Routes ONE_Leveling ONE_Dev; do
  src="$project/src/$addon"
  dst="$addons/$addon"
  if [[ ! -d "$dst" ]]; then restart+=("neues Addon: $addon"); continue; fi
  while IFS= read -r -d '' f; do
    rel="${f#"$src"/}"
    if [[ ! -f "$dst/$rel" ]]; then
      restart+=("neue Datei: $addon/$rel")
    elif ! cmp -s "$f" "$dst/$rel"; then
      case "$rel" in
        *.lua|*.xml) ;;
        *) restart+=("geändert: $addon/$rel") ;;
      esac
    fi
  done < <(find "$src" -type f -print0)
done
backup="$project/backups/forever-guild-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$backup"
for addon in ONE_Core ONE_Guild ONE_Nav ONE_Dungeons ONE_Crafting ONE_Classes ONE_Chat ONE_QuestDB ONE_Routes ONE_Leveling ONE_Dev; do
  target="$addons/$addon"
  if [[ -L "$target" ]]; then
    echo "STOP: $target ist ein Symlink. Bitte manuell prüfen." >&2
    exit 4
  fi
  candidate="$addons/.${addon}.ONE-incoming"
  rm -rf "$candidate"
  cp -a "$project/src/$addon" "$candidate"
  test -f "$candidate/$addon.toc"
  if [[ -e "$target" ]]; then
    cp -a "$target" "$backup/$addon"
    rm -rf "$target"
  fi
  mv "$candidate" "$target"
  echo "Installiert: $target"
done
echo "Sicherung: $backup"
if (( ${#restart[@]} > 0 )); then
  echo "NEUSTART NÖTIG – /reload reicht nicht, WoW einmal ganz beenden und neu starten. Grund:"
  for r in "${restart[@]:0:12}"; do echo "  - $r"; done
  (( ${#restart[@]} > 12 )) && echo "  … und $(( ${#restart[@]} - 12 )) weitere"
elif [[ "$running" == 1 ]]; then
  echo "Fertig. WoW läuft: jetzt im Spiel /reload eingeben."
else
  echo "Fertig. Forever starten; /trip, /trip diag und /trip navdiag testen."
fi
