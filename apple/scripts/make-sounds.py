#!/usr/bin/env python3
"""Generate Lauder's combat sounds (ADR 0008, ADR 0021) as 16-bit mono WAV files, using only the
standard library.

Each sound is built from simple parts: filtered noise for a shot's crack and body, a falling tone
for its boom, a quiet tail and an echo off the buildings. Each of the six paired weapons has its
own voice, with the minigun's spin-up and the shield dome's changes beside them. They stand in
until recordings replace them under the same names. Run from the repository root:

    python3 apple/scripts/make-sounds.py            # write the files
    python3 apple/scripts/make-sounds.py --check    # confirm the committed files match
"""

import argparse
import math
import random
import struct
import sys
import wave
from pathlib import Path

RATE = 44100
OUTPUT = Path("apple/sources/content/sounds")
# Another platform's maths may round a sample a step differently; anything more is a change.
TOLERANCE = 2


def samples(seconds):
    return int(seconds * RATE)


def noise(rng, length):
    return [rng.uniform(-1.0, 1.0) for _ in range(length)]


def low_pass(signal, cutoff):
    """A gentle one-pole low-pass filter."""
    share = 1 - math.exp(-2 * math.pi * cutoff / RATE)
    out, level = [], 0.0
    for value in signal:
        level += share * (value - level)
        out.append(level)
    return out


def high_pass(signal, cutoff):
    return [value - low for value, low in zip(signal, low_pass(signal, cutoff))]


def envelope(length, decay, attack=0.001, start=0.0):
    """A quick rise from silence at `start` seconds, then an exponential decay."""
    out = []
    for index in range(length):
        time = index / RATE - start
        if time < 0:
            out.append(0.0)
            continue
        rise = min(1.0, time / attack) if attack > 0 else 1.0
        out.append(rise * math.exp(-time / decay))
    return out


def tone(length, start_hz, end_hz, glide):
    """A sine falling from `start_hz` towards `end_hz`, a third of the way in `glide` seconds."""
    out, phase = [], 0.0
    for index in range(length):
        frequency = end_hz + (start_hz - end_hz) * math.exp(-index / RATE / glide)
        phase += 2 * math.pi * frequency / RATE
        out.append(math.sin(phase))
    return out


def shaped(signal, curve):
    return [value * level for value, level in zip(signal, curve)]


def mix(*parts):
    """The sum of (signal, gain) pairs, as long as the longest."""
    out = [0.0] * max(len(signal) for signal, _ in parts)
    for signal, gain in parts:
        for index, value in enumerate(signal):
            out[index] += value * gain
    return out


def echo(signal, seconds, gain, length):
    """A later, quieter, duller copy, as off a wall across the street."""
    delayed = [0.0] * samples(seconds) + [value * gain for value in signal]
    return low_pass(delayed, 1500)[:length]


def finish(signal, drive, peak):
    """Softly clipped for punch, scaled to `peak` and faded out at the end."""
    out = [math.tanh(drive * value) for value in signal]
    top = max(abs(value) for value in out) or 1.0
    out = [value / top * peak for value in out]
    fade = samples(0.01)
    for index in range(fade):
        out[-1 - index] *= index / fade
    return out


def gunshot(rng, seconds, crack, body, boom, tail, delay):
    """A shot: a sharp crack, the body of the blast, a falling boom, a tail and an echo.

    `crack` and `body` are (cutoff in hertz, decay in seconds); `boom` is (start hertz, end hertz,
    glide, decay, gain); `tail` is (decay, gain); `delay` is the echo's (seconds, gain).
    """
    length = samples(seconds)
    sharp = shaped(high_pass(noise(rng, length), crack[0]), envelope(length, crack[1], 0.0002))
    blast = shaped(low_pass(noise(rng, length), body[0]), envelope(length, body[1], 0.0005))
    low = shaped(tone(length, boom[0], boom[1], boom[2]), envelope(length, boom[3]))
    rest = shaped(low_pass(noise(rng, length), 900), envelope(length, tail[0], 0.02, 0.01))
    shot = mix((sharp, 1.0), (blast, 0.8), (low, boom[4]), (rest, tail[1]))
    return mix((shot, 1.0), (echo(shot, delay[0], delay[1], length), 1.0))


def bell(length, peak, width):
    """A smooth swell and fade, highest at `peak` seconds, about `width` seconds either side."""
    return [math.exp(-(((index / RATE) - peak) / width) ** 2) for index in range(length)]


