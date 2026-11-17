#!/usr/bin/env bash
# Usage: bash scripts/install-forever.sh [optional path to the _forever_ folder]
set -euo pipefail
project="$(cd "$(dirname "$0")/.." && pwd)"
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
echo "Fertig. Forever starten; /trip, /trip diag und /trip navdiag testen. Sicherung: $backup"
