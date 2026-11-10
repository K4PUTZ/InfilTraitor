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

Last updated 2026-11-10.

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

### Open

- Author the three motifs, then ratify or replace the draft values in `bible.json`.
- Ardour is the chosen DAW but is not installed. The Director buys it at community.ardour.org/download (one payment; winget has no package).
- ACE-Step is not installed on the PC, so `music_generate.py` has only run here as far as its `acestep` import. It is needed only if generation happens here.

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
| Ardour | Not installed | DAW, see Open |

### Running the scripts on Windows

From the repository root:

```powershell
.venv\Scripts\pip install -r ASSETS\AUDIO\MUSIC\requirements.txt
.venv\Scripts\python tools\persistent\music_pipeline.py check
.venv\Scripts\python tools\persistent\music_pipeline.py list
.venv\Scripts\python tools\persistent\music_synth.py list Basses
.venv\Scripts\python tools\persistent\music_audition.py bass --n 12 --out <dir>
.venv\Scripts\python tools\persistent\music_arrange.py <out_dir>
```

Behaviour worth knowing:

- Surge XT lives under `%CommonProgramFiles%\VST3` and `%ProgramData%\Surge XT`. pedalboard refuses the `.vst3` bundle folder and loads the binary inside it, which is what `music_synth.py` points to.
- Text files (prompts, JSON) must be UTF-8, with or without a BOM. `register` stops on a prompt file in any other encoding, such as ANSI or UTF-16, and writes nothing.
- New exports are 44.1 kHz. FFmpeg's `loudnorm` would otherwise leave them at 192 kHz.
- Provenance records hold `/` paths and LF line ends on every OS.
- New OGGs under `Export/` are versioned. WAVs and `.import` files are not.

## Work history

Newest first. Every round of work on the PC adds an entry in the commit that closes it: what changed, what was verified, what stays open. When a round changes the picture above, Current state changes with it.

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
