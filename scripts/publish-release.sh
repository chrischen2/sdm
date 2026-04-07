#!/usr/bin/env bash
#
# publish-release.sh — create a GitHub release and upload the packaged zip.
#
# Usage:
#   scripts/publish-release.sh v3.0.0
#
# Requires the 'gh' CLI authenticated against the repo.

set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <version-tag>   e.g. $0 v3.0.0"
    exit 1
fi

VERSION="$1"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ZIP_PATH="$REPO_ROOT/dist/SymphonyDataMapper3-${VERSION}-macos-x86_64.zip"

if [[ ! -f "$ZIP_PATH" ]]; then
    echo "ERROR: $ZIP_PATH not found."
    echo "Run scripts/package-release.sh $VERSION first."
    exit 1
fi

if ! command -v gh >/dev/null; then
    echo "ERROR: gh CLI not installed. Install with 'brew install gh' and 'gh auth login'."
    exit 1
fi

# Ensure tag exists locally and on origin.
if ! git -C "$REPO_ROOT" rev-parse "$VERSION" >/dev/null 2>&1; then
    echo "Tag $VERSION does not exist yet. Creating..."
    git -C "$REPO_ROOT" tag -a "$VERSION" -m "sdm3 $VERSION"
fi
git -C "$REPO_ROOT" push origin "$VERSION"

NOTES=$(cat <<EOF
## Symphony Data Mapper 3 — $VERSION

Modernized build of SDM for macOS Sequoia (Intel x86_64).
Output is byte-compatible with sdm2; verify with \`tools/compare_auisql.py\`.

### Install
1. Download and unzip \`SymphonyDataMapper3-${VERSION}-macos-x86_64.zip\`.
2. Move \`SymphonyDataMapper.app\` to \`/Applications\`.
3. Clear the Gatekeeper quarantine:
   \`\`\`
   sudo xattr -dr com.apple.quarantine /Applications/SymphonyDataMapper.app
   \`\`\`
4. Symlink the CLI:
   \`\`\`
   sudo ln -sf /Applications/SymphonyDataMapper.app/Contents/MacOS/SymphonyDataMapper /usr/local/bin/sdm3
   \`\`\`
5. Run: \`sdm3 /path/to/experiment.h5\`

### Requirements
- Intel x86_64 Mac (Apple Silicon: \`softwareupdate --install-rosetta\`)
- macOS 13 or later

See README.md and MODERNIZATION.md for details.
EOF
)

echo "==> Creating GitHub release $VERSION"
gh release create "$VERSION" "$ZIP_PATH" \
    --repo chrischen2/sdm \
    --title "sdm3 $VERSION" \
    --notes "$NOTES"

echo "Done."
