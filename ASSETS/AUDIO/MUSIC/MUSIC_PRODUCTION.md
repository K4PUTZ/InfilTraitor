# INFILTRAITOR music: production record

The dedicated document for the state of the music and the work done on the Windows PC. It records status, decisions and history, and does not restate the sources of truth:

| Source | Holds |
|---|---|
| `INFILTRAITOR_Music_Authorship_Project_Paper.pdf` | Artistic intent, thematic system, AI and rights policy |
| `bible.json` | The Music Bible: tonal centre, BPM, motifs, the seven gameplay contexts |
| `arrangement.json` | The arrangement of one context: Surge XT presets, entries, gains |
| `provenance/<take-id>.json` | Each take's tool, licence, prompt, parameters and hashes |
| `README.md` | Folder policy and the pipeline's commands |

## Current state

Last updated 2026-11-12.

### Composition

| Item | State |
|---|---|
| Motifs (Agent, Threat, Mission) | Not authored, `pending` in `bible.json` |
| Tonal centre, harmonic and timbral DNA | Draft defaults from the paper's example, waiting for the Director to ratify or replace them |
| Full theme (paper §5) | No take yet. `THEME/` holds only the prototype reference, `Black Tux Pulse.mp3` |
| Gameplay contexts | Seven defined in `bible.json`, only `infiltration` has takes |
| `infiltration` timbres | Chosen by the Director on 2026-10-19: `Basses/Bass 5`, `Plucks/Tinker`, `Pads/Primes`, `Leads/Scooped` |
| `infiltration` notes | Placeholder phrases in `music_arrange.py` (A minor, 4-bar loop) until the motifs exist |

Paper §12 makes a complete Music Bible the step before any final audio. Still missing from `bible.json` against its list: the exact leitmotifs, the rhythmic engine and the structural timeline.

### Takes

All three were made on the Mac, and none yet on the PC. `music_pipeline.py check` passes on them here. Their raw WAVs and stems are in `Raw/` on the Mac only, and their exports predate the 44.1 kHz fix, so they stay at 192 kHz.

| Take | Made with | Length | Notes |
|---|---|---|---|
| `infiltration-20261018-7902a26a` | `music_beat.py` | 16.484 s | Placeholder beat, mono export |
| `infiltration-20261018-030bbd95` | ACE-Step 1.5 turbo | 30.0 s | First AI take, licence still to verify before release |
| `infiltration-20261019-87d9d018` | `music_arrange.py` + Surge XT 1.3.4 | 32.968 s | First 4-line arrangement, Director-picked timbres, placeholder notes |

### Sessions

The Director asked on 2026-11-12 for pieces generated one at a time and arranged on a shared tempo and meter, on a timeline to play, reorder, copy and paste. The method (README, "Sessions") is in place: an Ardour session per spec, one track per line, MIDI clips played by Surge XT. Ardour's window has not been opened on the PC yet; what was checked is the saved file and a headless render.

| Session | Grid | Lines | State |
|---|---|---|---|
| `bassline-e1` | 120 BPM, 4/4, 4 bars | `Bass`: Surge XT `Basses/Bass 5` at -6 dB, one clip of E1 (MIDI 28) quarter notes, 0.9 beat long, velocity 100 | First experiment. `Bass 5` is the patch the Director picked for `infiltration`, reused as a starting timbre; the instrument and timbre are still to be chosen |

### Open

