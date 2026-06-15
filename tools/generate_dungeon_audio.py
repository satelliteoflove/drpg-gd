#!/usr/bin/env python3
"""Procedurally synthesize the dungeon soundscape.

Generates per-theme ambient beds + music (looping OGG), a torch-crackle loop, a
roaming-enemy growl loop (mono, for 3D positional audio), and the core one-shot
SFX (footsteps, turn scuff, door creak, stairs, torch whoosh, low-torch warning,
secret chime, encounter sting) as WAV.

All license-clean (generated from numpy). Deterministic. Re-run any time:
    uv run --with numpy --with soundfile python tools/generate_dungeon_audio.py

Loops are written as OGG and flagged loopable at runtime by AudioManager; the
seam is crossfaded here so they tile without a click.
"""

import os
import numpy as np
import soundfile as sf
from scipy.signal import lfilter

SR = 44100
rng = np.random.default_rng(0xD0CE)

AMBIENT_DIR = "audio/ambient"
MUSIC_DIR = "audio/music"
SFX_DIR = "audio/sfx"


# --- synth toolkit ----------------------------------------------------------

def t_axis(dur):
    return np.linspace(0, dur, int(SR * dur), endpoint=False)


def sine(freq, dur, phase=0.0):
    return np.sin(2 * np.pi * freq * t_axis(dur) + phase)


def lfo(freq, dur, lo=0.0, hi=1.0, phase=0.0):
    s = 0.5 * (1 + np.sin(2 * np.pi * freq * t_axis(dur) + phase))
    return lo + (hi - lo) * s


def noise(dur):
    return rng.standard_normal(int(SR * dur))


def one_pole_lp(x, cutoff):
    # one-pole low-pass; cutoff in Hz. C-level IIR via lfilter.
    a = np.exp(-2 * np.pi * cutoff / SR)
    return lfilter([1 - a], [1, -a], x)


def lp_fast(x, alpha):
    # EMA low-pass, alpha in (0,1) (higher = brighter). C-level IIR.
    alpha = float(alpha)
    return lfilter([alpha], [1, -(1 - alpha)], x)


def adsr(n, a, d, s, r, sustain=0.6):
    a = max(1, int(a * SR)); d = max(1, int(d * SR)); r = max(1, int(r * SR))
    s = max(0, n - a - d - r)
    env = np.concatenate([
        np.linspace(0, 1, a),
        np.linspace(1, sustain, d),
        np.full(s, sustain),
        np.linspace(sustain, 0, r),
    ])
    if len(env) < n:
        env = np.concatenate([env, np.zeros(n - len(env))])
    return env[:n]


def tone(freq, dur, a=0.01, d=0.1, r=0.3, sustain=0.5, partials=(1.0,)):
    n = int(SR * dur)
    base = t_axis(dur)
    y = np.zeros(n)
    for k, amp in enumerate(partials, start=1):
        y += amp * np.sin(2 * np.pi * freq * k * base)
    y *= adsr(n, a, d, 0, r, sustain)
    return y


def echo(x, delay=0.22, taps=(0.45, 0.18, 0.07)):
    y = x.copy()
    for i, g in enumerate(taps, start=1):
        d = int(delay * i * SR)
        if d < len(x):
            y[d:] += g * x[:-d]
    return y


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    if m < 1e-9:
        return x
    return x * (peak / m)


def stereo(left, right):
    n = min(len(left), len(right))
    return np.stack([left[:n], right[:n]], axis=1)


def loopify(x, cf_sec=0.5):
    # Crossfade the tail into the head so the buffer tiles seamlessly.
    cf = int(cf_sec * SR)
    if x.ndim == 1:
        if len(x) <= 2 * cf:
            return x
        fin = np.linspace(0, 1, cf)
        head = x[-cf:] * (1 - fin) + x[:cf] * fin
        return np.concatenate([head, x[cf:len(x) - cf]])
    else:
        if len(x) <= 2 * cf:
            return x
        fin = np.linspace(0, 1, cf)[:, None]
        head = x[-cf:] * (1 - fin) + x[:cf] * fin
        return np.concatenate([head, x[cf:len(x) - cf]], axis=0)


