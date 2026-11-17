#!/usr/bin/env python3
"""Laedt das fertige Paket auf CurseForge hoch (wird vom GitHub-Ablauf benutzt, geht auch von Hand).

  CF_API_TOKEN=… CF_PROJECT_ID=… python3 -I scripts/upload_curseforge.py [--dry-run]

* Version aus src/ONE_Core/Core.lua, Paket dist/GuildTrip_<version>_CurseForge.zip
  (vorher bauen: python3 -I scripts/build_release_windows.py --curseforge)
* Changelog: im Changelog (CHANGELOG.md bzw. docs/CHANGELOG_CURSEFORGE.md) der erste Code-Block
  unter der Ueberschrift "## <version>"
* Spielversion: CF_GAME_VERSION (Vorgabe 1.60.1), per Name in der CurseForge-Liste gesucht
* Art: CF_RELEASE_TYPE (release | beta | alpha, Vorgabe release)
* Abhaengigkeiten (Shortest Path Forever) stehen auf CurseForge als "Default Relations".
--dry-run: alles pruefen und anzeigen, nichts senden (kein Schluessel noetig).
--check: nur Schluessel und Spielversion bei CurseForge pruefen (nichts hochladen).
Der Schluessel steht nur in der Umgebung (GitHub-Secret), nie im Code oder im Log.
"""
import json
import os
import re
import sys
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = 'https://wow.curseforge.com/api'


def fail(msg):
    print('FEHLER: ' + msg, file=sys.stderr)
    sys.exit(1)


def version():
    core = (ROOT / 'src' / 'ONE_Core' / 'Core.lua').read_text(encoding='utf-8')
    return re.search(r'ONE\.version = "([^"]+)"', core).group(1)


def changelog(ver):
    for name in ('CHANGELOG.md', 'docs/CHANGELOG_CURSEFORGE.md'):
        path = ROOT / name
        if path.is_file():
            text = path.read_text(encoding='utf-8')
            head = re.search(r'^## ' + re.escape(ver) + r'\b.*$', text, re.M)
            if not head:
                continue
            block = re.search(r'```[a-z]*\n(.*?)```', text[head.end():], re.S)
            if block:
                return block.group(1).strip()
    fail(f'kein Changelog-Abschnitt "## {ver}" mit Code-Block gefunden')


def request(url, token, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=dict(headers or {}, **{'X-Api-Token': token}))
    with urllib.request.urlopen(req, timeout=120) as r:
        return json.loads(r.read().decode('utf-8') or 'null')


def game_version_id(token, wanted):
    found = [v for v in request(API + '/game/versions', token) if v.get('name') == wanted]
    if not found:
        fail(f'Spielversion "{wanted}" gibt es auf CurseForge nicht')
    type_id = os.environ.get('CF_GAME_VERSION_TYPE')
    if type_id:
        found = [v for v in found if str(v.get('gameVersionTypeID')) == type_id]
    if len(found) != 1:
        fail('Spielversion nicht eindeutig: ' + ', '.join(f"{v['id']} (Typ {v.get('gameVersionTypeID')})" for v in found)
             + ' – CF_GAME_VERSION_TYPE setzen')
    return found[0]['id']


def multipart(fields, file_field, file_path):
    boundary = uuid.uuid4().hex
    parts = []
    for key, value in fields.items():
        parts.append(f'--{boundary}\r\nContent-Disposition: form-data; name="{key}"\r\n\r\n{value}\r\n'.encode('utf-8'))
    parts.append((f'--{boundary}\r\nContent-Disposition: form-data; name="{file_field}"; filename="{file_path.name}"\r\n'
                  'Content-Type: application/zip\r\n\r\n').encode('utf-8'))
    parts.append(file_path.read_bytes())
    parts.append(f'\r\n--{boundary}--\r\n'.encode('utf-8'))
    return b''.join(parts), f'multipart/form-data; boundary={boundary}'


def main():
    dry = '--dry-run' in sys.argv[1:]
    if '--check' in sys.argv[1:]:
        # Nur Verbindung + Schluessel + Spielversion pruefen, nichts hochladen
        token = os.environ.get('CF_API_TOKEN')
        if not token:
            fail('CF_API_TOKEN fehlt')
        wanted = os.environ.get('CF_GAME_VERSION', '1.60.1')
        print(f'Verbindung ok, Spielversion {wanted} = ID {game_version_id(token, wanted)}, Projekt {os.environ.get("CF_PROJECT_ID")}')
        return
    ver = version()
    zip_path = ROOT / 'dist' / f'GuildTrip_{ver}_CurseForge.zip'
    if not zip_path.is_file():
        fail(f'{zip_path.relative_to(ROOT)} fehlt – erst bauen')
    notes = changelog(ver)
    release_type = os.environ.get('CF_RELEASE_TYPE', 'release')
    if release_type not in ('release', 'beta', 'alpha'):
        fail('CF_RELEASE_TYPE muss release, beta oder alpha sein')
    wanted = os.environ.get('CF_GAME_VERSION', '1.60.1')
    print(f'Guild Trip {ver} · {zip_path.name} ({zip_path.stat().st_size // 1024} KB) · {release_type} · Spiel {wanted}')
    print(f'Changelog: {len(notes)} Zeichen, beginnt mit: {notes.splitlines()[0][:60]!r}')
    if dry:
        print('Probelauf – nichts gesendet.')
        return
    token, project = os.environ.get('CF_API_TOKEN'), os.environ.get('CF_PROJECT_ID')
    if not token or not project:
        fail('CF_API_TOKEN und CF_PROJECT_ID muessen gesetzt sein')
    metadata = {'changelog': notes, 'changelogType': 'markdown', 'displayName': f'Guild Trip {ver}',
                'gameVersions': [game_version_id(token, wanted)], 'releaseType': release_type}
    body, ctype = multipart({'metadata': json.dumps(metadata)}, 'file', zip_path)
    result = request(f'{API}/projects/{project}/upload-file', token, data=body, headers={'Content-Type': ctype})
    print(f'Hochgeladen: Datei-ID {result.get("id")}')


if __name__ == '__main__':
    main()
