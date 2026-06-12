# Archive & Cleanup Policy

> **Rules for archiving, deprecating, and deleting code and assets.**

---

## Purpose

Establish clear, repeatable processes for managing:
- Code that's no longer needed
- Assets that aren't used
- Documentation that's outdated
- Infrastructure that's redundant

**Goal:** Prevent accumulation of "dead code" while preserving valuable historical information.

---

## Core Principles

### 1. Never Delete Without Understanding Why

❌ **BAD:** Delete a script because it looks old  
✅ **GOOD:** Archive it with documentation of why

### 2. Archive First, Delete Later

❌ **BAD:** Delete immediately  
✅ **GOOD:** Archive for 1 sprint, then evaluate for deletion

### 3. Preserve Historical Context

❌ **BAD:** Lose information about why something was done  
✅ **GOOD:** Document the migration/removal decision

### 4. Ownership & Approval

❌ **BAD:** Individual contributor deletes code  
✅ **GOOD:** Team consensus + owner approval

---

## Classification System

All code/assets fall into one of five states:

```
ACTIVE
  ↓ (no longer needed)
DEPRECATED
  ↓ (prepare for removal)
ARCHIVED
  ↓ (kept as reference)
DELETED
  ↓ (gone forever)
```

---

## State Definitions

### ACTIVE ✅

**Characteristics:**
- Currently used in production
- Maintained and tested
- Part of official codebase
- Someone owns it

**Duration:** Indefinite

**Action:** None (keep working on it)

---

### DEPRECATED ⚠️

**Characteristics:**
- No longer recommended
- Has better alternative available
- Still functional but discouraged
- Clear replacement documented

**Examples:**
- Old API replaced by new one
- Inefficient algorithm with better version
- Outdated documentation
- Redundant tools

**Duration:** 1-2 sprints (visible warning period)

**Action:**
1. Add deprecation notice to code/docs:
   ```python
   """
   DEPRECATED: Use new_thing() instead
   Removed in: Sprint X
   """
   ```
2. Update documentation with alternative
3. Notify users (CHANGELOG, docs)
4. Give 1-2 sprint warning period

---

### ARCHIVED 📦

**Characteristics:**
- Moved from active location
- Preserved for reference/recovery
- Not imported/used by active code
- Historical value only

**Examples:**
- Old migration scripts
- Superseded algorithms
- Experimental features
- Legacy asset formats

**Duration:** Indefinite (until explicitly deleted)

**Location:** 
- Code: `tools/archive/`, `docs/history/`
- Assets: `ARCHIVE/` (gitignored)

**Action:**
1. Move to archive folder with reason
2. Create README.md explaining why
3. Leave git history intact
4. Document dependencies

---

### DELETED 🗑️

**Characteristics:**
- Completely removed
- No recovery path (except git history)
- Space reclaimed
- No longer accessible

**Examples:**
- Build artifacts
- Temporary debugging code
- Accidentally committed files
- Spam

**Duration:** Only after archival + waiting period

**Prerequisites for Deletion:**
1. ✅ Archived (if valuable)
2. ✅ 1+ sprint review period
3. ✅ Owner + lead approval
4. ✅ Confirmed no dependencies
5. ✅ Git history available (if needed rollback)

---

## Decision Matrix

**Should this code/asset be archived, deprecated, or deleted?**

| Question | Archive | Deprecate | Delete |
|----------|---------|-----------|--------|
| Is it actively used? | No | Partially | No |
| Will it be useful later? | Yes | Maybe | No |
| Is there a replacement? | Maybe | Yes | Yes |
| Has anyone asked to keep it? | Yes | Yes | No |
| Does it affect repo size? | No | No | Maybe |
| Is it test artifact? | No | No | Yes |

**Score:** If Archive column > others → Archive  
If Deprecate > others → Deprecate  
If Delete > others → Delete

---

## Workflow: Archiving Code

### Step 1: Identify
- Determine if code is still needed
- Check for remaining usages
- Verify replacement exists

### Step 2: Notify
- Add deprecation notice
- Update documentation
- Inform team (Slack, sprint notes)

### Step 3: Wait
- Allow 1-2 sprints for team awareness
- Collect feedback
- Resolve any last-minute uses

### Step 4: Archive
```bash
# For scripts
mv old_script.py tools/archive/

# For docs
mv old_doc.md docs/history/deprecated/

# For assets (already in ARCHIVE/)
# Just remove from active location
```

### Step 5: Document
Create README.md explaining:
- Why archived?
- When was it active?
- What replaced it?
- How to recover?

### Step 6: Commit
```bash
git add .
git commit -m "Archive: Move [thing] to tools/archive/ (replaced by [new_thing])"
```

---

## Workflow: Deprecating Code

### Step 1: Identify Replacement
Before deprecating, ensure better alternative exists

### Step 2: Add Deprecation Notice
```python
# Example: Function
@deprecated("Use new_function() instead. Removed in Sprint X")
def old_function():
    pass

# Example: Script docstring
"""
script_name.py
DEPRECATED: Use script_name_v2.py instead
Timeline: Deprecated 2026-06-12, removal planned 2026-06-26
Migration: See DEVELOPMENT/MIGRATION_GUIDE.md
"""
```

### Step 3: Update Documentation
- Update README files with "DEPRECATED" warnings
- Add migration guide if complex
- Link to replacement

### Step 4: Announce
- Add to CHANGELOG
- Post in team channels
- Document in production/status docs

