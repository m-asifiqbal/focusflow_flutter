#!/usr/bin/env python3
"""Generates FocusFlow's reminder sounds (no third-party audio, no licences).

Writes four short, soft notification tones as 16-bit mono 44.1 kHz WAV:

  chime   two-tone bell (E6 -> B5), the default reminder sound
  bell    single struck bell with inharmonic partials
  gentle  slow-attack major third, quiet
  pulse   three short pulses

to
  android/app/src/main/res/raw/<name>.wav   (Android: RawResourceAndroidNotificationSound)
  assets/sounds/<name>.wav                  (iOS: copied to Library/Sounds at start-up)

Pure standard library (wave + math + struct); deterministic output, so
re-running it produces identical files. Run from the project root:

    python3 tool/sounds/generate_sounds.py
"""

import math
import os
import struct
import wave

RATE = 44100
ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
OUT_DIRS = [
    os.path.join(ROOT, 'android', 'app', 'src', 'main', 'res', 'raw'),
    os.path.join(ROOT, 'assets', 'sounds'),
]


def bell_partial(t, freq, decay, amp):
    """One exponentially decaying sine partial."""
    return amp * math.exp(-t * decay) * math.sin(2 * math.pi * freq * t)


def envelope(t, attack):
    """Short linear attack (no click at the start)."""
    return min(1.0, t / attack) if attack > 0 else 1.0


def strike(t, start, freq, decay=5.0, attack=0.004):
    """A bell-like note struck at `start` seconds (0 before it)."""
    if t < start:
        return 0.0
    u = t - start
    e = envelope(u, attack)
    return e * (
        bell_partial(u, freq, decay, 1.0)
        + bell_partial(u, freq * 2.0, decay * 1.6, 0.35)
        + bell_partial(u, freq * 3.01, decay * 2.4, 0.12)
    )


def chime(t):
    return 0.55 * strike(t, 0.0, 1318.5) + 0.55 * strike(t, 0.22, 987.8)


def bell(t):
    e = envelope(t, 0.003)
    return e * 0.45 * (
        bell_partial(t, 880.0, 3.2, 1.0)
        + bell_partial(t, 880.0 * 2.76, 5.0, 0.45)
        + bell_partial(t, 880.0 * 5.40, 8.0, 0.2)
        + bell_partial(t, 880.0 * 0.5, 2.5, 0.25)
    )


def gentle(t):
    e = envelope(t, 0.18)
    return e * 0.4 * (
        bell_partial(t, 659.3, 2.4, 1.0) + bell_partial(t, 830.6, 2.4, 0.8)
    )


def pulse(t):
    total = 0.0
    for i in range(3):
        total += 0.5 * strike(t, i * 0.18, 1046.5, decay=14.0, attack=0.003)
    return total


SOUNDS = {
    'chime': (chime, 1.4),
    'bell': (bell, 1.6),
    'gentle': (gentle, 1.6),
    'pulse': (pulse, 0.9),
}


def render(fn, seconds):
    n = int(RATE * seconds)
    fade = int(RATE * 0.05)  # 50 ms fade-out: no click at the end
    frames = bytearray()
    for i in range(n):
        v = fn(i / RATE)
        if i > n - fade:
            v *= (n - i) / fade
        v = max(-1.0, min(1.0, v))
        frames += struct.pack('<h', int(v * 32767 * 0.8))
    return bytes(frames)


def main():
    for name, (fn, seconds) in SOUNDS.items():
        data = render(fn, seconds)
        for d in OUT_DIRS:
            os.makedirs(d, exist_ok=True)
            path = os.path.join(d, name + '.wav')
            with wave.open(path, 'wb') as w:
                w.setnchannels(1)
                w.setsampwidth(2)
                w.setframerate(RATE)
                w.writeframes(data)
            print('wrote', os.path.relpath(path, ROOT), len(data) + 44, 'bytes')


if __name__ == '__main__':
    main()
