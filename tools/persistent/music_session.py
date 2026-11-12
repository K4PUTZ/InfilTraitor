#!/usr/bin/env python3
##
## music_session.py — build an Ardour session from a JSON spec: one track per line, every line a set of clips on ONE shared
## grid (tempo and meter fixed by the spec), so the Director can press play, move, copy and paste them on Ardour's timeline.
## A line is a MIDI clip played by a Surge XT patch. The session is built headless: ardour9-lua opens a new session and starts
## Ardour's own MCP HTTP surface (port 4820), this script drives it (tracks, Surge XT, clips, loop range, save), then writes
## the chosen Surge patch into the plugin state of the saved file. Windows only (the PC workspace).
##
##   .venv\Scripts\python tools\persistent\music_session.py build ASSETS\AUDIO\MUSIC\SESSIONS\<name>.spec.json [--force] [--no-render]
##   .venv\Scripts\python tools\persistent\music_session.py render <name>     # SESSIONS\<name>\export\<name>.wav, to listen without Ardour
##   .venv\Scripts\python tools\persistent\music_session.py open <name>       # opens the session in Ardour
##
## Spec (JSON): name, tempo, meter ("4/4": the denominator must be 4), bars, tracks[]. A track has name, instrument
## {plugin: "Surge XT", patch: "Basses/Bass 5"}, optional gain_db (fader) and clips[]. A clip has name, bar (start, 1-based), bars (length), and notes:
## `pattern` (one bar of {beat, note, vel, len}, repeated over the clip) and/or `notes` (the same fields plus the clip-relative `bar`).
## `note` is a name (E1, F#2, Bb3; C4 = 60) or a MIDI number; `beat` is 1-based and may be fractional; `len` is in beats.
## A session is never overwritten: --force moves the old folder aside as <name>.replaced-<time>.
import argparse, base64, html, json, os, re, shutil, socket, struct, subprocess, sys, tempfile, time, urllib.error, urllib.request
from datetime import datetime
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
REPO = Path(__file__).resolve().parents[2]
SESSIONS = REPO / "ASSETS/AUDIO/MUSIC/SESSIONS"
ARDOUR = Path(os.environ.get("ARDOUR_DIR", os.path.expandvars(r"%ProgramFiles%\Ardour9")))
PORT = 4820  # Ardour's MCP HTTP surface, fixed by Ardour
SURGE_ID = "ABCDEF019182FAEB566D624153675854"  # Surge XT's VST3 class id, as Ardour stores it
SAMPLE_RATE = 48000

## Runs inside ardour9-lua. Ardour 9.10's MCP surface has no tool for the tempo map or the session range, so the host does
## those two things; everything else is done over MCP while the host waits for the flag file.
HOST_LUA = r'''
local dir, name = arg[1], arg[2]
local bpm, num, den, bars, flag = tonumber(arg[3]), tonumber(arg[4]), tonumber(arg[5]), tonumber(arg[6]), arg[7]
local sr = tonumber(arg[8])
assert(create_session(dir, name, sr), "create_session failed")
if bpm ~= 120 or num ~= 4 or den ~= 4 then
  local tm = Temporal.TempoMap.write_copy()
  tm:set_tempo(Temporal.Tempo(bpm, bpm, den), Temporal.timepos_t(0))
  tm:set_meter(Temporal.Meter(num, den), Temporal.timepos_t(0))
  Temporal.TempoMap.update(tm)
end
local m = ARDOUR.ControlProtocolManager:manager()
local up = false
for p in m:control_protocol_infos():iter() do
  if p.name == "MCP HTTP Server (Experimental)" then m:activate(p, ""); up = p:active() end
end
assert(up, "the MCP surface did not start")
for i = 1, 2400 do  -- at most 10 minutes, so a crashed driver cannot leave this process behind
  ARDOUR.LuaAPI.usleep(250000)
  local f = io.open(flag, "r")
  if f then f:close() break end
end
for p in m:control_protocol_infos():iter() do  -- off again, or every opening of the session would listen on port 4820
  if p.name == "MCP HTTP Server (Experimental)" then pcall(function() m:deactivate(p, "") end) end
end
local secs = bars * (num * 4 / den) * 60 / bpm
Session:set_session_extents(Temporal.timepos_t(0), Temporal.timepos_t(math.floor(secs * sr + 0.5)))
Session:save_state("")
close_session()
'''


