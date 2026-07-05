#!/bin/bash
################################################################################
# INFILTRAITOR Manual Push Script with Version Bump
#
# Usage: ./push.sh [major|minor|patch]
# Default: bumps patch version
#
# Flow:
#   1. Stage all changes
#   2. Commit with tag message
#   3. Push to remote
#   4. On success: bump VERSION file, commit bump, push bump commit
#
# Error checking: Every stage must succeed; false success avoided.
################################################################################

set -euo pipefail

BUMP_TYPE="${1:-patch}"  # Default to patch; accept major/minor/patch as arg
REPO_ROOT="$(dirname "$0")/../../"
VERSION_FILE="$REPO_ROOT/VERSION"

####################
####################
TAG="ALPHA FIX-BAKE-05 - $(date +%Y-%m-%d)"
####################
####################

# Validate bump type
if [[ ! "$BUMP_TYPE" =~ ^(major|minor|patch)$ ]]; then
    echo "❌ Invalid bump type: $BUMP_TYPE"
    echo "   Usage: ./push.sh [major|minor|patch]"
    exit 1
fi

cd "$REPO_ROOT" || exit 1

echo ""
echo "================================"
echo "INFILTRAITOR Manual Push Script"
echo "================================"
echo ""
echo "[CONFIG] Version bump: $BUMP_TYPE"
echo "[CONFIG] Tag: $TAG"
echo ""

# ── STAGE 1: Verify VERSION file exists ──────────────────────────────────────
if [ ! -f "$VERSION_FILE" ]; then
    echo "❌ VERSION file not found at $VERSION_FILE"
    exit 1
fi
echo "[VERIFY] VERSION file found"

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
REMOTE=${2:-origin}  # Default to origin, can override
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

# ── STAGE 6: Commit version bump ─────────────────────────────────────────────
echo "[VERSION-COMMIT] Committing version bump..."
git add "$VERSION_FILE"
if ! git commit -m "[VERSION] Bump to $NEW_VERSION"; then
    echo "[VERSION-COMMIT] ⚠️  Version commit failed (may be staged)"
    # Don't fail here; version file is already updated in working tree
    # User can manually push if needed
else
    VERSION_COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "[VERSION-COMMIT] ✅ Version commit created: $VERSION_COMMIT_HASH"

    # ── STAGE 7: Push version commit ─────────────────────────────────────────
    echo "[VERSION-PUSH] Pushing version bump..."
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
