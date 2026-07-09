#!/bin/bash
################################################################################
# INFILTRAITOR Manual Push Script with Version Bump
#
# Usage: ./push.sh [major|minor|patch] ["message"]
#
# Arguments:
#   [major|minor|patch]  Version bump type (default: patch)
#   ["message"]          Optional commit message suffix. If omitted,
#                        defaults to "ALPHA <version> - <date>"
#
# Examples:
#   ./push.sh patch
#   ./push.sh patch "DOC-HOOK-01 test"
#   ./push.sh minor "VOXEL-08: Baking system"
#
# Flow:
#   1. Stage all changes
#   2. Update documentation (AUTO blocks in current_state.md, OPERATOR_CONTEXT.md, CODEMAP.md)
#   3. Commit with tag message
#   4. Push to remote
#   5. On success: bump VERSION file, commit bump, push bump commit
#
# Error checking: Every stage must succeed; false success avoided.
################################################################################

set -euo pipefail

# Tell the pre-push hook this push goes through push.sh (Stage 8 beeps at the
# end of the full run; the hook stays silent to avoid double notification).
export INFILTRAITOR_PUSH_SH=1

BUMP_TYPE="${1:-patch}"  # Default to patch; accept major/minor/patch as arg
MESSAGE="${2:-}"         # Optional message suffix
REPO_ROOT="$(dirname "$0")/../../"
VERSION_FILE="$REPO_ROOT/VERSION"

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "❌ Invalid bump type: $BUMP_TYPE"
    echo "   Usage: ./push.sh [major|minor|patch] [\"message\"]"
    exit 1
fi

cd "$REPO_ROOT" || exit 1

echo ""
echo "================================"
echo "INFILTRAITOR Manual Push Script"
echo "================================"
echo ""

# Build TAG: if no message given, use ALPHA default
if [ -z "$MESSAGE" ]; then
    TAG="ALPHA BAKE FIX $(cat "$VERSION_FILE") - $(date +%Y-%m-%d)"
else
    TAG="$MESSAGE"
fi

echo "[CONFIG] Version bump: $BUMP_TYPE"
echo "[CONFIG] Tag: $TAG"
echo ""

# ── STAGE 1: Verify VERSION file exists ──────────────────────────────────────
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ VERSION file not found at $VERSION_FILE"
    exit 1
fi
echo "[VERIFY] VERSION file found"

# ── STAGE 1.3: Architecture invariant check ──────────────────────────────────
echo "[CHECK] Verifying architecture invariants..."
if ! python3 "$REPO_ROOT/tools/persistent/check_invariants.py"; then
    echo "[CHECK] ❌ Architecture rule violations found — push aborted"
    exit 1
fi
echo "[CHECK] ✅ All 8 architecture rules satisfied"

# ── STAGE 1.4: Whole-project GDScript lint ───────────────────────────────────
echo "[LINT] Checking GDScript compile integrity..."
if ! python3 "$REPO_ROOT/tools/persistent/project_lint.py"; then
    echo "[LINT] ❌ Real GDScript compile errors found — push aborted"
    exit 1
fi
echo "[LINT] ✅ Whole-project lint passed"

# ── STAGE 1.5: Update documentation ─────────────────────────────────────────
echo "[DOCS] Updating generated documentation..."
if ! python3 "$REPO_ROOT/tools/persistent/update_docs.py"; then
    echo "[DOCS] ❌ Documentation update failed — push aborted"
    exit 1
fi
echo "[DOCS] ✅ Documentation refreshed"

# ── STAGE 2: Stage all changes ───────────────────────────────────────────────
echo "[STAGE] Staging changes..."
git add -A
echo "[STAGE] ✅ Files staged"

# ── STAGE 3: Commit ──────────────────────────────────────────────────────────
echo "[COMMIT] Creating commit with message: '$TAG'"
if ! git commit -m "$TAG"; then
    echo "[COMMIT] ❌ Commit failed (hook may have blocked)"
    exit 1
