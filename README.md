# INFILTRAITOR

Mobile turn-based stealth tactics / dungeon crawler prototype (Godot 4, portrait, grid-based).

## Source of truth

- Game plan: [DEVELOPMENT/GAME_PLAN.md](DEVELOPMENT/GAME_PLAN.md)
- Repo: https://github.com/K4PUTZ/InfilTraitor.git

Current prototype direction:

- Zelda-like top-down room-to-room dungeon flow on a square grid
- Turn-based tile interaction with 2 AP per turn
- Tap-to-select pathfinding and contextual actions
- Distinct 1 AP and 2 AP movement overlays inspired by X-COM readability
- Procedural floor generation from handcrafted room templates

## Project layout

- `infil-traitor/` — Godot project folder (open `project.godot`)
- `DEVELOPMENT/` — design + tooling
- `infiltraitor3d.html` — Three.js web prototype (standalone HTML)

## Development Operator

James (the local macOS development operator) has been moved to its own standalone repo:

- **Repo:** https://github.com/K4PUTZ/JAMES.git
- **Local path:** `../JAMES/` (peer directory)

James is project-agnostic and can automate any macOS development workflow. To use it with INFILTRAITOR, set `godot_project` in James's `config.ini` to point to this project's `infil-traitor/project.godot`.

Role split:

- James provides local eyes, ears, hands, logging, and task-state management.
- The LLM brain (GitHub Models / OpenAI) provides reasoning and task planning.

## Quick start

## VS Code setup (recommended)

This repo includes VS Code extension recommendations in [.vscode/extensions.json](.vscode/extensions.json).

Install at least:

```vscode-extensions
geequlim.godot-tools,alfish.godot-files
```

Then in VS Code settings, search for **Godot Tools** and set the **Editor Path** to your Godot executable.

macOS examples (depending on where you installed Godot):

- `/Applications/Godot.app/Contents/MacOS/Godot`
- `~/Downloads/Godot.app/Contents/MacOS/Godot`

### Godot (2D)

1. Install Godot 4.x.
2. Open the project at [infil-traitor/project.godot](infil-traitor/project.godot).

Notes:
- This repo ignores `.godot/` (editor cache) via `.gitignore`.

### Web prototype (Three.js)

Open [infiltraitor3d.html](infiltraitor3d.html) in a browser.

If your browser blocks ES module imports from `file://`, serve this folder with a tiny local server, for example:

- `python3 -m http.server` (then open `http://127.0.0.1:8000/infiltraitor3d.html`)

### Concept art generation (Stable Diffusion WebUI)

The scripts in [DEVELOPMENT/](DEVELOPMENT/) can generate concept images via the AUTOMATIC1111 SD WebUI API.

- Wrapper (recommended): [DEVELOPMENT/generate_art.sh](DEVELOPMENT/generate_art.sh)
- Generator: [DEVELOPMENT/generate_concept.py](DEVELOPMENT/generate_concept.py)

Expected SD WebUI location (auto-detected):
- Preferred: `../stable-diffusion-webui/` (sibling folder next to this repo)
- Also supported: `./stable-diffusion-webui/` (inside this repo)

Basic usage:

- Generate with defaults: `bash DEVELOPMENT/generate_art.sh`
- Custom prompt: `bash DEVELOPMENT/generate_art.sh --prompt "top-down tile grid, stealth game"`
- Check status: `bash DEVELOPMENT/generate_art.sh --status`
- Start SD server only: `bash DEVELOPMENT/generate_art.sh --start-sd`

Outputs are written to `DEVELOPMENT/concept_art/`.

## Contributing

Suggested workflow:

- `git checkout -b feature/<short-name>`
- commit changes
- push branch and open a PR
