"""Generate subtle, tasteful UI sound effects as 16-bit PCM WAV files.

Soft sine/triangle tones with gentle envelopes - intentionally quiet and
unobtrusive. Output: audio/ui/*.wav
"""
import math
import os
import struct
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "audio", "ui")
os.makedirs(OUT, exist_ok=True)


def env(n, attack=0.005, release=0.12):
    """ADSR-ish envelope: fast attack, exponential-ish release."""
    e = np.ones(n)
    a = int(SR * attack)
    r = int(SR * release)
    if a > 0:
        e[:a] = np.linspace(0.0, 1.0, a)
    if r > 0:
        e[-r:] = np.linspace(1.0, 0.0, r) ** 1.8
    return e


def tone(freq, dur, kind="sine", detune=0.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    if kind == "sine":
        w = np.sin(2 * math.pi * freq * t)
    elif kind == "tri":
        w = 2.0 / math.pi * np.arcsin(np.sin(2 * math.pi * freq * t))
    else:
        w = np.sin(2 * math.pi * freq * t)
    if detune:
        w = 0.6 * w + 0.4 * np.sin(2 * math.pi * (freq * (1 + detune)) * t)
    return w


def soft_noise_tick(dur, freq, amp):
    n = int(SR * dur)
    t = np.arange(n) / SR
    w = np.sin(2 * math.pi * freq * t) * np.exp(-t * 60.0)
    return w * amp


def save(name, sig, peak=0.32):
    sig = np.asarray(sig, dtype=np.float64)
    m = np.max(np.abs(sig)) or 1.0
    sig = sig / m * peak
    pcm = np.clip(sig * 32767.0, -32768, 32767).astype(np.int16)
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(SR)
        f.writeframes(pcm.tobytes())
    print("wrote", os.path.normpath(path), len(pcm), "samples")


# Navigate: a soft, short woody tick (low presence, quick decay)
nav = soft_noise_tick(0.06, 520, 1.0) + 0.5 * soft_noise_tick(0.06, 780, 1.0)
save("nav.wav", nav, peak=0.22)

# Hover: even softer, higher, barely-there
hover = soft_noise_tick(0.045, 900, 1.0)
save("hover.wav", hover, peak=0.13)

# Confirm: gentle rising two-note chime (C5 -> G5), warm
c5, g5 = 523.25, 783.99
n1 = tone(c5, 0.10, "sine", 0.004) * env(int(SR * 0.10), 0.004, 0.09)
n2 = tone(g5, 0.16, "sine", 0.004) * env(int(SR * 0.16), 0.004, 0.14)
confirm = np.concatenate([n1, np.zeros(int(SR * 0.02)), n2])
# add a soft octave shimmer
shimmer = tone(g5 * 2, len(confirm) / SR, "sine") * env(len(confirm), 0.02, 0.2) * 0.15
confirm = confirm + shimmer[: len(confirm)]
save("confirm.wav", confirm, peak=0.30)

# Back/cancel: soft descending two-note (G4 -> C4)
g4, c4 = 392.0, 261.63
b1 = tone(g4, 0.09, "sine") * env(int(SR * 0.09), 0.004, 0.08)
b2 = tone(c4, 0.14, "sine") * env(int(SR * 0.14), 0.004, 0.12)
back = np.concatenate([b1, np.zeros(int(SR * 0.015)), b2])
save("back.wav", back, peak=0.26)

# Denied: muted low double-thud
d = tone(146.83, 0.16, "tri") * env(int(SR * 0.16), 0.003, 0.14)
denied = np.concatenate([d[: int(SR * 0.06)], np.zeros(int(SR * 0.01)), d])
save("denied.wav", denied, peak=0.24)

print("done")