class Mcp:
    def __init__(self):
        self.url, self.n = f"http://127.0.0.1:{PORT}/mcp", 0

    def rpc(self, method, params=None, timeout=60):
        self.n += 1
        body = json.dumps({"jsonrpc": "2.0", "id": self.n, "method": method, "params": params or {}}).encode()
        req = urllib.request.Request(self.url, data=body, headers={"Content-Type": "application/json", "Accept": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read().decode())

    def call(self, tool, **args):
        r = self.rpc("tools/call", {"name": tool, "arguments": args})
        if "error" in r:
            sys.exit(f"[session] {tool}: {r['error']}")
        res = r["result"]
        if res.get("isError"):
            sys.exit(f"[session] {tool} failed: {json.dumps(res.get('content'))[:600]}")
        return res.get("structuredContent", {})


def note_number(n):
    if isinstance(n, int):
        return n
    m = re.fullmatch(r"([A-Ga-g])([#b]?)(-?\d+)", str(n).strip())
    if not m:
        sys.exit(f"[session] bad note '{n}' (use E1, F#2, Bb3 or a MIDI number)")
    pc = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}[m[1].upper()] + {"#": 1, "b": -1, "": 0}[m[2]]
    return 12 * (int(m[3]) + 1) + pc


def load_spec(path):
    spec = json.loads(Path(path).read_text(encoding="utf-8-sig"))
    for k in ("name", "tempo", "meter", "bars", "tracks"):
        if k not in spec:
            sys.exit(f"[session] spec lacks '{k}'")
    if not re.fullmatch(r"[A-Za-z0-9_-]+", spec["name"]):
        sys.exit("[session] name may only hold letters, digits, - and _ (it is the folder and the file name)")
    m = re.fullmatch(r"(\d+)/(\d+)", spec["meter"])
    if not m or m[2] != "4":
        sys.exit("[session] meter must be N/4 for now (beats are quarter notes)")
    spec["_num"] = int(m[1])
    if not 20 <= spec["tempo"] <= 300:
        sys.exit("[session] tempo out of range")
    names = set()
    for t in spec["tracks"]:
        if t["name"] in names:
            sys.exit(f"[session] duplicate track '{t['name']}'")
        names.add(t["name"])
        for c in t.get("clips", []):
            if c["bar"] < 1 or c["bar"] + c["bars"] - 1 > spec["bars"]:
                sys.exit(f"[session] clip '{c['name']}' on '{t['name']}' falls outside the {spec['bars']} bars")
            c["_events"] = clip_events(c, spec["_num"])
    return spec


def clip_events(clip, beats_per_bar):
    ev = []
    for bar in range(1, clip["bars"] + 1):
        for n in clip.get("pattern", []):
            ev.append((bar, n))
    ev += [(n["bar"], n) for n in clip.get("notes", [])]
    out = []
    for bar, n in ev:
        if not 1 <= bar <= clip["bars"] or not 1 <= n["beat"] < beats_per_bar + 1 or n.get("len", 1.0) <= 0:
            sys.exit(f"[session] clip '{clip['name']}': note out of the clip ({n})")
        out.append({"bar": bar, "b": n["beat"], "n": note_number(n["note"]), "v": n.get("vel", 100), "l": n.get("len", 1.0)})
    return out


def surge_state(patch):
    """Ardour's VST3 chunk: a .vstpreset stream whose 'Comp' part is Surge's state, which is a .fxp's 'sub3' chunk.
    JUCE's own trailing 'JUCEPrivateData' marker must NOT be added: with it Surge crashes on load (tested)."""
    import music_synth as ms
    fxp = ms.find_preset(patch).read_bytes()
    comp = fxp[fxp.index(b"sub3"):]
    blob = (b"VST3" + struct.pack("<i", 1) + SURGE_ID.encode() + struct.pack("<q", 48 + len(comp)) + comp
            + b"List" + struct.pack("<i", 1) + b"Comp" + struct.pack("<qq", 48, len(comp)))
    return base64.b64encode(blob).decode()


