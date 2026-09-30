# Developer Setup & Authentication Guide

> **How to set up development environment, authentication, and access to external resources.**

---

## Day-to-day workflow (added 2026-09-30)

```bash
# open the project (the editor stays open while you work; GDScript hot-reloads)
/Applications/Godot.app/Contents/MacOS/Godot --path . 2>/dev/null &

# verify before declaring anything done: ONE command, in tiers, failing fast
python3 tools/persistent/verify.py            # picks docs / quick / smoke from the changed files
python3 tools/persistent/verify.py smoke      # lint + invariants + codemap + selftests + a boot of PLAYGROUND and GLASS (the default for code under godot/)
python3 tools/persistent/verify.py full       # + the identity gates: ONLY when asked, or to close a stage that rewires the board/state/light/ground
python3 tools/persistent/verify.py --baseline # take this at the START of a task that will need `full`
```
- The **boot gates refuse to start while any other Godot is alive, the editor included** (`smoke` does not care). Close the editor for `full`.
- Git hooks (`.git/hooks/pre-commit`, `pre-push`, sources in `tools/persistent/hooks/`) run invariants, the codemap freshness check and the lint; never bypass them. A commit can still pass with a failing selftest: run `verify.py smoke` before committing code.
- A capture or probe always names its map: `INFILTRAITOR_MAP=PLAYGROUND|PROPS|GLASS` (without it the LAST map used opens). Scenarios: `INFILTRAITOR_SCENARIO="framing portrait; frames 60; detonate 0; frames 400; capture name; quit"`.
- **A phone test is the release APK:** `python3 tools/persistent/export_android.py --install`, then `device_run.py --device <serial> --seconds N` (logs) or `device_record.py` (video). Flags reach the APK only through `dev_flags.cfg` (`DevFlags`). The Android SDK is at `/opt/homebrew/share/android-commandlinetools` (`adb` in `platform-tools/`). Guide: [`../../tools/persistent/MobileTesting.md`](../../tools/persistent/MobileTesting.md), [`../../EXPORT_ANDROID.md`](../../EXPORT_ANDROID.md).
- New textures, decals and models follow the checkers: `check_facade.py`, `check_decal.py`, `check_surface.py` (a colored or un-imported facade is rejected with no error at all). A new PNG/GLB in a folder Godot has not scanned needs `godot --headless --path . --import`.

---

## SSH Authentication

### SSH Keys for GitHub Access

**Status:** ✅ SSH Key Configured (Ed25519)

Your SSH key is stored in: `~/.ssh/id_ed25519`

**Key Information:**
```
Type:          Ed25519 (secure, modern)
Fingerprint:   SHA256:t+kFDgLjfbkEdoO/FY6aU+g4fCzIQuigbajV6/ryEpI
Email:         emaildomat@gmail.com
Added to:      macOS Keychain
Repository:    git@github.com:K4PUTZ/InfilTraitor.git
```

### Testing SSH Connection

```bash
ssh -T git@github.com
```

**Expected response:**
```
Hi K4PUTZ! You've successfully authenticated, but GitHub does not provide shell access.
```

If authentication fails:
- Verify key is in `~/.ssh/id_ed25519`
- Check it's added to macOS Keychain: `ssh-add -l`
- Verify GitHub SSH key settings: https://github.com/settings/keys

---

## Git Configuration

### User Information (Already Set)

```bash
# Your git config
user.name:  K4PUTZ
user.email: emaildomat@gmail.com
```

### Remote Configuration

```bash
# Repository remote
origin: git@github.com:K4PUTZ/InfilTraitor.git (SSH)
```

---

## Large Files Management

### Why Some Files Aren't in Git

GitHub recommends files under 50 MB. This project has design assets larger than that:

**Removed from Repository:**
- `DEVELOPMENT.archive/Concept/MAPs.psd` (71 MB) — Design reference file
- Other large binaries: `.psd`, `.psb`, `.ai`, `.mov`, `.mp4`, `.wav`, `.flac`

**Why:** Large binary files bloat the repository and make cloning slow.

### Storing Large Files

**Options:**

