#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

echo "Building Progress Tracker…"
swift build -c release

APP="$ROOT/dist/Progress Tracker.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$ROOT/.build/release/ProgressTracker" "$APP/Contents/MacOS/ProgressTracker"
cp "$ROOT/Info.plist" "$APP/Contents/Info.plist"

# Ad-hoc signing is enough to run this app locally.
codesign --force --deep --sign - "$APP"

echo ""
echo "Created: $APP"
echo "Run it with: open \"$APP\""