def set_patch(ardour_file, track, patch):
    text = ardour_file.read_bytes().decode("utf-8")
    start = re.search(r'<Route [^>]*\bname="%s"' % re.escape(track.replace("&", "&amp;")), text)
    if not start:
        sys.exit(f"[session] track '{track}' not found in the saved session")
    end = text.index("</Route>", start.start())
    block = text[start.start():end]
    proc = re.search(r'<Processor [^>]*type="vst3"[^>]*unique-id="%s"' % SURGE_ID, block)
    chunk = re.search(r"<chunk>.*?</chunk>", block[proc.start():], re.S) if proc else None
    if not chunk:
        sys.exit(f"[session] no Surge XT state to replace on '{track}'")
    a = start.start() + proc.start() + chunk.start()
    b = start.start() + proc.start() + chunk.end()
    ardour_file.write_bytes((text[:a] + "<chunk>" + surge_state(patch) + "</chunk>" + text[b:]).encode("utf-8"))


def prune_orphan_midi(out, name, afile):
    """Ardour leaves empty MIDI sources of its own (write sources that never received a note) next to the real one."""
    used = {html.unescape(n) for n in re.findall(r'<Source name="([^"]+\.mid)"', afile.read_bytes().decode("utf-8"))}
    for f in (out / "interchange" / name / "midifiles").glob("*.mid"):
        if f.name not in used:
            f.unlink()


def ardour_env(cfg):
    e = dict(os.environ)
    e["ARDOUR_CONFIG_PATH"] = str(cfg)  # keeps the headless run out of the user's own Ardour config
    return e


def port_busy():
    with socket.socket() as s:
        s.settimeout(0.5)
        return s.connect_ex(("127.0.0.1", PORT)) == 0