def shimmer(length, start_hz, end_hz, glide):
    """Two slightly detuned tones gliding from `start_hz` to `end_hz` over `glide` seconds,
    easing in: the sound of Tom's dome."""
    out, first, second = [], 0.0, 0.0
    for index in range(length):
        progress = min(1.0, index / RATE / glide)
        frequency = start_hz + (end_hz - start_hz) * (1 - (1 - progress) ** 2)
        first += 2 * math.pi * frequency / RATE
        second += 2 * math.pi * frequency * 1.007 / RATE
        out.append(math.sin(first) + math.sin(second) + 0.3 * math.sin(2 * first))
    return out


def long_rifle(rng):
    """Miki's long rifle: a hard crack, a deep boom and a long echo down the span."""
    shot = gunshot(
        rng, 1.1, crack=(2000, 0.005), body=(2400, 0.045), boom=(85, 40, 0.07, 0.11, 0.85),
        tail=(0.32, 0.26), delay=(0.17, 0.32))
    return finish(shot, drive=1.9, peak=0.95)


def assault_rifle(rng):
    """One round of Miki's assault rifle: short and punchy, for ten rounds a second."""
    shot = gunshot(
        rng, 0.42, crack=(2200, 0.0035), body=(3200, 0.02), boom=(140, 70, 0.03, 0.035, 0.5),
        tail=(0.09, 0.14), delay=(0.08, 0.16))
    return finish(shot, drive=1.5, peak=0.78)


def shotgun(rng):
    """Laura's shotgun: a heavy, deep blast with the hiss of its spreading pellets."""
    length = samples(1.0)
    shot = gunshot(
        rng, 1.0, crack=(1000, 0.01), body=(1600, 0.07), boom=(72, 34, 0.09, 0.12, 1.0),
        tail=(0.3, 0.3), delay=(0.14, 0.3))
    spray = shaped(
        high_pass(low_pass(noise(rng, length), 6000), 2000), envelope(length, 0.05, 0.001, 0.004))
    return finish(mix((shot, 1.0), (spray, 0.35)), drive=2.0, peak=0.95)


def minigun(rng):
    """One round of Tom's minigun: a tiny, buzzing shot that blurs into a roar at full rate."""
    length = samples(0.16)
    sharp = shaped(high_pass(noise(rng, length), 2600), envelope(length, 0.003, 0.0002))
    blast = shaped(low_pass(noise(rng, length), 3800), envelope(length, 0.014, 0.0004))
    low = shaped(tone(length, 180, 100, 0.02), envelope(length, 0.022))
    return finish(mix((sharp, 1.0), (blast, 0.8), (low, 0.35)), drive=1.3, peak=0.6)


def minigun_spin(rng):
    """Tom's minigun spinning up: a motor whine rising over its half second, with the
    barrels' rattle quickening under it."""
    seconds = 0.5  # Weapon.minigun.spinUp
    length = samples(seconds + 0.08)
    whine, rattle, phase, turn = [], [], 0.0, 0.0
    grit = high_pass(noise(rng, length), 1800)
    for index in range(length):
        progress = min(1.0, index / RATE / seconds)
        phase += 2 * math.pi * (90 + 330 * progress ** 0.7) / RATE
        whine.append(math.sin(phase) + 0.35 * math.sin(2 * phase) + 0.15 * math.sin(3 * phase))
        turn += 2 * math.pi * (12 + 48 * progress) / RATE
        rattle.append(grit[index] * (0.5 + 0.5 * math.sin(turn)) ** 4)
    level = [min(1.0, index / samples(0.04)) * (0.6 + 0.4 * min(1.0, index / RATE / seconds))
             for index in range(length)]
    return finish(mix((shaped(whine, level), 0.8), (shaped(rattle, level), 0.5)), drive=1.2,
                  peak=0.55)


def sword_swing(rng):
    """Laura's energy sword: a hum that bends up and down as the blade passes, inside a whoosh."""
    length = samples(0.38)
    whoosh = shaped(high_pass(low_pass(noise(rng, length), 2600), 450), bell(length, 0.12, 0.07))
    hum, phase = [], 0.0
    for index in range(length):
        phase += 2 * math.pi * (150 + 45 * math.sin(math.pi * min(1.0, index / RATE / 0.3))) / RATE
        hum.append(math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.2 * math.sin(3.01 * phase))
    return finish(mix((whoosh, 1.0), (shaped(hum, bell(length, 0.13, 0.11)), 0.55)), drive=1.2,
                  peak=0.6)


