#!/usr/bin/env python3
"""Generate Lauder's combat sounds (ADR 0008) as 16-bit mono WAV files, using only the standard
library.

Each sound is built from simple parts: filtered noise for a shot's crack and body, a falling tone
for its boom, a quiet tail and an echo off the buildings. They stand in until recordings replace
them under the same names. Run from the repository root:

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


def carbine(rng):
    """Miki's precision carbine: a clean crack and a firm boom."""
    shot = gunshot(
        rng, 0.7, crack=(1800, 0.006), body=(2600, 0.035), boom=(110, 55, 0.05, 0.06, 0.7),
        tail=(0.18, 0.22), delay=(0.11, 0.25))
    return finish(shot, drive=1.6, peak=0.9)


def light_burst(rng):
    """One round of Laura's light burst weapon: short, bright and lighter."""
    shot = gunshot(
        rng, 0.45, crack=(2400, 0.004), body=(3600, 0.022), boom=(150, 80, 0.03, 0.035, 0.45),
        tail=(0.11, 0.16), delay=(0.09, 0.18))
    return finish(shot, drive=1.4, peak=0.75)


def close_scatter(rng):
    """Tom's close scatter weapon: a heavy, deep blast with a long tail."""
    shot = gunshot(
        rng, 0.95, crack=(1100, 0.009), body=(1800, 0.06), boom=(80, 38, 0.08, 0.11, 0.95),
        tail=(0.26, 0.3), delay=(0.13, 0.3))
    return finish(shot, drive=2.0, peak=0.95)


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


# Each file's name, as CombatSound names it in the app, and how it is made.
SOUNDS = {
    "carbine": carbine,
    "light-burst": light_burst,
    "close-scatter": close_scatter,
    "rifle": rifle,
    "strike-body": strike_body,
    "strike-block": strike_block,
    "empty-click": empty_click,
    "guard-warning": guard_warning,
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
