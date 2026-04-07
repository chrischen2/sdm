#!/usr/bin/env bash
#
# package-release.sh — build a distributable zip of SymphonyDataMapper.app
#
# Produces: dist/SymphonyDataMapper3-<version>-macos-x86_64.zip
#
# Usage:
#   scripts/package-release.sh              # version from git describe
#   scripts/package-release.sh v3.0.1       # explicit version tag
#
# Requires:
#   - A completed Release build at
#     SymphonyDataMapper/build/Release/SymphonyDataMapper.app
#     (run scripts/build.sh first, or xcodebuild -configuration Release)

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_SRC="$REPO_ROOT/SymphonyDataMapper/build/Release/SymphonyDataMapper.app"
DIST_DIR="$REPO_ROOT/dist"

VERSION="${1:-$(git -C "$REPO_ROOT" describe --tags --always --dirty 2>/dev/null || echo dev)}"
ZIP_NAME="SymphonyDataMapper3-${VERSION}-macos-x86_64.zip"
ZIP_PATH="$DIST_DIR/$ZIP_NAME"

red()    { printf "\033[31m%s\033[0m\n" "$*"; }
green()  { printf "\033[32m%s\033[0m\n" "$*"; }
yellow() { printf "\033[33m%s\033[0m\n" "$*"; }

if [[ ! -d "$APP_SRC" ]]; then
    red "ERROR: $APP_SRC not found."
    red "Build the Release configuration first, e.g.:"
    red "  cd SymphonyDataMapper && xcodebuild -configuration Release \\"
    red "      CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO"
    exit 1
fi

echo "==> Checking binary architecture"
BIN="$APP_SRC/Contents/MacOS/SymphonyDataMapper"
ARCH_OUT=$(lipo -archs "$BIN")
echo "    $BIN: $ARCH_OUT"
if [[ "$ARCH_OUT" != "x86_64" ]]; then
    yellow "WARNING: expected x86_64, got '$ARCH_OUT'"
fi

echo "==> Checking linked libraries (otool -L)"
NONSYSTEM=$(otool -L "$BIN" | awk 'NR>1 {print $1}' \
    | grep -Ev '^(/usr/lib/|/System/|@rpath/|@executable_path/)' || true)
if [[ -n "$NONSYSTEM" ]]; then
    yellow "WARNING: binary references non-system dylibs:"
    echo "$NONSYSTEM" | sed 's/^/    /'
    yellow "Users will need these available at the same paths (e.g. via brew)."
    yellow "Consider bundling them into the .app with install_name_tool, or"
    yellow "document 'brew install hdf5 libaec' as a prerequisite."
else
    green "    All linked dylibs are system libraries. Good."
fi

echo "==> Verifying code signature"
if codesign --verify --deep --strict "$APP_SRC" 2>&1; then
    green "    Signature OK (ad-hoc is fine for unsigned personal builds)."
else
    yellow "    codesign --verify reported issues; continuing anyway."
fi

echo "==> Packaging with ditto"
mkdir -p "$DIST_DIR"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_SRC" "$ZIP_PATH"

SIZE=$(du -h "$ZIP_PATH" | cut -f1)
green "==> Created $ZIP_PATH ($SIZE)"

cat <<EOF

Next steps:
  1. Test the zip on a clean machine (or at least a fresh user) by unzipping
     and running: sudo xattr -dr com.apple.quarantine SymphonyDataMapper.app
  2. Tag the release if you haven't:
        git tag -a $VERSION -m "sdm3 $VERSION"
        git push origin $VERSION
  3. Upload to GitHub Releases:
        scripts/publish-release.sh $VERSION
     (requires gh CLI authenticated)
EOF
