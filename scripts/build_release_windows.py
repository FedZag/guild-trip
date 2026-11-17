"""Baut ein weitergebbares ZIP fuer Windows-Tester (WoW Forever).
Inhalt: ONE_Core, ONE_Guild, ONE_Nav als oberste Ordner + Anleitung (CRLF, UTF-8 mit BOM).
Nur Dateien, die laut TOC geladen werden, plus Texturen. Alte, ungeladene
Navigationsdateien in ONE_Guild werden weggelassen.
Aufruf: python3 scripts/build_release_windows.py [Zielordner]
        python3 scripts/build_release_windows.py --curseforge [Zielordner]
--curseforge: nur die fuenf Addon-Ordner (mit LICENSE.txt), ohne Anleitung –
die CurseForge-App entpackt das ZIP direkt in den AddOns-Ordner.
"""
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'src'
ADDONS = ['ONE_Core', 'ONE_Guild', 'ONE_Nav', 'ONE_Dungeons', 'ONE_Crafting', 'ONE_Classes', 'ONE_Chat', 'ONE_QuestDB', 'ONE_Routes', 'ONE_Leveling']

version = re.search(r'ONE\.version = "([^"]+)"', (SRC / 'ONE_Core' / 'Core.lua').read_text()).group(1)
args = [a for a in sys.argv[1:] if a != '--curseforge']
curseforge = '--curseforge' in sys.argv[1:]
target_dir = Path(args[0]) if args else ROOT / 'dist'
target_dir.mkdir(parents=True, exist_ok=True)
target = target_dir / (f'GuildTrip_{version}_CurseForge.zip' if curseforge else f'GuildTrip_{version}_Windows.zip')

files = []
for addon in ADDONS:
    folder = SRC / addon
    toc = (folder / f'{addon}.toc').read_text()
    assert '## Interface: 16001' in toc, f'{addon}: kein Forever-Interface'
    assert f'## Version: {version}' in toc, f'{addon}: Version passt nicht zu {version}'
    loaded = [line.strip() for line in toc.splitlines() if line.strip().endswith('.lua')]
    for name in loaded:
        path = folder / name
        assert path.is_file(), f'Fehlt laut TOC: {path}'
        files.append(path)
    files.append(folder / f'{addon}.toc')
    # Lizenztexte uebernommener Daten muessen mitgeliefert werden (z. B. MIT).
    files.extend(sorted(folder.glob('LICENSE*')))
    # Liste fremder Quellen (GPL: Namensnennung mitliefern)
    if (folder / 'THIRD_PARTY.md').is_file():
        files.append(folder / 'THIRD_PARTY.md')
    # Tastenbelegung (WoW laedt Bindings.xml selbst aus dem Addon-Ordner)
    if (folder / 'Bindings.xml').is_file():
        files.append(folder / 'Bindings.xml')
    assert (folder / 'LICENSE.txt').is_file(), f'{addon}: LICENSE.txt fehlt'
    files.extend(sorted(p for p in (folder / 'Textures').rglob('*.tga')) if (folder / 'Textures').is_dir() else [])
    # Eigene Klaenge (scripts/build_sounds.py, eigene Rechte)
    files.extend(sorted(p for p in (folder / 'Sounds').glob('*.ogg')) if (folder / 'Sounds').is_dir() else [])
    # Schriften (z. B. IM FELL English fuer das Buch-Aussehen) samt Lizenz (SIL OFL)
    if (folder / 'Fonts').is_dir():
        fonts = sorted((folder / 'Fonts').glob('*.ttf'))
        if fonts:
            assert (folder / 'Fonts' / 'OFL.txt').is_file(), f'{addon}: Schrift ohne Lizenz'
            files.extend(fonts)
            files.append(folder / 'Fonts' / 'OFL.txt')

# Anleitung nur fuers Tester-ZIP (docs/ liegt nicht im oeffentlichen Projekt, dort wird nur --curseforge gebaut)
guide_bytes = None
if not curseforge:
    guide = (ROOT / 'docs' / 'ANLEITUNG_WINDOWS.txt').read_text(encoding='utf-8').replace('{VERSION}', version)
    guide_bytes = '﻿'.encode('utf-8') + guide.replace('\r\n', '\n').replace('\n', '\r\n').encode('utf-8')

if target.exists():
    target.unlink()
with zipfile.ZipFile(target, 'w', zipfile.ZIP_DEFLATED) as z:
    if not curseforge:
        z.writestr('LIES_MICH_ZUERST.txt', guide_bytes)
    for path in files:
        z.write(path, path.relative_to(SRC).as_posix())

print(target)
print(f'{len(files)} Addon-Dateien, Version {version}')