# NOTE: do NOT write OGG/Vorbis here. libsndfile's Vorbis encoder stack-overflows
# (0xC00000FD) on longer buffers on this Windows build and leaves a truncated,
# zero-packet .ogg behind. Such a stub, once imported, makes Godot's Vorbis mixer
# spew "ran out of packets in stream" thousands of times/sec, which floods the
# editor's main-thread error pipeline and freezes the whole editor (and starves
# the godot-mcp bridge). Everything is written as WAV and looped at runtime.


def write_wav(path, data):
    data = np.nan_to_num(np.clip(data, -1.0, 1.0)).astype(np.float32)
    sf.write(path, data, SR, subtype="PCM_16")
    print("  wrote", path, f"({len(data)/SR:.2f}s)")


# --- ambient beds -----------------------------------------------------------

def drone(root, dur, detune=0.5, vib=0.12):
    base = t_axis(dur)
    v = 1 + 0.0015 * np.sin(2 * np.pi * vib * base)
    y = np.zeros(len(base))
    for mult, amp in [(1.0, 1.0), (1.5, 0.5), (2.0, 0.35), (3.0, 0.12)]:
        f = root * mult
        y += amp * np.sin(2 * np.pi * f * base * v)
        y += amp * 0.6 * np.sin(2 * np.pi * (f + detune) * base * v)
    y *= lfo(0.05, dur, 0.55, 1.0)
    return y


def wind(dur, cutoff_alpha, amp_lfo=0.07):
    w = lp_fast(noise(dur), cutoff_alpha)
    w *= lfo(amp_lfo, dur, 0.25, 1.0)
    return w


def drips(dur, rate, fmin=600, fmax=1300, decay=0.18):
    n = int(SR * dur)
    out = np.zeros(n)
    count = max(1, int(dur * rate))
    for _ in range(count):
        start = rng.integers(0, n - int(SR * 0.4))
        f0 = rng.uniform(fmin, fmax)
        dl = int(SR * rng.uniform(0.08, decay))
        bt = np.linspace(0, dl / SR, dl)
        pitch = f0 * np.exp(-6 * bt)
        ping = np.sin(2 * np.pi * pitch * bt) * np.exp(-22 * bt)
        out[start:start + dl] += ping * rng.uniform(0.3, 0.7)
    return out


def ambient_bed(root, dur, wind_alpha, drip_rate, drip_amt, rumble=0.0):
    # Mono (libsndfile's vorbis encoder is unstable writing stereo OGG on
    # Windows; the bed is non-positional so mono costs nothing).
    mix = 0.5 * drone(root, dur) + wind(dur, wind_alpha) * 0.6 + drips(dur, drip_rate) * drip_amt
    if rumble > 0:
        mix += lp_fast(noise(dur), 0.02) * rumble
    return loopify(norm(mix, 0.8), 0.8)


# --- music (sparse, tense) --------------------------------------------------

def music(root, dur, scale, tempo=44):
    n = int(SR * dur)
    base = t_axis(dur)
    pad = np.zeros(n)
    for mult, amp in [(1.0, 0.5), (1.5, 0.3), (2.0, 0.18)]:
        pad += amp * np.sin(2 * np.pi * root * mult * base)
    pad *= lfo(0.05, dur, 0.4, 0.8)

    melody = np.zeros(n)
    beat = 60.0 / tempo
    t = 1.0
    while t < dur - 2.0:
        if rng.random() < 0.7:
            deg = scale[rng.integers(0, len(scale))]
            freq = root * 2 * (2 ** (deg / 12.0))
            nd = rng.uniform(0.6, 1.6)
            note = tone(freq, nd, a=0.04, d=0.2, r=nd * 0.6, sustain=0.5,
                        partials=(1.0, 0.3, 0.12))
            start = int(t * SR)
            end = min(n, start + len(note))
            melody[start:end] += note[:end - start] * rng.uniform(0.3, 0.55)
        t += beat * rng.choice([1, 1, 2, 2, 3])

    melody = echo(melody, 0.33, (0.4, 0.2, 0.1))
    mix = 0.7 * pad + 0.9 * melody
    return loopify(norm(mix * 0.9, 0.62), 1.0)


