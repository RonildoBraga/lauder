#!/usr/bin/env python3
"""Generate the graybox duel's three placeholder combat sounds as 16-bit mono WAV files.

The original deterministic sword whoosh, body impact and hard block are reused unchanged.
No firearm, dome or robot sound is packaged. Historical WAVs remain with the bridge reference.

    python3 apple/scripts/make-sounds.py            # write the active files
    python3 apple/scripts/make-sounds.py --check    # compare the committed files
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


def finish(signal, drive, peak):
    """Softly clipped for punch, scaled to `peak` and faded out at the end."""
    out = [math.tanh(drive * value) for value in signal]
    top = max(abs(value) for value in out) or 1.0
    out = [value / top * peak for value in out]
    fade = samples(0.01)
    for index in range(fade):
        out[-1 - index] *= index / fade
    return out


def bell(length, peak, width):
    """A smooth swell and fade, highest at `peak` seconds, about `width` seconds either side."""
    return [math.exp(-(((index / RATE) - peak) / width) ** 2) for index in range(length)]


def sword_swing(rng):
    """A blade whoosh with a rising and falling hum, reused from the bridge prototype."""
    length = samples(0.38)
    whoosh = shaped(high_pass(low_pass(noise(rng, length), 2600), 450), bell(length, 0.12, 0.07))
    hum, phase = [], 0.0
    for index in range(length):
        phase += 2 * math.pi * (150 + 45 * math.sin(math.pi * min(1.0, index / RATE / 0.3))) / RATE
        hum.append(math.sin(phase) + 0.4 * math.sin(2 * phase) + 0.2 * math.sin(3.01 * phase))
    return finish(mix((whoosh, 1.0), (shaped(hum, bell(length, 0.13, 0.11)), 0.55)), drive=1.2,
                  peak=0.6)


def strike_body(rng):
    """A body impact: a dull thud."""
    length = samples(0.2)
    thud = shaped(low_pass(noise(rng, length), 450), envelope(length, 0.025))
    knock = shaped(tone(length, 120, 70, 0.03), envelope(length, 0.03))
    slap = shaped(high_pass(noise(rng, length), 3000), envelope(length, 0.003, 0.0002))
    return finish(mix((thud, 1.0), (knock, 0.8), (slap, 0.25)), drive=1.3, peak=0.7)


def strike_block(rng):
    """A hard block impact: a crack and short ring."""
    length = samples(0.3)
    crack = shaped(high_pass(noise(rng, length), 3200), envelope(length, 0.003, 0.0002))
    grit = shaped(high_pass(low_pass(noise(rng, length), 5000), 1200), envelope(length, 0.025))
    whine = shaped(tone(length, 2900, 1900, 0.12), envelope(length, 0.07, 0.004, 0.004))
    return finish(mix((crack, 1.0), (grit, 0.6), (whine, 0.22)), drive=1.4, peak=0.7)


# Each file's name, as CombatSound names it in the app, and how it is made.
SOUNDS = {
    "sword-swing": sword_swing,
    "strike-body": strike_body,
    "strike-block": strike_block,
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