- Author the three motifs, then ratify or replace the draft values in `bible.json`.
- Choose the instrument and timbre of the bass line (the Director's search), then change the spec's `patch` or the plugin.
- Open `bassline-e1` in Ardour and confirm it plays as the headless render did.
- Audio clips on the same grid (ACE-Step samples cut to whole bars, for the drums and effects) are not built: `music_session.py` places MIDI clips only.
- `music_generate.py`, the Bible-driven take, has not run here yet. `music_sample.py` has.

## PC workspace

`D:\INFILTRAITOR-PC` holds the music only, and the rest of the project stays on the Mac. The composition here is independent of the Mac (Director, 2026-11-09: "Nada daqui vai ser executado no Mac, vamos trabalhar a composição de forma independente").

### Repository

- Branch: `feat/music-composition`, on GitHub. It reaches `main` only when the Director orders a merge, a deliberate exception to the project's work-on-`main` rule (Director, 2026-11-10).
- Clone: blobless and sparse (non-cone), with only `/.gitignore`, `/ASSETS/AUDIO/` and `/tools/persistent/music_*.py` checked out, and `core.autocrlf=false`. It fetches only `main` and this branch.
- Not here: the root docs (read them with `git show origin/main:CLAUDE.md`), the hooks, and `Raw/`.
- No pre-commit or pre-push hook runs here. The gates that can block on `main` only look at GDScript and `hud.tscn`, so a music commit loses only the refresh of the docs' AUTO headers.
- A filename Windows cannot hold, anywhere in a commit being checked out, breaks the checkout even outside the sparse set. Rename it at the source; `core.protectNTFS` stays on.

### Tools

| Tool | Version | Used for |
|---|---|---|
| Python, project `.venv` at the repository root | 3.14.10 | The music scripts, dependencies in `requirements.txt` |
| pedalboard | 0.9.26 | Hosts Surge XT from Python |
| Surge XT | 1.3.4 | Synthesizer and factory presets |
| FFmpeg | 9.0.2 | Duration probes and the loudness-normalised export |
| Audacity | 4.0.2 | Audio editing |
| MuseScore Studio | 4.7.6 | Notation |
| Git | 2.56.0 | Version control |
| Poppler | 25.07.0 | Reading the paper's PDF |
| Ardour | 9.10.0 | DAW, and the engine `music_session.py` drives headless. Surge XT was indexed with `ardour-vst3-scanner`, which wrote Ardour's plugin cache under `%LOCALAPPDATA%\Ardour9\cache` |
| uv | 0.13.7 | Runs ACE-Step's environment |
| ACE-Step | 1.5 turbo, `D:\ACE-Step` (outside the repository) | Loose samples through `music_sample.py`. MIT code and weights. Own environment (Python 3.11), 9.4 GB of weights under `checkpoints` |

### Running the scripts on Windows

From the repository root:

```powershell
.venv\Scripts\pip install -r ASSETS\AUDIO\MUSIC\requirements.txt
.venv\Scripts\python tools\persistent\music_pipeline.py check
.venv\Scripts\python tools\persistent\music_pipeline.py list
.venv\Scripts\python tools\persistent\music_synth.py list Basses
.venv\Scripts\python tools\persistent\music_audition.py bass --n 12 --out <dir>
.venv\Scripts\python tools\persistent\music_arrange.py <out_dir>
.venv\Scripts\python tools\persistent\music_session.py build ASSETS\AUDIO\MUSIC\SESSIONS\<name>.spec.json
.venv\Scripts\python tools\persistent\music_session.py render <name>
```

Samples run from ACE-Step's environment instead (command in the README, "Loose samples for listening").

Behaviour worth knowing:

- `music_session.py` holds Ardour's MCP port (4820) while it builds, so run one build at a time, with no Ardour window that has its MCP surface on.
- A Surge XT state written into an Ardour session is the `.fxp`'s `sub3` chunk alone. With JUCE's trailing `JUCEPrivateData` marker added, Surge crashes when the session loads or exports (tested).
- Python's `write_text` on Windows turns LF into CRLF. The repository is LF (`core.autocrlf=false`), so write bytes or pass `newline="\n"`.
- Surge XT lives under `%CommonProgramFiles%\VST3` and `%ProgramData%\Surge XT`. pedalboard refuses the `.vst3` bundle folder and loads the binary inside it, which is what `music_synth.py` points to.
- Text files (prompts, JSON) must be UTF-8, with or without a BOM. `register` stops on a prompt file in any other encoding, such as ANSI or UTF-16, and writes nothing.
- New exports are 44.1 kHz. FFmpeg's `loudnorm` would otherwise leave them at 192 kHz.
- Provenance records hold `/` paths and LF line ends on every OS.
- New OGGs under `Export/` are versioned. WAVs and `.import` files are not.

## Work history

Newest first. Every round of work on the PC adds an entry in the commit that closes it: what changed, what was verified, what stays open. When a round changes the picture above, Current state changes with it.

### 2026-11-12: Ardour sessions, loose samples and the first bass line

Done:
- Checked Ardour 9.10.0, installed by the Director. Its plugin list lacked Surge XT until `ardour-vst3-scanner` indexed it, which wrote one cache file under `%LOCALAPPDATA%\Ardour9\cache\vst`, Ardour 9's user cache, so the window should list Surge XT too (not opened to confirm).
- Installed `uv` (winget) and cloned ACE-Step 1.5 (`ca1e85f`) to `D:\ACE-Step`, outside the repository, with its own environment: 7.2 GB of environment plus 9.4 GB of weights that came down on the first generation, about 16.6 GB on `D:` (the estimate given before installing was 10 GB).
- Added `tools/persistent/music_sample.py`: a free prompt becomes loose samples in `ASSETS/AUDIO/SAMPLES/` (the root `.gitignore` already ignores the folder), each with a `.json` of prompt and seed. On GPUs under 10 GiB it keeps the models in RAM between steps.
- Added `tools/persistent/music_session.py` and `ASSETS/AUDIO/MUSIC/SESSIONS/`, the timeline method (README, "Sessions"): a JSON spec becomes an Ardour session with one track per line, MIDI clips on a shared tempo and meter, Surge XT with a factory patch, and a loop range over the whole length. Ardour 9.10 ships an MCP HTTP surface; the script runs `ardour9-lua` headless, starts that surface, drives it, then writes the Surge patch into the saved plugin state.
- Built `bassline-e1`, the Director's first step: E1 quarter notes, 120 BPM, 4/4, 4 bars, `Basses/Bass 5` at -6 dB.
- Wrote the README sections "Sessions" and "Loose samples for listening", and updated this record.

Verified, all on Windows:
- Samples: the first sample (12 s, low bass with a galloping kit, E minor, 140 BPM) was generated. The second take of that run failed the VRAM pre-flight (0.7 GB free, 0.8 GB needed), and `empty_cache` did not change it. With the models offloaded, two 10 s takes ran in one 111 s run.
- Session build: all 16 notes were read back from Ardour and matched the spec. A copy of the saved session, loaded fresh, reported 120 BPM, track `Bass`, region `E1 quarters` from 1|1|0 to 5|1|0, 16 notes of pitch 28 at velocity 100.
- Headless render of the saved session (`ardour9-export`): 8.000 s, peak -6.3 dBFS, strongest partial of the first note 39.8 Hz (E1 is 41.2 Hz), loudness repeating every 0.500 s with strength 0.93.
- A throwaway spec at 90 BPM and 3/4, with two tracks and a clip starting at bar 2, came out with the right tempo, meter and 12-beat range. Building over an existing session refused, and `--force` moved it aside.
- Patch: after Ardour loaded the saved session and saved it again, Surge's state held all 571 parameters of `Basses/Bass 5.fxp` with no difference, and the patch name inside is `Bass 10` (the factory file name and the name Surge shows differ). The Ardour render and a pedalboard render of the same notes at 48 kHz and 0.9 beat agree to 0.08 dB RMS over the first 30 harmonics of E1. Two Ardour builds of the same spec rendered identically.
- `music_pipeline.py check` passes.

Not verified:
- Ardour's window was never opened on the PC: the timeline, the audio device and the sound through it are untested, and nothing was heard by ear on this side.
- `music_generate.py` has not run on Windows.

Found on the way:
- A Surge state carrying JUCE's `JUCEPrivateData` marker makes Surge crash when the session loads (exit code 0xC0000005), and `ardour9-export` crashes on it too. The same state without the marker loads.
- A saved session records the MCP surface as active, so every opening would listen on port 4820 on all network interfaces. The build switches it off.
- The same patch renders differently at 44.1 kHz and at 48 kHz: 4.9 dB RMS over the same 30 harmonics at equal note length. `music_audition.py` and `music_synth.py` render at 44.1 kHz, Ardour sessions run at 48 kHz, so a timbre heard in an audition can sound a little different in a session.

### 2026-11-10: the composition gets its own branch and this record

Done:
- Created `feat/music-composition` on GitHub and sent the UTF-8 fix (`324929ac`) only there. `main` on GitHub stayed at `4516234f`. The reasons: the Mac pushes to `main` often, experiments stay out of its public history until approved, and a filename Windows cannot hold on `main` no longer blocks this work.
- Wrote this document and linked it from `README.md`.

### 2026-11-09: PC workspace set up, pipeline fixed for Windows

Done:
- Cloned only the audio part of the repository. `DIAGRAMS/PROBLEM?.psd`, a name Windows cannot hold, blocked the checkout, and the Director renamed it on the Mac (`83134d56`).
- Installed the tools listed above and created the `.venv`. Chose Ardour as the DAW after confirming it has a one-time payment.
- `e740d6be` made the pipeline work on Windows:
  - Surge XT's paths per OS, and preset names with `/` on every OS.
  - `music_audition.py` defaults to a folder under the home directory and creates it.
  - Provenance records with `/` paths and LF line ends.
  - Exports at 44.1 kHz instead of the 192 kHz `loudnorm` left behind.
  - `.gitignore` versions new OGGs in `Export/`, which a later `*.ogg` rule was hiding.
  - `pedalboard` added to `requirements.txt`.
- `324929ac` made every text read in the music scripts name UTF-8. Python's default on Windows is the ANSI code page, which garbled accented prompts on their way into provenance and crashed on some bytes.
- The Director ruled that nothing made here will be executed on the Mac.

Verified, all on Windows:
- `music_synth.py` (`list`, `render`), `music_audition.py` and `music_arrange.py` ran unmodified. `music_arrange.py` wrote five stems and the mix at 32.968 s, the length of the Mac's take.
- In a throwaway copy of the repository, `register`, `stems`, `export` and `check` all passed, and the test export came out as 44.1 kHz stereo Vorbis.
- Accented and BOM input through `music_pipeline.py`, `music_beat.py`, `music_synth.py` and `music_arrange.py`: 3 of 20 cases passed before `324929ac`, 20 of 20 after.

Not verified: `music_generate.py` beyond its `acestep` import, because ACE-Step is not installed here.