def build(spec_path, force, render_after):
    spec = load_spec(spec_path)
    name, out = spec["name"], SESSIONS / spec["name"]
    if not (ARDOUR / "bin/ardour9-lua.exe").exists():
        sys.exit(f"[session] Ardour not found at {ARDOUR} (set ARDOUR_DIR)")
    if out.exists() and not force:
        sys.exit(f"[session] {out} exists; --force moves it aside and builds a new one")
    if port_busy():
        sys.exit(f"[session] port {PORT} is in use (another Ardour with its MCP surface on?); close it and retry")
    if out.exists():
        aside = out.with_name(f"{name}.replaced-{datetime.now():%Y%m%d-%H%M%S}")
        out.rename(aside)
        print(f"[session] old session moved to {aside}")
    SESSIONS.mkdir(parents=True, exist_ok=True)
    work = Path(tempfile.mkdtemp(prefix="music_session_"))
    (work / "cfg").mkdir()
    (work / "host.lua").write_text(HOST_LUA, encoding="utf-8")
    flag, log = work / "stop.flag", work / "host.log"
    mcp = Mcp()
    with open(log, "wb") as lf:
        host = subprocess.Popen([str(ARDOUR / "bin/ardour9-lua.exe"), str(work / "host.lua"), out.as_posix(), name, str(spec["tempo"]),
                                 str(spec["_num"]), "4", str(spec["bars"]), flag.as_posix(), str(SAMPLE_RATE)],
                                stdout=lf, stderr=subprocess.STDOUT, env=ardour_env(work / "cfg"), cwd=work)
    try:
        t0 = time.time()
        while True:
            if host.poll() is not None:
                sys.exit(f"[session] Ardour host exited early:\n{log.read_text(errors='replace')[-1500:]}")
            if time.time() - t0 > 90:
                sys.exit("[session] Ardour's MCP surface did not answer in 90 s")
            try:
                mcp.rpc("initialize", {"protocolVersion": "2025-03-26", "capabilities": {}, "clientInfo": {"name": "music_session", "version": "1"}}, timeout=3)
                break
            except (urllib.error.URLError, OSError, ValueError):
                time.sleep(0.5)
        info = mcp.call("session_get_info")
        if info["sessionName"] != name or round(info["tempoBpm"]) != round(spec["tempo"]):
            sys.exit(f"[session] the host holds the wrong session or tempo: {info}")
        plugins = {p["name"]: p for p in mcp.call("plugin_list_available", search="Surge")["plugins"]}
        total = 0
        for t in spec["tracks"]:
            tid = mcp.call("tracks_add", type="midi", name=t["name"], count=1)["created"]["routes"][0]["id"]
            got = mcp.call("track_rename", id=tid, newName=t["name"])["track"]["name"]
            if got != t["name"]:
                sys.exit(f"[session] Ardour named the track '{got}' instead of '{t['name']}'")
            ins = t.get("instrument")
            if ins:
                if ins["plugin"] != "Surge XT" or "Surge XT" not in plugins:
                    sys.exit("[session] only Surge XT is wired so far, and it must be scanned by Ardour (ardour-vst3-scanner)")
                mcp.call("plugin_add_by_plugin_id", id=tid, pluginId=plugins["Surge XT"]["pluginId"])
            if "gain_db" in t:
                mcp.call("track_set_fader_db", id=tid, db=t["gain_db"])
            for c in t.get("clips", []):
                r = mcp.call("midi_note_import_json_to_new_region_bbt", trackId=tid, name=c["name"], startBar=c["bar"], startBeat=1,
                             endBar=c["bar"] + c["bars"], endBeat=1, midi={"midi_events": c["_events"]})
                if r["summary"]["notesInserted"] != len(c["_events"]):
                    sys.exit(f"[session] clip '{c['name']}': Ardour kept {r['summary']['notesInserted']} of {len(c['_events'])} notes")
                got = mcp.call("midi_note_list", regionId=r["region"]["regionId"])
                want = sorted((e["n"]) for e in c["_events"])
                if got["count"] != len(want) or sorted(n["note"] for n in got["notes"]) != want:
                    sys.exit(f"[session] clip '{c['name']}': the notes in Ardour differ from the spec")
                total += got["count"]
                print(f"[session] {t['name']}: clip '{c['name']}' bars {c['bar']}-{c['bar'] + c['bars'] - 1}, {got['count']} notes read back from Ardour")
        mcp.call("transport_loop_location_bbt", startBar=1, startBeat=1, endBar=spec["bars"] + 1, endBeat=1)
        mcp.call("session_save")
    finally:
        flag.write_text("stop")
        try:
            host.wait(timeout=60)
        except subprocess.TimeoutExpired:
            host.kill()
    afile = out / f"{name}.ardour"
    if not afile.exists():
        sys.exit(f"[session] the host did not write {afile}:\n{log.read_text(errors='replace')[-1500:]}")
    for t in spec["tracks"]:
        if t.get("instrument", {}).get("patch"):
            set_patch(afile, t["name"], t["instrument"]["patch"])
            print(f"[session] {t['name']}: Surge XT patch {t['instrument']['patch']}")
    prune_orphan_midi(out, name, afile)
    text = afile.read_bytes().decode("utf-8")
    fixed = re.sub(r'(<Protocol name="MCP HTTP Server \(Experimental\)"[^>]*?) active="1"', lambda m: m.group(1) + ' active="0"', text)
    if fixed != text:  # the host could not switch the surface off; the saved file must not start a server on every open
        afile.write_bytes(fixed.encode("utf-8"))
        print("[session] MCP surface switched off in the saved file")
    print(f"[session] {name}: {spec['tempo']} BPM {spec['meter']}, {spec['bars']} bars, {len(spec['tracks'])} track(s), {total} notes -> {afile}")
    try:
        if render_after:
            render(name, work / "cfg")
    finally:
        shutil.rmtree(work, ignore_errors=True)