def dome_up(rng):
    """Tom's dome rising: a bright shimmer sweeping up round him."""
    length = samples(0.5)
    sweep = shaped(shimmer(length, 220, 660, 0.3), envelope(length, 0.22, 0.05))
    air = shaped(high_pass(low_pass(noise(rng, length), 5000), 1500), envelope(length, 0.08, 0.04))
    return finish(mix((sweep, 1.0), (air, 0.25)), drive=1.1, peak=0.5)


def dome_low(rng):
    """The dome running down: its shimmer stutters three times."""
    length = samples(0.42)
    gate = low_pass([1.0 if (index // samples(0.07)) % 2 == 0 else 0.15 for index in range(length)],
                    60)
    stutter = shaped(shaped(shimmer(length, 520, 520, 1), gate), envelope(length, 0.25, 0.01))
    return finish(stutter, drive=1.0, peak=0.42)


def dome_down(rng):
    """The dome let go, or dropped: its shimmer sinks away."""
    length = samples(0.4)
    return finish(shaped(shimmer(length, 600, 200, 0.3), envelope(length, 0.14, 0.01)), drive=1.0,
                  peak=0.42)


def dome_break(rng):
    """The dome run out while held: it crackles and collapses, a falling tone over a thump."""
    length = samples(0.6)
    sparks = [value if rng.random() < 0.08 else value * 0.1
              for value in high_pass(noise(rng, length), 2500)]
    crackle = shaped(sparks, envelope(length, 0.12, 0.002))
    fall = shaped(shimmer(length, 700, 120, 0.35), envelope(length, 0.2, 0.005))
    thump = shaped(tone(length, 110, 55, 0.04), envelope(length, 0.06, 0.002, 0.02))
    return finish(mix((crackle, 0.8), (fall, 0.8), (thump, 0.7)), drive=1.5, peak=0.7)


def dome_ready(rng):
    """The dome recharged in Tom's hands: one soft, high chime, unlike the guard's two notes."""
    length = samples(0.45)
    chime = mix((tone(length, 1320, 1320, 1), 1.0), (tone(length, 2640, 2640, 1), 0.25),
                (tone(length, 3960, 3960, 1), 0.1))
    return finish(shaped(chime, envelope(length, 0.12, 0.004)), drive=1.0, peak=0.35)


def rifle(rng):
    """The hostiles' rifle: darker than the carbine, so their fire is told apart."""
    shot = gunshot(
        rng, 0.8, crack=(1300, 0.007), body=(2000, 0.042), boom=(95, 48, 0.06, 0.07, 0.75),
        tail=(0.21, 0.24), delay=(0.12, 0.28))
    return finish(shot, drive=1.7, peak=0.85)


def strike_body(rng):
    """A shot striking someone: a dull thud."""
    length = samples(0.2)
    thud = shaped(low_pass(noise(rng, length), 450), envelope(length, 0.025))
    knock = shaped(tone(length, 120, 70, 0.03), envelope(length, 0.03))
    slap = shaped(high_pass(noise(rng, length), 3000), envelope(length, 0.003, 0.0002))
    return finish(mix((thud, 1.0), (knock, 0.8), (slap, 0.25)), drive=1.3, peak=0.7)


def strike_block(rng):
    """A shot striking concrete: a crack, flying grit and a short ricochet."""
    length = samples(0.3)
    crack = shaped(high_pass(noise(rng, length), 3200), envelope(length, 0.003, 0.0002))
    grit = shaped(high_pass(low_pass(noise(rng, length), 5000), 1200), envelope(length, 0.025))
    whine = shaped(tone(length, 2900, 1900, 0.12), envelope(length, 0.07, 0.004, 0.004))
    return finish(mix((crack, 1.0), (grit, 0.6), (whine, 0.22)), drive=1.4, peak=0.7)


def empty_click(rng):
    """Fire with no rounds: two small metal clicks."""
    length = samples(0.12)
    first = shaped(high_pass(noise(rng, length), 4000), envelope(length, 0.0012, 0.0001))
    second = shaped(high_pass(noise(rng, length), 4500), envelope(length, 0.001, 0.0001, 0.035))
    ring = shaped(tone(length, 3100, 3100, 1), envelope(length, 0.008, 0.0005))
    return finish(mix((first, 1.0), (second, 0.6), (ring, 0.3)), drive=1.2, peak=0.5)


def guard_warning(rng):
    """A short two-note acquisition warning, distinct from a shot or an impact."""
    length = samples(0.36)
    signal = [0.0] * length
    for start, frequency, duration in ((0.0, 660, 0.11), (0.155, 990, 0.15)):
        begin = samples(start)
        for index in range(samples(duration)):
            time = index / RATE
            edge = min(1.0, time / 0.008, (duration - time) / 0.018)
            note = math.sin(2 * math.pi * frequency * time)
            overtone = 0.2 * math.sin(4 * math.pi * frequency * time)
            signal[begin + index] = edge * (note + overtone)
    return finish(signal, drive=1.0, peak=0.55)


def guard_leg_break(rng):
    """A dry joint shearing, followed by a low clonk and a brief, uneven metallic ring.

    No shot's boom or echo: one short mechanical event as the detached leg staggers the guard.
    """
    length = samples(0.42)
    shear = shaped(high_pass(noise(rng, length), 1900), envelope(length, 0.009, 0.0004))
    clonk = shaped(tone(length, 320, 95, 0.035), envelope(length, 0.045, 0.001, 0.012))
    ring = mix((tone(length, 760, 760, 1), 1.0), (tone(length, 1230, 1230, 1), 0.45),
               (tone(length, 1870, 1870, 1), 0.2))
    ring = shaped(ring, envelope(length, 0.055, 0.002, 0.006))
    strain = shaped(tone(length, 620, 180, 0.06), envelope(length, 0.07, 0.003, 0.018))
    return finish(mix((shear, 1.0), (clonk, 0.85), (ring, 0.45), (strain, 0.18)),
                  drive=1.35, peak=0.78)


# Each file's name, as CombatSound names it in the app, and how it is made.
SOUNDS = {
    "long-rifle": long_rifle,
    "assault-rifle": assault_rifle,
    "shotgun": shotgun,
    "minigun": minigun,
    "minigun-spin": minigun_spin,
    "sword-swing": sword_swing,
    "dome-up": dome_up,
    "dome-low": dome_low,
    "dome-down": dome_down,
    "dome-break": dome_break,
    "dome-ready": dome_ready,
    "rifle": rifle,
    "strike-body": strike_body,
    "strike-block": strike_block,
    "empty-click": empty_click,
    "guard-warning": guard_warning,
    "guard-leg-break": guard_leg_break,
}


def quantised(signal):
    return [max(-32767, min(32767, round(value * 32767))) for value in signal]


def make(name):
    """A sound's 16-bit samples: the same every run, from a generator seeded by its name."""
    return quantised(SOUNDS[name](random.Random(f"lauder-{name}")))


def write(path, values):
    with wave.open(str(path), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(RATE)
        stream.writeframes(struct.pack(f"<{len(values)}h", *values))


def read(path):
    with wave.open(str(path), "rb") as stream:
        if (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) != (1, 2, RATE):
            return None
        frames = stream.readframes(stream.getnframes())
    return list(struct.unpack(f"<{len(frames) // 2}h", frames))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "--check", action="store_true", help="compare the committed files instead of writing them")
    arguments = parser.parse_args()
    problems = []
    for name in SOUNDS:
        path = OUTPUT / f"{name}.wav"
        values = make(name)
        if not arguments.check:
            OUTPUT.mkdir(parents=True, exist_ok=True)
            write(path, values)
            print(f"Wrote {path}: {len(values) / RATE:.2f} s.")
            continue
        committed = read(path) if path.is_file() else None
        if committed is None:
            problems.append(f"{path} is missing or not 16-bit mono at {RATE} Hz")
        elif len(committed) != len(values) or any(
                abs(a - b) > TOLERANCE for a, b in zip(committed, values)):
            problems.append(f"{path} differs from what the script makes")
    unexpected = sorted(
        path.name for path in OUTPUT.glob("*.wav") if path.stem not in SOUNDS) if OUTPUT.is_dir() else []
    problems += [f"{OUTPUT / name} is not one of the script's sounds" for name in unexpected]
    if problems:
        print("\n".join(problems), file=sys.stderr)
        print("Run 'python3 apple/scripts/make-sounds.py' and commit the result.", file=sys.stderr)
        return 1
    if arguments.check:
        print(f"The {len(SOUNDS)} combat sounds match apple/scripts/make-sounds.py.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
