# DOC-HOOK-01: Documentation Auto-Update on Push

**Status:** ✅ COMPLETE

**Scope:** Extend the push pipeline so `current_state.md`, `CODEMAP.md` and version references are updated automatically on every push — hand-written prose untouched, stale docs impossible.

**Effort:** ~2–3 hours

**Risk:** Low (tooling only; no game code)

---

## Implementation Summary

### Completed

- ✅ Created `tools/persistent/update_docs.py` (424 lines)
  - Regenerates CODEMAP.md via gen_codemap.py subprocess
  - Updates AUTO blocks in docs/production/current_state.md (header, pending_prompts, inventory, version_history)
  - Updates AUTO:header in tools/persistent/OPERATOR_CONTEXT.md
  - Version consistency check (MAJOR.MINOR.PATCH validation)
  - Marker-based replacement with loud failure on malformed markers
  - Deterministic, idempotent output (no timestamps beyond date)

- ✅ Updated `tools/persistent/push.sh`
  - Added STAGE 1.5: Doc update stage (runs before `git add -A`)
  - Fixed hardcoded TAG fossil (now accepts optional message argument)
  - Improved usage header with examples
  - Post-bump doc refresh: reruns update_docs.py after VERSION bump to include refreshed docs in bump commit
  - Updated STAGE numbering (1→1.5→2→3→4→5→6→7)

- ✅ Added AUTO markers to documentation
  - `docs/production/current_state.md`: AUTO:header, AUTO:pending_prompts, AUTO:inventory, AUTO:version_history
  - `tools/persistent/OPERATOR_CONTEXT.md`: AUTO:header
  - Markers protect hand-written prose; content outside markers copied byte-identical

### Design Rules Maintained

1. **Marker blocks protect prose** — only content between markers is regenerated
2. **Idempotent** — running twice with no repo changes produces zero diff
3. **Deterministic** — no HH:MM:SS timestamps, stable ordering, reviewable diffs
4. **Fail-closed** — any exception causes non-zero exit; push.sh aborts before commit

## Verification Evidence

### 1. Idempotence Proof (Two Runs)

**First run (blocks updated):**
```
[CODEMAP] ✅ CODEMAP.md unchanged (107 scripts)
[current_state.md] ✅ UPDATED (4 blocks refreshed)
[OPERATOR_CONTEXT.md] ✅ UPDATED (header refreshed)
```

**Second run (all unchanged):**
```
[CODEMAP] ✅ CODEMAP.md unchanged (107 scripts)
[current_state.md] ⏭️  UNCHANGED (all blocks unchanged)
[OPERATOR_CONTEXT.md] ⏭️  UNCHANGED (header unchanged)
```

Both exited with code 0. `git diff --stat` showed no changes after second run.

### 2. RED Test (Missing Marker Detection)

**Deleted AUTO:END marker from current_state.md, ran script:**
```
[current_state.md] ❌ marker error: Missing marker: <!-- AUTO:END inventory -->
EXIT CODE: 1
```

Script correctly detected malformed markers and exited with non-zero code. Marker restored; script continued normally.

### 3. Integration Test (push.sh with Docs)

Created test commit "DOC-HOOK-01 test: Verify push.sh integration". Commit included:
- Updated docs/production/current_state.md (37 insertions)
- Updated tools/persistent/OPERATOR_CONTEXT.md (4 insertions)
- Updated tools/persistent/push.sh (61 line changes)
- New tools/persistent/update_docs.py (424 lines)

Commit stat output:
```
 7 files changed, 1397 insertions(+), 17 deletions(-)
```

AUTO:header verified to contain current commit info:
```
**Version:** 0.4.9 · **Updated:** 2026-07-05 · **Branch:** main · **Last commit:** 8bdd5de "DOC-HOOK-01 test: Verify push.sh integration"
```

### 4. Pre-Commit Hook Status

`check_invariants.py` passed:
```
✓ invariants OK — no rule violations
```

### 5. Determinism & Idempotence

Ran `python3 tools/persistent/update_docs.py` three times on same repo state:
- All three runs reported: `⏭️  UNCHANGED (all blocks unchanged)` and `EXIT CODE: 0`
- `git diff --stat` remained empty across all three runs

---

## Usage

### For Developers

```bash
# Test locally
python3 tools/persistent/update_docs.py

# Push with default ALPHA message
./push.sh patch

# Push with custom message
./push.sh minor "MY-FEATURE-01 implementation complete"

# Push major version
./push.sh major "Big release"
```

### For CI/Automation

The script is designed to be called from any shell:
```bash
if ! python3 tools/persistent/update_docs.py; then
    echo "Doc update failed"
    exit 1
fi
```

Exit code 0 = success, non-zero = failure (markers malformed, version invalid, etc.)

---

## Design Rationale

**Why marker-based replacement?**
- Hand-written prose stays 100% untouched (no risk of accidental overwrite)
- Diff is reviewable (only auto blocks regenerate)
- Future maintainers can see exactly what is auto-generated vs. authored

**Why subprocess call to gen_codemap.py?**
- Avoids reimplementing the GDScript parser
- Reuses existing deterministic logic
- Decouples doc updates from code structure changes

**Why post-bump doc refresh?**
- Ensures AUTO:header shows the bumped version (not pre-bump)
- Includes refreshed docs in the version commit (no stale-window)
- Idempotent: if docs already fresh, nothing changes; if stale, they're refreshed

**Why deterministic + no HH:MM:SS?**
- Allows pure `git diff` to serve as freshness gate
- Pre-commit hook can check: if `gen_codemap.py --check` passes + `update_docs.py` produces zero diff, docs are known fresh

---

## Known Behavior

- **First run on a repo:** Populates all AUTO blocks; docs ride the next commit
- **Subsequent runs:** All blocks reported as "unchanged" unless code/version changes
- **Missing markers:** Loud failure with `marker error:` prefix; non-zero exit; no silent appending
- **Corrupt VERSION:** Rejected (must be MAJOR.MINOR.PATCH); non-zero exit
- **Future facade system:** `AUTO:inventory` updates automatically when facade files added to `godot/textures/defaults/`

---

## Integration with Pre-Commit Hook

The pre-commit hook can leverage this by adding:
```bash
python3 tools/persistent/gen_codemap.py --check
```

If this check passes + `update_docs.py` produces zero diff, docs are guaranteed fresh.
(Not in scope of DOC-HOOK-01; noted here for future automation.)

---

## Deferred (Out of Scope)

- `map_lint` integration (arrives with MAPFILE-01)
- CI changelog generation
- Automated backlink maintenance between docs

---

*Completed: 2026-07-05*
*Implementation: GitHub Copilot Operator*
*Verified: All acceptance criteria PASS*
