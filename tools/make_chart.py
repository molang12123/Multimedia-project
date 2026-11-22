#!/usr/bin/env python3
"""Generate a song file (chart schema v2: 2 lanes, tap / hold / swipe) from an audio file.

  pip install librosa numpy            (ffmpeg needed if your audio is mp3/ogg)
  python tools/make_chart.py audio/monkey_dancing.mp3 --id monkey_dancing \
      --title "Monkey Dancing" --audio-res res://audio/monkey_dancing.mp3 \
      --video res://video/monkey_dancing.ogv -o charts/monkey_dancing.json

For audio without a detectable beat (or a click track) give the grid yourself:
  --grid 120:2.0        # BPM : time of the first beat in seconds

Notes follow the detected beats; "challenge" also uses the 8th notes that have an audible
onset. The output is only a starting point: play it, then edit the JSON by hand.
Remember to add the new file to SONG_FILES in scripts/audio/audio_manager.gd.
"""
import argparse
import json
import random

import numpy as np

HOP = 256
DIFFS = ("easy", "normal", "challenge")


def load(path):
    import librosa
    y, sr = librosa.load(path, sr=22050, mono=True)
    return y, sr


def attack_time(y, sr, t, back=0.05, fwd=0.03):
    """Refine t to the steepest rise of the short-time loudness around it."""
    a, b = max(int((t - back) * sr), 0), min(int((t + fwd) * sr), len(y))
    seg = y[a:b]
    if len(seg) < 200:
        return t
    win = int(0.004 * sr)
    rms = np.sqrt(np.convolve(seg ** 2, np.ones(win) / win, mode="same")) + 1e-6
    rise = np.diff(np.log(rms))
    return (a + int(np.argmax(rise))) / sr


def detect_beats(y, sr):
    import librosa
    env = librosa.onset.onset_strength(y=y, sr=sr, hop_length=HOP, n_fft=1024)
    _, beats = librosa.beat.beat_track(onset_envelope=env, sr=sr, hop_length=HOP,
                                       units="time", start_bpm=140, tightness=100)
    ft = librosa.frames_to_time(np.arange(len(env)), sr=sr, hop_length=HOP)
    out = []
    for b in beats:                                   # snap to the strongest nearby onset
        m = np.abs(ft - b) <= 0.04
        out.append(ft[m][np.argmax(env[m])] if m.any() else b)
    out = [attack_time(y, sr, t) for t in out]
    return np.array(sorted(out)), env, ft


def build(beats, mids, mids_strong, dur, diff, rng):
    p_hold, p_swipe, p_chord = {
        "easy": (0.18, 0.12, 0.0),
        "normal": (0.12, 0.15, 0.0),
        "challenge": (0.10, 0.18, 0.12),
    }[diff]
    if diff == "easy":
        cands = [(t, False) for t in beats[::2]]
    elif diff == "normal":
        cands = [(t, False) for t in beats]
    else:
        cands = [(t, False) for t in beats] + [(t, True) for t, s in zip(mids, mids_strong) if s]
    cands.sort()

    def nxt(t):
        return next((b for b in beats if b > t + 0.05), t + 0.5)

    busy = [0.0, 0.0]          # lane is occupied by a hold until this time
    last_t = [-9.0, -9.0]
    lane, swipe_up = 1, True
    notes = []
    for t, is_mid in cands:
        if t > dur - 1.0:
            break
        lane = lane if rng.random() < 0.3 else 1 - lane          # mostly alternate
        if t < busy[lane] + 0.12 or t - last_t[lane] < 0.18:
            lane = 1 - lane
            if t < busy[lane] + 0.12 or t - last_t[lane] < 0.18:
                continue
        r = rng.random()
        kind = "tap"
        if not is_mid:                                           # 8th notes stay simple
            if r < p_hold:
                kind = "hold"
            elif r < p_hold + p_swipe:
                kind = "swipe"
        length = 0.0
        if kind == "hold":
            end = nxt(nxt(t)) if rng.random() < 0.5 else nxt(t)
            length = round(min(end - t, 1.2) - 0.08, 3)
            if length < 0.3:
                kind = "tap"
        note = {"time_sec": round(float(t), 3), "lane": lane}
        if kind == "hold":
            note.update(type="hold", duration_sec=length)
            busy[lane] = t + length
        elif kind == "swipe":
            note.update(type="swipe", direction="up" if swipe_up else "down")
            swipe_up = not swipe_up
        notes.append(note)
        last_t[lane] = t
        if kind == "tap" and not is_mid and rng.random() < p_chord:   # two-thumb chord
            o = 1 - lane
            if t >= busy[o] + 0.12 and t - last_t[o] >= 0.18:
                notes.append({"time_sec": round(float(t), 3), "lane": o})
                last_t[o] = t
    return sorted(notes, key=lambda n: (n["time_sec"], n["lane"]))


def write(path, song):
    """One note per line, so the file stays easy to edit by hand and to diff."""
    with open(path, "w", encoding="utf-8") as f:
        f.write("{\n")
        for k, v in song.items():
            if k != "difficulties":
                f.write("  %s: %s,\n" % (json.dumps(k), json.dumps(v, ensure_ascii=False)))
        f.write('  "difficulties": {\n')
        items = list(song["difficulties"].items())
        for i, (d, notes) in enumerate(items):
            f.write('    "%s": [\n' % d)
            for j, n in enumerate(notes):
                f.write("      " + json.dumps(n, ensure_ascii=False) + ("," if j < len(notes) - 1 else "") + "\n")
            f.write("    ]" + ("," if i < len(items) - 1 else "") + "\n")
        f.write("  }\n}\n")


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("audio", help="audio file on disk")
    ap.add_argument("--id", required=True, help="song_id (also the file name)")
    ap.add_argument("--title", required=True)
    ap.add_argument("--audio-res", required=True, help="res:// path written into the song file")
    ap.add_argument("--video", help="res:// path of a background video")
    ap.add_argument("--grid", help="BPM:FIRST_BEAT_SECONDS instead of beat detection")
    ap.add_argument("--seed", type=int, default=7)
    ap.add_argument("-o", "--out", required=True)
    a = ap.parse_args()

    y, sr = load(a.audio)
    dur = len(y) / sr
    if a.grid:
        bpm, first = (float(x) for x in a.grid.split(":"))
        beats = np.arange(first, dur - 1.0, 60.0 / bpm)
        env = ft = None
    else:
        beats, env, ft = detect_beats(y, sr)
    mids = (beats[:-1] + beats[1:]) / 2
    if env is not None:
        thr = np.percentile(env, 70)
        strong = [env[np.abs(ft - m) <= 0.03].max() >= thr for m in mids]
    else:
        strong = [True] * len(mids)
    rng = random.Random(a.seed)
    song = {
        "schema_version": 2,
        "song_id": a.id,
        "title": a.title,
        "bpm": round(float(60.0 / np.median(np.diff(beats))), 1),
        "duration_sec": round(dur, 3),
        "audio": {"path": a.audio_res, "offset": 0.0},
    }
    if a.video:
        song["video"] = {"path": a.video, "offset": 0.0}
    song["difficulties"] = {d: build(beats, mids, strong, dur, d, rng) for d in DIFFS}
    write(a.out, song)
    print({d: len(n) for d, n in song["difficulties"].items()}, "bpm", song["bpm"], "beats", len(beats))


if __name__ == "__main__":
    main()
