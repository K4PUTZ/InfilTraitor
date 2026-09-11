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

| Access | URL | Use Case |
|--------|-----|----------|
| **Same WiFi (LAN)** | `http://<your-mac-ip>:8080` | Fast, low latency |
| **Any network (ngrok)** | `https://...ngrok-free.dev` | Remote testing, sharing |

**Find your Mac IP:**
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

The web preset has `thread_support=false`, so plain `http.server` works — no
cross-origin headers, no HTTPS needed on the LAN.

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