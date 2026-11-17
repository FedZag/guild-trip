#!/usr/bin/env python3
"""Erzeugt die eigenen Klaenge von Guild Trip (eigene Rechte, keine fremden Aufnahmen).

Synthese: kleine Handglocke = Grundton + unharmonische Obertoene mit eigener
Abklingzeit, weicher Anschlag. Ausgabe als OGG Vorbis (WoW spielt .ogg) nach
src/ONE_Core/Sounds/. Braucht numpy und ffmpeg (mit libvorbis).

  python3 -I scripts/build_sounds.py
"""
import pathlib
import subprocess
import tempfile
import wave

import numpy as np

RATE = 44100
ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / 'src' / 'ONE_Core' / 'Sounds'

# Obertoene einer kleinen Glocke: (Frequenzfaktor, Lautstaerke, Abklingzeit in s)
PARTIALS = [(1.0, 1.0, .9), (2.0, .45, .55), (2.76, .35, .35), (5.4, .18, .18), (8.93, .08, .1)]


def bell(freq, length, strength=1.0):
    t = np.arange(int(RATE * length)) / RATE
    tone = np.zeros_like(t)
    for factor, amp, decay in PARTIALS:
        tone += amp * np.sin(2 * np.pi * freq * factor * t) * np.exp(-t / decay)
    attack = np.minimum(1.0, t / .004)  # 4 ms weicher Anschlag, kein Knacken
    return strength * tone * attack


def mix(notes, length):
    """notes: (Startzeit s, Frequenz Hz, Staerke)"""
    out = np.zeros(int(RATE * length))
    for start, freq, strength in notes:
        part = bell(freq, length - start, strength)
        i = int(RATE * start)
        out[i:i + len(part)] += part
    fade = np.ones_like(out)
    n = int(RATE * .25)
    fade[-n:] = np.linspace(1, 0, n)  # sanft ausklingen
    out *= fade
    return out / np.max(np.abs(out)) * 10 ** (-4 / 20)  # Spitze -4 dB


def save(name, samples):
    OUT.mkdir(parents=True, exist_ok=True)
    pcm = (samples * 32767).astype('<i2')
    with tempfile.TemporaryDirectory() as tmp:
        wav = pathlib.Path(tmp) / 'klang.wav'
        with wave.open(str(wav), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(pcm.tobytes())
        target = OUT / name
        subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
                        '-c:a', 'libvorbis', '-q:a', '4', str(target)], check=True)
    print(f'{target.relative_to(ROOT)}  {len(samples) / RATE:.1f} s')


def soft(samples, peak_db):
    """leiser machen: Spitze auf peak_db (z. B. -14 dB)"""
    return samples / np.max(np.abs(samples)) * 10 ** (peak_db / 20)


def pluck(freq, length, decay=.12):
    """kurzes, weiches Zupfen (Holz/Glas): Grundton + eine Oktave, schnelles Abklingen"""
    t = np.arange(int(RATE * length)) / RATE
    tone = np.sin(2 * np.pi * freq * t) + .3 * np.sin(2 * np.pi * freq * 2 * t)
    return tone * np.exp(-t / decay) * np.minimum(1.0, t / .003)


E5, G5, B5, C5 = 659.25, 783.99, 987.77, 523.25
# Erkennungsklang: zwei Glockenschlaege abwaerts-aufwaerts (E5, dann H5)
save('Glocke.ogg', mix([(0, E5, 1.0), (.17, B5, .8)], 1.5))
# Gildenausflug beginnt: drei aufsteigende Schlaege (C5, E5, G5), der letzte klingt laenger
save('Ausflug.ogg', mix([(0, C5, .8), (.15, E5, .85), (.30, G5, 1.0)], 1.9))

# Chat (15.11.2026): drei dezente Klaenge, deutlich leiser und kuerzer als die Glocke
A5, E6, D6 = 880.0, 1318.5, 1174.7
# Fluestern: zwei sanfte, kurze Glockenschlaege (A5, dann E6), leise
save('ChatWhisper.ogg', soft(mix([(0, A5, .9), (.11, E6, .7)], .9), -12))
# Gilde/Gruppe: ein einzelnes leises "Pling"
save('ChatMessage.ogg', soft(pluck(D6, .35, .09), -18))
# Gesendet: winziges Tippen (tief, sehr kurz)
save('ChatSent.ogg', soft(pluck(C5 * 2, .12, .025), -22))
