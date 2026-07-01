# INFILTRAITOR — Localization System Reference

> **i18n setup, TranslationServer integration, and localization workflow.**

All player-facing text goes through Godot's `TranslationServer`. The `LocalizationManager` autoload parses per-domain CSV sources at boot, builds one `Translation` per locale, and registers them, so `tr("domain.key")` works engine-wide with O(1) lookup — mobile-friendly.

---

## Architecture

```
godot/localization/translations/*.csv   ← human-editable source (spreadsheet-friendly)
   │   header row:  keys, en, pt_BR, es, ...
   │   column 0:    semantic key   (e.g., ui.hud.ap_counter)
   │   empty cell:  falls back to default_locale ("en")
   ▼
LocalizationManager._ready()
  ├─ parse CSV → Translation per locale
  ├─ TranslationServer.add_translation()
  └─ emit language_changed signal
   ▼
tr("ui.hud.ap_counter")  →  "AP %d/%d"  (current locale, else fallback "en")
```

---

## LocalizationManager API

Singleton: `Localization` (autoload in `project.godot`)

### Setting Language

```gdscript
Localization.set_language(locale: String) -> void
    ## Switch to locale, persist to user://settings.cfg, emit language_changed
    ## Example: Localization.set_language("pt_BR")

Localization.cycle_language() -> void
    ## Rotate through supported_locales
    ## Example usage: room debug key K

Localization.get_language() -> String
    ## Returns current locale code (e.g., "en", "pt_BR")

Localization.get_supported_locales() -> PackedStringArray
    ## Returns ["en", "pt_BR", "es", ...]

Localization.get_language_endonym(locale: String) -> String
    ## Returns language name in its own language
    ## Example: get_language_endonym("pt_BR") → "Português"

signal language_changed(locale: String)
    ## Emitted when language changes via set_language()
```

### Accessing the Singleton

The autoload registers the global name `Localization`, but that global is only indexed by the editor LSP after a project reload. To stay error-free, fetch it by tree path:

```gdscript
var loc: Variant = get_node_or_null("/root/Localization")
```

Plain `tr("key")` needs no reference — only locale switching and signal wiring do.

---

## CSV Format & Key Convention

### Semantic, Dotted, Stable Keys

Key convention: `{domain}.{section}.{name}`

```
keys,en,pt_BR,es
ui.hud.ap_counter,"AP %d/%d","PA %d/%d","%d PA"
ui.banner.busted,"Mission Failed","Missão Falhada","Misión Fallida"
dialogue.intro.line_01,"Proceed carefully","Prossiga com cuidado","Proceda con cuidado"
```

**Principles:**
- Keys are **semantic** and **stable** — editing source text never changes the key
- One CSV file per domain (e.g., `ui.csv`, `dialogue.csv`)
- Each file listed in `LocalizationManager.SOURCE_FILES`
- Missing cells fall back to English (`en`) automatically

### CSV Structure

```
Header: keys,en,pt_BR,es,fr,...
Row 1:  ui.hud.ap_counter,"value","Valeur","Valor","Valeur"
Row 2:  ui.banner.busted,"Mission Failed",...
```

**Column 0 = Key** (never translated)  
**Columns 1+ = Locale translations** (in order matching `supported_locales`)

---

## Adding a String

1. Identify the domain (ui, dialogue, narrative, etc.)
2. Add a row to the appropriate CSV in `godot/localization/translations/`:
   ```
   ui.hud.new_button,"Button Label","Rótulo do Botão","Etiqueta de Botón"
   ```
3. Reference it in code:
   ```gdscript
   var text = tr("ui.hud.new_button")
   ```
4. **Or** set a `Control`'s text to the key and let Godot auto-translate it (static labels)

---

## Adding a Language

1. Add a column to every CSV with the locale code (e.g., `it` for Italian):
   ```
   keys,en,pt_BR,it
   ui.hud.ap_counter,"AP %d/%d","PA %d/%d","PA %d/%d"
   ```
2. Append the locale code to `LocalizationManager.supported_locales`:
   ```gdscript
   supported_locales = ["en", "pt_BR", "it"]
   ```

**Missing cells:** automatically fall back to English (`en`).

---

## Live Refresh on Locale Change

Controllers that build text in code should cache their last values and rebuild on `language_changed`:

```gdscript
func _ready() -> void:
    Localization.language_changed.connect(_on_language_changed)
    _on_language_changed(Localization.get_language())

func _on_language_changed(locale: String) -> void:
    label.text = tr("ui.hud.ap_counter") % [ap_current, ap_max]
```

Static `Control` text (`Label`, `Button`) re-translates automatically on locale change.

---

## Source CSV Files

Each domain has one canonical CSV file. Example structure:

```
godot/localization/translations/
├── ui.csv           # HUD, buttons, menus
├── dialogue.csv     # NPC/guard dialogue
├── narrative.csv    # Story text
└── system.csv       # Game messages, notifications
```

List all source files in `LocalizationManager.SOURCE_FILES`:

```gdscript
const SOURCE_FILES = [
    "res://godot/localization/translations/ui.csv",
    "res://godot/localization/translations/dialogue.csv",
    ...
]
```

---

## What Is NOT Localized

**Developer tools & debug content:**
- DEV_VISION guard labels (id, state, cell, facing, last_known)
- Tile hover panel (coordinates, blocked, light class, risk, shadow stats)
- LIGHT_VISION labels (light intensity, shadow depth, exposure class)
- HEAT_VISION labels (exposure, risk, elite status)

**Symbolic UI:**
- Compass (N/S/E/W)
- Dev buttons and key labels
- Technical console output

These remain **in English** for now. Future expansion: locale-variant resolution for sprites with baked text and dubbed audio.

---

## Future Extension Points (Documented, Not Built)

### Dialogues
New `dialogue.csv` domain (or structured dialogue resource that resolves lines through `tr()`).

### Sprites with Baked Text
Locale-variant asset resolver keyed off `Localization.get_language()`:
```
…/<asset>.<locale>.png
```
Example:
```
res://assets/intro_title.en.png
res://assets/intro_title.pt_BR.png
res://assets/intro_title.es.png
```

### Dubbed Audio
Same locale-variant resolution for voice streams:
```
res://audio/dialogue/<key>.<locale>.ogg
```

---

## Related Documentation

- **OPERATOR_CONTEXT** — Development handbook
- **ARCHITECTURE.md** — High-level system relationships
- Godot [TranslationServer docs](https://docs.godotengine.org/en/stable/classes/class_translationserver.html)
