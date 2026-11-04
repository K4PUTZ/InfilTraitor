## Mobile Testing

The phone test is the release APK (Director, 2026-09-23): `tools/persistent/export_android.py` → `device_run.py` / `device_record.py`, flags through `dev_flags.cfg`. Setup: `EXPORT_ANDROID.md`. The web + ngrok flow left on 2026-11-04 with the Web preset; it is in git history.

### Input on Mobile (FL-01+)

- **Single tap** → Select tile
- **Double tap** (same area, <300ms) → Move agent
- **One-finger drag** → Pan camera
- **Pinch** → Zoom (if configured)

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
rather than trusting the preset — that is how all three were found. `tools/persistent/apk_audit.py` does it for an APK.

---
**Recording the game on a handset:** `python3 tools/persistent/device_record.py --device <serial> --preset blast --out temp/videos/<name>.mp4` — see `docs/pipelines/device_video_recording.md`.
