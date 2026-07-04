#!/bin/bash
################################################################################
# INFILTRAITOR Quick Push Script
# Edit the TAG below to customize your commit message
################################################################################

# === EDIT THIS FIELD ===
TAG="Alpha BAKE-03 - $(date +%Y-%m-%d)"
# =======================

echo "📦 Pushing to repository..."
echo "   Tag: $TAG"
echo ""

cd "$(dirname "$0")/../../" || exit 1

git add -A
git commit -m "$TAG"
git push

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Push successful!"
else
    echo ""
    echo "❌ Push failed!"
    exit 1
fi
