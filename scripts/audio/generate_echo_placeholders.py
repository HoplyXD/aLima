#!/usr/bin/env python3
"""Generate original placeholder WAV files for the Cultural Echo audio layers.

These are procedurally generated synthetic tones, not recordings of traditional
music or third-party samples. They exist so the Phase 6 mixer and missing-audio
fallback paths can be exercised in development. Final Cultural Echo audio must be
original, human-curated, reviewed, and disclosed before release.

Outputs four mono 44.1kHz PCM WAV files under assets/audio/echoes/:
  hum.wav      - low drone around 80 Hz with slow amplitude modulation
  melody.wav   - slow arpeggio of simple sine tones
  voice.wav    - formant-like swept sine phrase (no lyrics, no speech sample)
  heartbeat.wav - low thump pulse at ~72 BPM
"""

import math
import os
import struct
import wave

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "echoes")
SAMPLE_RATE = 44100
DURATION_SECONDS = 8.0
SAMPLES = int(SAMPLE_RATE * DURATION_SECONDS)


def write_wav(path: str, samples: list[float]) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "w") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples
        )
        wav.writeframes(frames)


def generate_hum() -> list[float]:
    samples = []
    for i in range(SAMPLES):
        t = i / SAMPLE_RATE
        freq = 80.0 + 2.0 * math.sin(2.0 * math.pi * 0.25 * t)
        env = 0.7 + 0.3 * math.sin(2.0 * math.pi * 0.4 * t)
        s = math.sin(2.0 * math.pi * freq * t) * 0.5 * env
        samples.append(s)
    return samples


def generate_melody() -> list[float]:
    notes = [220.0, 261.63, 329.63, 392.0]
    note_dur = 1.0
    samples = []
    for i in range(SAMPLES):
        t = i / SAMPLE_RATE
        idx = int(t / note_dur) % len(notes)
        freq = notes[idx]
        phase = (t % note_dur) / note_dur
        env = 1.0 - phase  # simple decay
        s = math.sin(2.0 * math.pi * freq * t) * 0.4 * env
        samples.append(s)
    return samples


def generate_voice() -> list[float]:
    samples = []
    for i in range(SAMPLES):
        t = i / SAMPLE_RATE
        base = 300.0 + 150.0 * math.sin(2.0 * math.pi * 0.35 * t)
        mod = math.sin(2.0 * math.pi * 5.0 * t)
        freq = base + 50.0 * mod
        env = 0.5 + 0.5 * math.sin(2.0 * math.pi * 0.2 * t)
        s = math.sin(2.0 * math.pi * freq * t) * 0.35 * env
        samples.append(s)
    return samples


def generate_heartbeat() -> list[float]:
    bpm = 72.0
    beat_interval = 60.0 / bpm
    samples = []
    for i in range(SAMPLES):
        t = i / SAMPLE_RATE
        phase = t % beat_interval
        # Two quick pulses per beat.
        p1 = math.exp(-40.0 * abs(phase - 0.05))
        p2 = math.exp(-60.0 * abs(phase - 0.18)) * 0.6
        s = (p1 + p2) * 0.7 * math.sin(2.0 * math.pi * 60.0 * phase)
        samples.append(s)
    return samples


def main() -> None:
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    write_wav(os.path.join(OUTPUT_DIR, "hum.wav"), generate_hum())
    write_wav(os.path.join(OUTPUT_DIR, "melody.wav"), generate_melody())
    write_wav(os.path.join(OUTPUT_DIR, "voice.wav"), generate_voice())
    write_wav(os.path.join(OUTPUT_DIR, "heartbeat.wav"), generate_heartbeat())
    print("Generated placeholder Echo WAV files in", OUTPUT_DIR)


if __name__ == "__main__":
    main()
