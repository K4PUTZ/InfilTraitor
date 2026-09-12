## Mobile Testing — Local Server + ngrok

### Quick Start (Two Terminal Tabs)

**Tab 1: Local HTTP Server**
```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR/export/web"
python3 -m http.server 8080
```
→ Serves the web build on `http://localhost:8080`

**Tab 2: ngrok Tunnel**
```bash
ngrok http 8080
```
→ Creates a public HTTPS tunnel (look for `Forwarding:` line in output)

### Testing on Mobile

| Access | URL | Verdict |
|--------|-----|---------|
| **Any network (ngrok)** | `https://...ngrok-free.dev` | ✅ The only route that runs the game |
| **Same WiFi (LAN)** | `http://<your-mac-ip>:8080` | ⛔ Loads the page, refuses to RUN — see below |

⚠️ **THE LAN URL CANNOT RUN THE GAME, AND THE PAGE STILL LOADS** (measured
2026-09-12). Godot web requires a **secure context**, which is HTTPS *or*
`localhost` — never a LAN IP over `http://`. The phone shows:

```
The following features required to run Godot projects on the Web are missing:
Secure Context - Check web server configuration (use HTTPS)
```

So the HTTPS tunnel is not a convenience for remote testing; it is how a phone
runs this build at all. Two related traps: a phone browser silently upgrades a
typed IP to `https://`, which reaches the plain `http.server` as a TLS handshake
and is logged as `code 400, message Bad request version` — and if a server is
already on 8080 (a previous session's, or the agent's), a second one dies with
`Address already in use` while the first keeps answering fine.

**Find your Mac IP** (for anything other than running the game — the LAN route
above cannot satisfy the secure-context requirement):
```bash
ipconfig getifaddr en0
```

### Input on Mobile (FL-01+)

- **Single tap** → Select tile
- **Double tap** (same area, <300ms) → Move agent
- **One-finger drag** → Pan camera
- **Pinch** → Zoom (if configured)

### Stopping the Servers

```bash
# Kill Python server (check terminal or use Ctrl+C, or: pkill -f "http.server 8080")

# Stop ngrok (Ctrl+C in ngrok terminal)
```

**Note:** The web build at `export/web` must be re-exported from Godot if code changes. During development, use the Godot editor directly for faster iteration.

### Re-export from the CLI (≈35 s)

```bash
cd "/Volumes/Expansion/----- PESSOAL -----/PYTHON/INFILTRAITOR"
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --export-release "Web" export/web/index.html
```

The web preset has `thread_support=false`, so plain `http.server` is enough — no
`SharedArrayBuffer`, so no COOP/COEP cross-origin headers to configure.
⚠️ **That removes the HEADER requirement, NOT the HTTPS one.** Secure context is
required regardless of threads, so serve it through the ngrok tunnel for a phone;
`http.server` alone only works in a desktop browser on `localhost`.

### ⚠️ Three export traps, found 2026-09-11 (all fixed in `export_presets.cfg`)

`export_filter="all_resources"` packs every IMPORTED resource and nothing else, and
that was wrong three ways at once — the build still booted and looked like a game:

| symptom | cause | fix |
|---|---|---|
| only the code maps exist (PLAYGROUND fallback) — no GLASS, no RENDER_ORDER | `maps/*.map.json` have no `.import`, so they are not resources and were never packed | `include_filter="maps/*.json, …"` |
| the HUD shows raw keys (`ui.hud.ap_counter`) | `LocalizationManager` reads the raw `*.csv` with `FileAccess`; the CSVs were imported as `csv_translation`, so only the unused `.translation` products shipped — and an include filter cannot pull in an imported file | both `godot/localization/translations/*.csv.import` set to `importer="keep"` |
| `index.pck` 482 MB (APK 515 MB) | the 65 `ASSETS/TEXTURES/source/*_diffuse_2048.jpg` source textures, imported and unused at runtime | `exclude_filter="ASSETS/TEXTURES/source/*"` → 106 MB |

To see what a build REALLY contains, read the `.pck` index (GDPC v3: header, then
`dir_offset` → file count → `path_len, path, offset, size, md5[16], flags` per entry)
rather than trusting the preset — that is how all three were found.

⚠️ The web build runs the **Compatibility** (WebGL2) renderer, not the native
**Mobile** one: colour, lighting and cost can differ. For a device performance number
of the real target, use the Android APK (`EXPORT_ANDROID.md`).