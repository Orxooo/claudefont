#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Orxooo
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
cache=${CLAUDEFONT_BUILD_DIR:-"$HOME/Library/Caches/claudefont/rewrite-20261002"}
case "$cache" in "$HOME/Library/Caches/claudefont"/*|"$HOME/Library/Application Support/claudefont-development"/*) ;; *) echo "Use the claudefont cache or development support directory for build output" >&2; exit 2;; esac
[ ! -L "$cache" ] || { echo "Refusing a symlink build directory" >&2; exit 2; }
mkdir -p "$cache"
cache=$(cd "$cache" && pwd -P)
case "$cache" in "$HOME/Library/Caches/claudefont"/*|"$HOME/Library/Application Support/claudefont-development"/*) ;; *) echo "Build output resolved outside the claudefont build directories" >&2; exit 2;; esac
case "$cache" in "$repo"|"$repo"/*|*"/Mobile Documents/"*) echo "Build output must be outside the repository and iCloud" >&2; exit 2;; esac
app="$cache/ClaudeFont.app"
if [ -e "$app" ]; then
  [ ! -L "$app" ] && [ -d "$app/Contents" ] || { echo "Refusing unsafe output path" >&2; exit 2; }
  rm -rf "$app"
fi
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources" "$cache/modules"
identity=${CLAUDEFONT_SIGN_IDENTITY:-}
if [ -z "$identity" ]; then
  identities=$(/usr/bin/security find-identity -v -p codesigning | /usr/bin/awk '/Apple Development:|Developer ID Application:/ { print $2 }')
  count=$(printf '%s\n' "$identities" | /usr/bin/awk 'NF { n++ } END { print n+0 }')
  [ "$count" -eq 1 ] || { echo "Set CLAUDEFONT_SIGN_IDENTITY when there is not exactly one Apple signing identity" >&2; exit 2; }
  identity=$identities
fi
[ -n "$identity" ] || { echo "An Apple signing identity is required" >&2; exit 2; }
cli_sources=()
for file in "$repo"/cli/*.swift; do cli_sources+=("$file"); done
shared_sources=()
for file in "$repo"/shared/*.swift; do shared_sources+=("$file"); done
gui_sources=()
for file in "$repo"/gui/*.swift; do
  case "$(basename "$file")" in render-icon.swift|debug*.swift) continue;; esac
  gui_sources+=("$file")
done
export CLANG_MODULE_CACHE_PATH="$cache/modules"
/usr/bin/xcrun swiftc -O -target arm64-apple-macos26.0 -module-cache-path "$cache/modules" "${shared_sources[@]}" "${cli_sources[@]}" -o "$app/Contents/Resources/claudefont"
/usr/bin/xcrun swiftc -O -target arm64-apple-macos26.0 -parse-as-library -module-cache-path "$cache/modules" "${shared_sources[@]}" "${gui_sources[@]}" -o "$app/Contents/MacOS/claudefont"
/usr/bin/xcrun swift -module-cache-path "$cache/modules" "$repo/gui/render-icon.swift" "$cache/claudefont.iconset"
/usr/bin/iconutil -c icns "$cache/claudefont.iconset" -o "$app/Contents/Resources/claudefont.icns"
cp "$repo/gui/setup-test-copy.sh" "$repo/gui/remove-test-copy.sh" "$repo/LICENSE" "$repo/NOTICE" "$app/Contents/Resources/"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>io.github.orxooo.claudefont</string>
<key>CFBundleName</key><string>ClaudeFont</string>
<key>CFBundleDisplayName</key><string>ClaudeFont</string>
<key>CFBundleExecutable</key><string>claudefont</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>4</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleIconFile</key><string>claudefont</string>
<key>LSMinimumSystemVersion</key><string>26.0</string>
<key>NSHighResolutionCapable</key><true/>
<key>NSSystemAdministrationUsageDescription</key><string>ClaudeFont needs access to back up, update and restore the Claude app you select.</string>
<key>NSHumanReadableCopyright</key><string>Copyright © 2026 Orxooo. GPL-3.0-only.</string>
</dict></plist>
PLIST
cat > "$cache/TestLauncher.swift" <<'SWIFT'
import Foundation
import Darwin
let app = Bundle.main.bundleURL
let expected = URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/claudefont/Claude Test.app")
guard app.standardizedFileURL == expected.standardizedFileURL,
      let executable = Bundle.main.object(forInfoDictionaryKey: "ClaudefontRuntimeExecutable") as? String,
      !executable.isEmpty, !executable.contains("/"), executable != "ClaudefontTestLauncher" else { exit(2) }
let runtime = app.appendingPathComponent("Contents/MacOS").appendingPathComponent(executable)
let profile = app.deletingLastPathComponent().appendingPathComponent("profile")
var forwarded: [String] = []
var skipNext = false
for arg in CommandLine.arguments.dropFirst() {
    if skipNext { skipNext = false; continue }
    if arg == "--user-data-dir" { skipNext = true; continue }
    if arg.hasPrefix("--user-data-dir=") { continue }
    forwarded.append(arg)
}
let values = [runtime.path] + forwarded + ["--user-data-dir=" + profile.path]
var pointers = values.map { strdup($0) }; pointers.append(nil)
execv(runtime.path, &pointers)
fputs("Cannot launch test runtime\n", stderr); exit(1)
SWIFT
/usr/bin/xcrun swiftc -O -target arm64-apple-macos26.0 -module-cache-path "$cache/modules" "$cache/TestLauncher.swift" -o "$app/Contents/Resources/ClaudefontTestLauncher"
/usr/bin/codesign --force --sign "$identity" "$app/Contents/Resources/ClaudefontTestLauncher"
/usr/bin/codesign --force --sign "$identity" "$app/Contents/Resources/claudefont"
/usr/bin/codesign --force --sign "$identity" "$app"
/usr/bin/codesign --verify --strict --verbose=2 "$app/Contents/Resources/claudefont"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$app"
echo "$app"