#### Option 1: Local Storage (Recommended for Solo Dev)
- Store design files in `DEVELOPMENT.archive/Concept/` locally
- Do NOT commit to git (already in .gitignore)
- Document references in README or issue tracker

#### Option 2: Google Drive / Cloud Storage
- Upload to shared Google Drive
- Reference in: `docs/technical/ASSET_MAP.md`
- Add access link to project wiki or README

#### Option 3: Git LFS (Large File Storage)
For future projects with many large files:
```bash
# Install Git LFS
brew install git-lfs

# Configure for .psd files
git lfs track "*.psd"

# Then commit normally
git add .psd file
git commit -m "Add large design asset"
```

---

## .gitignore Rules

### Current Ignored Patterns

```
# Backup artifacts
BACKUP.ZIP
BACKUP_*.ZIP

# Large binary files (not for version control)
*.psd      # Photoshop
*.psb      # Photoshop Large
*.ai       # Illustrator
*.mov      # Video
*.mp4      # Video
*.wav      # Audio
*.flac     # Audio

# Godot-generated
.godot/
export/
build/

# Python cache
__pycache__/
*.pyc
.pytest_cache/

# System files
.DS_Store
.vscode/
*.swp
*.swo

# Local archives (558 MB)
ARCHIVE/
```

### Important

If you accidentally commit a large file:

```bash
# Remove from current commit only
git rm --cached path/to/file.psd

# Commit the removal
git commit -m "Remove large file from git"

# To permanently remove from history (dangerous!)
git filter-branch --tree-filter 'rm -f path/to/file.psd' HEAD
```

---

## Backup & External Storage

### Project Backups

**Automatic Backup Script:**
```bash
python3 tools/persistent/BACKUP.py
```

Creates: `BACKUP_YYYY-MM-DD_HHMM.ZIP` (excludes ASSETS, ARCHIVE, .git)

**Location:** Repository root  
**Size:** ~0.76 MB (code only, no assets)

### Design Archives

**Store Externally:**
- Concept art (.psd, .ai, .mov)
- Marketing assets
- Old prototypes

**Reference in:**
- `DEVELOPMENT.archive/Concept/` (local only)
- Linked in: `docs/technical/ASSET_MAP.md`

---

## First-Time Setup Checklist

- [ ] Clone repository
- [ ] Verify SSH: `ssh -T git@github.com`
- [ ] Verify git config: `git config --global --list`
- [ ] Read: [Game Vision](../vision/game_vision.md)
- [ ] Read: [Systems Architecture](../systems/)
- [ ] Check: [Current State](../production/current_state.md)
- [ ] Install Godot 4.6+ (if contributing to game)
- [ ] Install Python 3.9+ (if contributing to tools)
- [ ] Run test suite: `pytest -q` (if in Python workspace)

---

## Troubleshooting

### Push fails with "Permission denied"

**Problem:** `git@github.com: Permission denied (publickey)`

**Solution:**
1. Check SSH key exists: `ls -la ~/.ssh/id_ed25519`
2. Test connection: `ssh -T git@github.com`
3. If test fails, key not added to GitHub:
   - Copy public key: `cat ~/.ssh/id_ed25519.pub`
   - Add to GitHub: https://github.com/settings/keys
   - Test again: `ssh -T git@github.com`

### Pull/Push is slow

**Problem:** Repository is large (~100 MB after full history)

**Cause:** Large binary files in history

**Solution:**
- Remove large files before committing
- Use `.gitignore` for design assets
- Consider Git LFS for future large files

### Can't find a file

**Problem:** "Couldn't find file — it should be here!"

**Likely Cause:** File is in `.gitignore` or `DEVELOPMENT.archive/`

**Solution:**
- Check `.gitignore` for pattern
- Look in `DEVELOPMENT.archive/` for archived items
- Check git history: `git log --all --full-history -- file.psd`

---

## References

- [Repository Structure](repo_structure.md) — Where files belong

---

**Last Updated:** 2026-06-12  
**Maintainer:** DevOps Lead  
**Status:** ✅ SSH Configured  
**Next:** See [Getting Started](../vision/game_vision.md)