# --- one-shot SFX -----------------------------------------------------------

def footstep(pitch=1.0, length=0.16):
    n = int(SR * length)
    bt = np.linspace(0, length, n)
    thump = np.sin(2 * np.pi * 70 * pitch * bt) * np.exp(-30 * bt)
    grit = lp_fast(noise(length), 0.25) * np.exp(-40 * bt) * 0.5
    scuff = lp_fast(noise(length), 0.6) * np.exp(-18 * bt) * 0.25
    return norm(thump + grit + scuff, 0.8)


def turn_scuff():
    length = 0.18
    n = int(SR * length)
    bt = np.linspace(0, length, n)
    s = lp_fast(noise(length), 0.5) * np.exp(-12 * bt) * (0.4 + 0.6 * bt / length)
    return norm(s, 0.5)


def door_creak():
    length = 0.9
    bt = t_axis(length)
    sweep = 180 + 90 * np.sin(2 * np.pi * 1.5 * bt) * np.exp(-1.5 * bt)
    body = np.sin(2 * np.pi * np.cumsum(sweep) / SR)
    body *= (lp_fast(np.abs(noise(length)), 0.02))  # rough amplitude
    body *= np.exp(-1.2 * bt)
    thud = np.sin(2 * np.pi * 60 * bt[:int(SR * 0.15)]) * np.exp(-25 * bt[:int(SR * 0.15)])
    out = body * 0.7
    out[:len(thud)] += thud * 0.5
    return norm(out, 0.75)


def stairs():
    out = np.zeros(int(SR * 0.9))
    pos = 0.0
    for i in range(4):
        st = footstep(pitch=1.0 - i * 0.06, length=0.16)
        start = int(pos * SR)
        end = min(len(out), start + len(st))
        out[start:end] += st[:end - start] * 0.8
        pos += 0.2
    return norm(out, 0.8)


def torch_whoosh():
    length = 0.45
    bt = t_axis(length)
    env = np.exp(-6 * bt) * (1 - np.exp(-60 * bt))
    air = lp_fast(noise(length), 0.35)
    return norm(air * env, 0.7)


def torch_low_warn():
    # a soft sputter: two short filtered-noise puffs
    out = np.zeros(int(SR * 0.5))
    for k, start in enumerate([0.0, 0.18]):
        seg_len = 0.12
        bt = t_axis(seg_len)
        puff = lp_fast(noise(seg_len), 0.2) * np.exp(-20 * bt)
        s = int(start * SR)
        out[s:s + len(puff)] += puff
    return norm(out, 0.5)


def secret_chime():
    out = np.zeros(int(SR * 1.2))
    for k, semi in enumerate([0, 7, 12]):
        f = 660 * (2 ** (semi / 12.0))
        note = tone(f, 0.9, a=0.005, d=0.3, r=0.6, sustain=0.3, partials=(1.0, 0.5, 0.25))
        start = int(k * 0.12 * SR)
        end = min(len(out), start + len(note))
        out[start:end] += note[:end - start] * (0.6 - k * 0.1)
    return norm(echo(out, 0.2, (0.3, 0.12)), 0.7)


def encounter_sting():
    length = 1.1
    bt = t_axis(length)
    swell = (1 - np.exp(-5 * bt)) * np.exp(-1.5 * bt)
    low = np.sin(2 * np.pi * 110 * bt) + np.sin(2 * np.pi * 116 * bt)  # dissonant beat
    low += 0.5 * np.sin(2 * np.pi * 55 * bt)
    hiss = lp_fast(noise(length), 0.5) * np.exp(-3 * bt) * 0.4
    return norm((low * 0.5 + hiss) * swell, 0.85)


