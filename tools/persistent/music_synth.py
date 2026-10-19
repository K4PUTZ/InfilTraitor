#!/usr/bin/env python3
##
## music_synth.py — render a MIDI line through Surge XT (free, GPL-3, 3 000+ factory presets) with pedalboard.
## Surge is a VST3 instrument at ~/Library/Audio/Plug-Ins/VST3/Surge XT.vst3 (extracted from the Homebrew cask's pkg
## without sudo) and its factory patches live in ~/Documents/Surge XT/patches_factory/<Category>/<Name>.fxp.
## A patch is loaded by swapping the 'sub3' chunk of a .fxp into the plugin's JUCE state (the state's IComponent is
## the same chunk, JUCE-base64 encoded) — pedalboard has no preset API of its own.
##
##   .venv/bin/python tools/persistent/music_synth.py list [Category]            # presets (Leads, Basses, Pads, ...)
##   .venv/bin/python tools/persistent/music_synth.py render <preset> <notes.json> <out.wav> [--bpm 124] [--bars 8]
## notes.json: [[step16, midi_note, length_in_16ths, velocity0-127], ...] on the 16th grid, so every line is sample-aligned.
import json, os, re, sys
from pathlib import Path
import numpy as np

PLUGIN = os.path.expanduser("~/Library/Audio/Plug-Ins/VST3/Surge XT.vst3")
PATCHES = Path(os.path.expanduser("~/Documents/Surge XT/patches_factory"))
ALPH = b".ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+"  # JUCE MemoryBlock base64
SR = 44100


def _b64(data):
    out, bits, nb = bytearray(), 0, 0
    for byte in data:
        bits |= byte << nb; nb += 8
        while nb >= 6:
            out.append(ALPH[bits & 63]); bits >>= 6; nb -= 6
    if nb:
        out.append(ALPH[bits & 63])
    return bytes(out)


def find_preset(name):
    hits = [p for p in PATCHES.rglob("*.fxp") if p.stem == name or str(p.relative_to(PATCHES).with_suffix("")) == name]
    if not hits:
        sys.exit(f"[synth] preset '{name}' not found (use `list`)")
    return hits[0]


def load_surge(preset=None):
    from pedalboard import load_plugin
    plug = load_plugin(PLUGIN)
    if preset:
        fxp = find_preset(preset).read_bytes()
        chunk = fxp[fxp.index(b"sub3"):]  # after the 60-byte fxp header and the chunk size
        rs = plug.raw_state
        xml = rs[rs.index(b"<?xml"):]
        new = str(len(chunk)).encode() + b"." + _b64(chunk)
        xml = re.sub(rb"(<IComponent>).*?(</IComponent>)", lambda m: m.group(1) + new + m.group(2), xml, count=1, flags=re.S)
        plug.raw_state = rs[:rs.index(b"<?xml")][:4] + len(xml).to_bytes(4, "little") + xml
    return plug


def render(preset, notes, bpm, bars, tail=2.0):
    from pedalboard.io import AudioFile  # noqa: F401  (import check)
    plug = load_surge(preset)
    step = 60.0 / bpm / 4
    dur = bars * 16 * step + tail
    msgs = []
    for s, n, ln, vel in notes:
        t = s * step
        msgs.append((bytes([0x90, n, vel]), t))
        msgs.append((bytes([0x80, n, 0]), t + max(ln, 1) * step * 0.95))
    audio = plug(msgs, duration=dur, sample_rate=SR, num_channels=2, buffer_size=512, reset=True)
    return audio  # shape (channels, samples)


def main():
    a = sys.argv[1:]
    if not a:
        sys.exit(__doc__)
    if a[0] == "list":
        for p in sorted(PATCHES.rglob("*.fxp")):
            if len(a) < 2 or p.parent.name == a[1]:
                print(p.relative_to(PATCHES))
    elif a[0] == "render":
        import soundfile as sf
        bpm = int(a[a.index("--bpm") + 1]) if "--bpm" in a else 124
        bars = int(a[a.index("--bars") + 1]) if "--bars" in a else 8
        audio = render(a[1], json.loads(Path(a[2]).read_text()), bpm, bars)
        sf.write(a[3], audio.T, SR)
        print(f"[synth] {a[1]} -> {a[3]} (peak {np.abs(audio).max():.3f})")


if __name__ == "__main__":
    main()