fi
COMMIT_HASH=$(git rev-parse --short HEAD)
echo "[COMMIT] ✅ Commit created: $COMMIT_HASH"

# ── STAGE 4: Push ────────────────────────────────────────────────────────────
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
REMOTE=${3:-origin}  # Can override remote (note: now $3 since $2 is message)
echo "[PUSH] Pushing to $REMOTE/$CURRENT_BRANCH..."
if ! git push "$REMOTE" "$CURRENT_BRANCH"; then
    echo "[PUSH] ❌ Push failed"
    exit 1
fi
echo "[PUSH] ✅ Pushed to $REMOTE/$CURRENT_BRANCH"

# ── STAGE 5: Bump version ────────────────────────────────────────────────────
echo ""
echo "[VERSION] Reading current version from $VERSION_FILE..."
CURRENT_VERSION=$(cat "$VERSION_FILE")
echo "[VERSION] Current: $CURRENT_VERSION"

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"
MAJOR=${MAJOR:-0}
MINOR=${MINOR:-0}
PATCH=${PATCH:-0}

# Calculate new version
case "$BUMP_TYPE" in
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    patch)
        PATCH=$((PATCH + 1))
        ;;
esac

NEW_VERSION="$MAJOR.$MINOR.$PATCH"
echo "$NEW_VERSION" > "$VERSION_FILE"
echo "[VERSION] ✅ Bumped to: $NEW_VERSION"

# ── STAGE 6: Update docs + Commit version bump ──────────────────────────────
# Re-run update_docs.py so AUTO:header shows the NEW version, then include
# refreshed docs in the bump commit (post-bump coherence).
echo "[VERSION] Re-running doc updates for post-bump coherence..."
if python3 "$REPO_ROOT/tools/persistent/update_docs.py"; then
    echo "[VERSION] ✅ Docs refreshed for new version"
fi
echo "[VERSION-COMMIT] Committing version bump + refreshed docs..."
git add "$VERSION_FILE" "$REPO_ROOT/docs/production/current_state.md" "$REPO_ROOT/tools/persistent/CODEMAP.md" "$REPO_ROOT/tools/persistent/OPERATOR_CONTEXT.md" 2>/dev/null || true
if ! git commit -m "[VERSION] Bump to $NEW_VERSION"; then
    echo "[VERSION-COMMIT] ⚠️  Version commit failed (may be staged)"
    # Don't fail here; version file is already updated in working tree
    # User can manually push if needed
else
    VERSION_COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "[VERSION-COMMIT] ✅ Version commit created: $VERSION_COMMIT_HASH"

    # ── STAGE 7: Push version commit ─────────────────────────────────────────
    echo "[VERSION-PUSH] Pushing version bump + docs..."
    if ! git push "$REMOTE" "$CURRENT_BRANCH"; then
        echo "[VERSION-PUSH] ⚠️  Version push failed"
        echo "              VERSION file updated locally; manual push may be needed"
    else
        echo "[VERSION-PUSH] ✅ Version pushed"
    fi
fi

echo ""
echo "================================"
echo "✅ Push workflow complete!"
echo "   Version: $NEW_VERSION"
echo "   Branch: $CURRENT_BRANCH"
echo "================================"
echo ""

# ── STAGE 8: Notification (audio beep) ───────────────────────────────────────
# Notify operator that prompt is done (cross-platform audio)
OS=$(uname)
case "$OS" in
    Darwin)
        # macOS: use afplay
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
        sleep 0.2
        afplay /System/Library/Sounds/Glass.aiff 2>/dev/null || true
        ;;
    Linux)
        # Linux: try paplay (PulseAudio), fall back to beep
        paplay /usr/share/sounds/freedesktop/stereo/complete.oga 2>/dev/null || beep 2>/dev/null || echo -e '\a' || true
        ;;
    MINGW*|MSYS*|CYGWIN*)
        # Windows: PowerShell beep
        powershell -c "[console]::beep()" 2>/dev/null || echo -e '\a' || true
        ;;
    *)
        # Fallback: ASCII bell (works everywhere)
        echo -e '\a' || true
        ;;
esac