def torch_loop():
    dur = 4.0
    bt = t_axis(dur)
    hiss = lp_fast(noise(dur), 0.4) * 0.18
    crackle = np.zeros(int(SR * dur))
    for _ in range(int(dur * 14)):
        s = rng.integers(0, len(crackle) - 400)
        dl = rng.integers(60, 350)
        pop = lp_fast(rng.standard_normal(dl), 0.5) * np.exp(-np.linspace(0, 8, dl)) * rng.uniform(0.3, 1.0)
        crackle[s:s + dl] += pop
    out = norm(hiss + crackle, 0.6)
    return loopify(out, 0.3)


def roamer_loop():
    dur = 3.5
    bt = t_axis(dur)
    growl = np.sin(2 * np.pi * 90 * bt + 3 * np.sin(2 * np.pi * 0.7 * bt))
    growl *= lfo(0.5, dur, 0.2, 1.0)
    rasp = lp_fast(noise(dur), 0.08) * 0.5
    rasp *= lfo(0.8, dur, 0.1, 0.8)
    out = norm(growl * 0.5 + rasp, 0.55)
    return loopify(out, 0.4)


# --- main -------------------------------------------------------------------

def main():
    for d in (AMBIENT_DIR, MUSIC_DIR, SFX_DIR):
        os.makedirs(d, exist_ok=True)

    minor = [0, 2, 3, 5, 7, 8, 10]

    # NOTE: everything is WAV — libsndfile's OGG/Vorbis encoder stack-overflows
    # on longer buffers on this Windows build. Loops are flagged loopable at
    # runtime by AudioManager (AudioStreamWAV.loop_mode).
    print("Ambient beds:")
    write_wav(f"{AMBIENT_DIR}/ambient_catacombs.wav",
              ambient_bed(55.0, 18, 0.06, 0.6, 0.6))
    write_wav(f"{AMBIENT_DIR}/ambient_caverns.wav",
              ambient_bed(49.0, 18, 0.12, 1.2, 0.9, rumble=0.1))
    write_wav(f"{AMBIENT_DIR}/ambient_crypt.wav",
              ambient_bed(41.0, 18, 0.04, 0.25, 0.4, rumble=0.22))

    print("Music:")
    write_wav(f"{MUSIC_DIR}/music_catacombs.wav", music(110.0, 24, minor, 46))
    write_wav(f"{MUSIC_DIR}/music_caverns.wav", music(98.0, 24, minor, 42))
    write_wav(f"{MUSIC_DIR}/music_crypt.wav", music(82.0, 26, minor, 38))

    print("Loops:")
    write_wav(f"{SFX_DIR}/torch_loop.wav", torch_loop())
    write_wav(f"{SFX_DIR}/roamer.wav", roamer_loop())

    print("One-shots:")
    write_wav(f"{SFX_DIR}/footstep_1.wav", footstep(1.0, 0.16))
    write_wav(f"{SFX_DIR}/footstep_2.wav", footstep(0.92, 0.15))
    write_wav(f"{SFX_DIR}/footstep_3.wav", footstep(1.08, 0.17))
    write_wav(f"{SFX_DIR}/turn.wav", turn_scuff())
    write_wav(f"{SFX_DIR}/door.wav", door_creak())
    write_wav(f"{SFX_DIR}/stairs.wav", stairs())
    write_wav(f"{SFX_DIR}/torch_light.wav", torch_whoosh())
    write_wav(f"{SFX_DIR}/torch_low.wav", torch_low_warn())
    write_wav(f"{SFX_DIR}/secret.wav", secret_chime())
    write_wav(f"{SFX_DIR}/encounter.wav", encounter_sting())

    print("Done.")


if __name__ == "__main__":
    main()