### Step 5: Monitor
- Track usage of deprecated code
- Support teams migrating away
- Collect concerns/questions

### Step 6: Archive or Delete
After waiting period:
- If still used → Extend deprecation
- If replaced → Archive or delete

---

## Workflow: Deleting Code

**IMPORTANT:** Only delete after archival or for obvious junk.

### Step 1: Verify
- ✅ Archived (if valuable)
- ✅ 1+ sprint waiting period passed
- ✅ No remaining usages
- ✅ Owner approval
- ✅ Lead approval

### Step 2: Confirm Dependencies
```bash
# Search entire codebase for references
grep -r "old_function" --include="*.py" --include="*.gd" .
grep -r "old_script" --include="*.py" --include="*.gd" .
```

**If any matches → DO NOT DELETE** (back to archive workflow)

### Step 3: Delete
```bash
rm path/to/old_code.py
git add .
git commit -m "Delete: Remove [thing] (archived [date], replaced by [new_thing])"
```

### Step 4: Monitor
- Watch for breakage
- Be ready to recover from git if needed

---

## Categories: What to Do With Each

### Old Scripts

| Type | Action | Timeline |
|------|--------|----------|
| One-off debugging | Delete | Immediately |
| Utility no longer used | Archive | After 1 sprint |
| Replaced utility | Archive then Delete | After 2 sprints |
| Complex migration | Archive permanently | Never delete |

### Old Documentation

| Type | Action | Timeline |
|------|--------|----------|
| Superseded (outdated info) | Archive to history/ | When replaced |
| Still relevant but old | Move to docs/history/ | During DOC sprints |
| Historical (design evolution) | Archive permanently | Never delete |
| Duplicate of current | Delete | Immediately |

### Old Assets

| Type | Action | Timeline |
|------|--------|----------|
| Unused sprites | Move to ARCHIVE/ | Quarterly cleanup |
| Old texture packs | Move to ARCHIVE/ | As replaced |
| Experimental concepts | Keep in ARCHIVE/ | Reference value |
| Accidental uploads | Delete | Immediately |

### Build Artifacts

| Type | Action | Timeline |
|------|--------|----------|
| .godot/ cache | Delete | Automatically (gitignored) |
| export/ folder | Delete | Automatically (gitignored) |
| *.ZIP backups | Delete | After 1 month |
| Compiled outputs | Delete | Automatically (gitignored) |

### Temporary Files

| Type | Action | Timeline |
|------|--------|----------|
| .DS_Store | Delete | Automatically (gitignored) |
| Editor temp files | Delete | Automatically (gitignored) |
| Debug outputs | Delete | End of day |
| Personal notes | Delete | Not in repo (use wiki) |

---

## Gitignore Strategy

**Files that should be gitignored (regenerable):**
```gitignore
# Cache
.godot/
__pycache__/
.pytest_cache/
.vscode/

# System
.DS_Store
Thumbs.db

# Build outputs
export/
build/

# Backups (regenerable via BACKUP.py)
BACKUP_*.ZIP
*.backup
*.tmp
```

**Files that must be in git (non-regenerable):**
- All source code
- Game content (ASSETS/)
- Documentation
- Configuration (project.godot)

---

## Timeline: Example Cleanup

### Sprint X-1: Identify
- Find 5 old scripts not used in 3+ months
- Verify no dependencies
- Plan archive

### Sprint X: Deprecate
- Move to archive/
- Add documentation
- Commit changes
- Notify team

### Sprint X+1: Monitor
- Verify no issues
- Check for late dependencies
- Get feedback

### Sprint X+2: Consider Deletion
- Review archive after 2-week period
- If safe → delete
- If concerns → keep archived indefinitely

---

## What NOT to Delete

### Never Delete:
- ✅ Git history (keep git)
- ✅ Historical records (keep in docs/history/)
- ✅ Completed work documentation
- ✅ Design decisions (even old ones)
- ✅ Migration records (learning source)

### Can Delete:
- ❌ Build artifacts (regenerable)
- ❌ Cache files (regenerable)
- ❌ Debug code (shouldn't be in repo)
- ❌ Duplicate code (but document removal)
- ❌ Temporary experiments (archive first)

---

## Approval Matrix

| Action | Owner | Reviewers | Approval |
|--------|-------|-----------|----------|
| Archive code | Code owner | Tech lead | Optional |
| Deprecate API | Design lead | All users | Notify |
| Delete archived | DevOps | Owner + lead | Required |
| Delete ASAP | Anyone | None | Use judgment (junk only) |

---

## Metrics & Reporting

### Track Quarterly:

1. **Code Growth**
   - Total lines in active codebase
   - Archived code size
   - Trend: should slow over time

2. **Deprecation Rate**
   - New deprecations per sprint
   - Time to removal
   - Adoption of replacements

3. **Archive Size**
   - Code archives
   - Asset archives
   - Total preserved

4. **Cleanup Effectiveness**
   - Bugs from deleted code: should be zero
   - Saved space
   - Improved codebase clarity

---

## References

- [Repository Structure](repo_structure.md) — Folder organization
- [Tools Registry](../tools/README.md) — Tool management
- Git documentation: `git log`, `git show`, `git checkout -- <file>`

---

**Last Updated:** 2026-06-12  
**Maintained By:** Architecture Team  
**Approval Required:** Before major deletions  
**Status:** Active 🟢