def render(name, cfg=None, out=None):
    d = SESSIONS / name
    if not (d / f"{name}.ardour").exists():
        sys.exit(f"[session] no session {d}")
    wav = Path(out) if out else d / "export" / f"{name}.wav"
    wav.parent.mkdir(parents=True, exist_ok=True)
    own = cfg is None
    cfg = cfg or Path(tempfile.mkdtemp(prefix="music_session_cfg_"))
    r = subprocess.run([str(ARDOUR / "bin/ardour9-export.exe"), "-b", "24", "-o", str(wav), str(d), name], env=ardour_env(cfg),
                       capture_output=True, text=True)
    if own:
        shutil.rmtree(cfg, ignore_errors=True)
    if r.returncode or not wav.exists():
        sys.exit(f"[session] export failed:\n{(r.stdout + r.stderr)[-1500:]}")
    print(f"[session] rendered {wav}")
    analyze(wav, name)


def session_tempo(name):
    m = re.search(r'<Tempo npm="([\d.]+)"', (SESSIONS / name / f"{name}.ardour").read_text(encoding="utf-8"))
    return float(m[1]) if m else None


def analyze(wav, name):
    """A sanity read of the render: length, level, the pitch of the first note and whether the loudness repeats on the beat."""
    import numpy as np, soundfile as sf
    data, sr = sf.read(wav)
    mono = data.mean(axis=1) if data.ndim > 1 else data
    peak = float(np.abs(data).max())
    n = int(sr * 0.4)
    spec = np.abs(np.fft.rfft(mono[:n] * np.hanning(n), n=sr * 4))
    freqs = np.fft.rfftfreq(sr * 4, 1 / sr)
    band = (freqs > 25) & (freqs < 2000)
    f0 = freqs[band][np.argmax(spec[band])]
    db = 20 * np.log10(max(peak, 1e-9))
    out = f"[session] {name}: {len(mono) / sr:.3f} s, peak {db:.1f} dBFS{' (hot: lower the faders)' if db > -1 else ''}, strongest partial of the first note {f0:.1f} Hz"
    bpm = session_tempo(name)
    if bpm:
        win = int(sr * 0.03)
        env = np.convolve(np.abs(mono), np.ones(win) / win, mode="same")
        env -= env.mean()
        ac = np.correlate(env, env, "full")[len(env) - 1:]
        lo, hi = int(sr * 0.25), min(int(sr * 1.1), len(ac) - 1)
        if hi > lo and ac[0] > 0:
            lag = lo + int(np.argmax(ac[lo:hi]))
            if ac[lag] / ac[0] >= 0.8:  # only a clearly periodic render says something about the beat
                out += f", loudness repeats every {lag / sr:.3f} s (a beat at {bpm:g} BPM is {60 / bpm:.3f} s, strength {ac[lag] / ac[0]:.2f})"
    print(out)


def main():
    global SESSIONS
    ap = argparse.ArgumentParser(description="Build, render and open Ardour sessions from JSON specs")
    ap.add_argument("--sessions-dir", help="where sessions live (default ASSETS/AUDIO/MUSIC/SESSIONS)")
    sub = ap.add_subparsers(dest="cmd", required=True)
    b = sub.add_parser("build"); b.add_argument("spec"); b.add_argument("--force", action="store_true"); b.add_argument("--no-render", action="store_true")
    r = sub.add_parser("render"); r.add_argument("name"); r.add_argument("--out")
    o = sub.add_parser("open"); o.add_argument("name")
    a = ap.parse_args()
    if sys.platform != "win32":
        sys.exit("[session] this runs on the Windows PC workspace only")
    if a.sessions_dir:
        SESSIONS = Path(a.sessions_dir).resolve()
    if a.cmd == "build":
        build(a.spec, a.force, not a.no_render)
    elif a.cmd == "render":
        render(a.name, out=a.out)
    else:
        f = SESSIONS / a.name / f"{a.name}.ardour"
        if not f.exists():
            sys.exit(f"[session] no session {f}")
        subprocess.Popen([str(ARDOUR / "bin/Ardour.exe"), str(f)])


if __name__ == "__main__":
    main()
