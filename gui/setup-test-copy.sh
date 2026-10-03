#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Orxooo
set -euo pipefail
source_app="/Applications/Claude.app"
replace=false
while [ "$#" -gt 0 ]; do
  case "$1" in
    --source) [ "$#" -ge 2 ] || exit 2; source_app=$2; shift 2;;
    --replace) replace=true; shift;;
    *) echo "usage: setup-test-copy.sh [--source /path/Claude.app] [--replace]" >&2; exit 2;;
  esac
done
root="$HOME/Library/Application Support/claudefont"
target="$root/Claude Test.app"
marker="$root/.managed-test-copy"
for parent in "$HOME/Library" "$HOME/Library/Application Support" "$root"; do
  [ ! -L "$parent" ] || { echo "Refusing symlink test location" >&2; exit 2; }
done
[ ! -L "$source_app" ] && [ -d "$source_app/Contents" ] && [ ! -L "$source_app/Contents" ] && [ ! -L "$source_app/Contents/Info.plist" ] || { echo "Invalid source app" >&2; exit 2; }
source_app="$(cd "$(dirname "$source_app")" && pwd -P)/$(basename "$source_app")"
case "$source_app" in *.app) ;; *) echo "Source must be an app bundle" >&2; exit 2;; esac
case "$source_app" in "$root"|"$root"/*) echo "Test app cannot be its own source" >&2; exit 2;; esac
[ ! -L "$source_app/Contents/Resources" ] && [ -f "$source_app/Contents/Resources/app.asar" ] && [ ! -L "$source_app/Contents/Resources/app.asar" ] || { echo "Source has no regular Electron archive" >&2; exit 2; }
/usr/bin/codesign --verify --deep --strict "$source_app"
if [ -e "$root" ]; then
  [ -f "$marker" ] && [ ! -L "$marker" ] && [ "$(cat "$marker")" = "io.github.orxooo.claudefont.test" ] || { echo "Existing directory is not a managed test copy" >&2; exit 2; }
else
  mkdir -p "$root"; chmod 700 "$root"
  printf '%s\n' 'io.github.orxooo.claudefont.test' > "$marker"
fi
for path in "$target" "$root/profile" "$root/.previous.app" "$root/.staged.app"; do
  [ ! -L "$path" ] || { echo "Refusing symlink test contents" >&2; exit 2; }
done
if /bin/ps -axo comm= | /usr/bin/grep -F "$target/Contents/" >/dev/null; then
  echo "Close the test app before rebuilding" >&2; exit 2
fi
if [ -e "$target" ]; then
  $replace || { echo "Test copy exists; use --replace to rebuild" >&2; exit 2; }
  [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")" = 'io.github.orxooo.claudefont.test' ] || { echo "Unexpected target identity" >&2; exit 2; }
fi
[ ! -e "$root/.previous.app" ] && [ ! -e "$root/.staged.app" ] || { echo "Previous operation artifacts exist; inspect them before rebuilding" >&2; exit 2; }
# Local test copies work without a developer certificate. Release signing is separate.
identity=${CLAUDEFONT_SIGN_IDENTITY:--}
staged="$root/.staged.app"
launcher="$(cd "$(dirname "$0")" && pwd)/ClaudefontTestLauncher"
[ -f "$launcher" ] && [ ! -L "$launcher" ] || { echo "Test launcher is missing from the application bundle" >&2; exit 2; }
work=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/claudefont-copy.XXXXXX")
cleanup() {
  code=$?
  if [ -d "$staged" ] && [ ! -L "$staged" ]; then rm -rf "$staged"; fi
  if [ "$code" -ne 0 ] && [ -d "$root/.previous.app" ] && [ ! -e "$target" ]; then mv "$root/.previous.app" "$target"; fi
  rm -rf "$work"
  exit "$code"
}
trap cleanup EXIT
/usr/bin/ditto "$source_app" "$staged"
original=$(/usr/libexec/PlistBuddy -c 'Print CFBundleExecutable' "$staged/Contents/Info.plist")
case "$original" in ''|*/*|*$'\n'*|ClaudefontTestLauncher) echo "Invalid runtime executable" >&2; exit 2;; esac
[ -f "$staged/Contents/MacOS/$original" ] && [ ! -L "$staged/Contents/MacOS/$original" ] || { echo "Invalid runtime path" >&2; exit 2; }
/usr/bin/codesign -d --entitlements :- "$staged" > "$work/entitlements.plist" 2>/dev/null
if [ "$identity" = "-" ] && [ -s "$work/entitlements.plist" ]; then
  # These claims require a certificate's team identity. Runtime/sandbox capabilities remain.
  for key in application-identifier com.apple.application-identifier com.apple.developer.team-identifier keychain-access-groups com.apple.security.application-groups; do
    if /usr/libexec/PlistBuddy -c "Print :$key" "$work/entitlements.plist" >/dev/null 2>&1; then
      /usr/libexec/PlistBuddy -c "Delete :$key" "$work/entitlements.plist"
      printf 'Removed certificate-bound entitlement: %s\n' "$key"
    fi
  done
fi
# The copied runtime and retained vendor frameworks have different Team IDs.
if [ ! -s "$work/entitlements.plist" ]; then
  printf '%s\n' '<?xml version="1.0"?><plist version="1.0"><dict/></plist>' > "$work/entitlements.plist"
fi
/usr/libexec/PlistBuddy -c 'Set :com.apple.security.cs.disable-library-validation true' "$work/entitlements.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Add :com.apple.security.cs.disable-library-validation bool true' "$work/entitlements.plist"
original_flags=$(/usr/bin/codesign -d --verbose=4 "$staged" 2>&1 | /usr/bin/sed -n 's/.*flags=\(0x[0-9a-fA-F]*\).*/\1/p' | /usr/bin/head -n 1)
case "$original_flags" in 0x*) ;; *) echo "Unable to read signature flags" >&2; exit 2;; esac
cp "$launcher" "$staged/Contents/MacOS/ClaudefontTestLauncher"
/usr/libexec/PlistBuddy -c "Add ClaudefontRuntimeExecutable string $original" "$staged/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleExecutable ClaudefontTestLauncher' "$staged/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set CFBundleIdentifier io.github.orxooo.claudefont.test' "$staged/Contents/Info.plist"
# Electron derives retained helper names from CFBundleName. Keep its native
# runtime name; the display name and managed app path identify the test copy.
/usr/libexec/PlistBuddy -c 'Set CFBundleDisplayName Claude Test' "$staged/Contents/Info.plist" 2>/dev/null || /usr/libexec/PlistBuddy -c 'Add CFBundleDisplayName string Claude Test' "$staged/Contents/Info.plist"
# Signing retains runtime capabilities; certificate-bound claims are omitted for ad-hoc copies.
# Existing frameworks and helpers retain their original signatures.
sign_args=(--force --sign "$identity" --options "$original_flags")
if [ -s "$work/entitlements.plist" ]; then sign_args+=(--entitlements "$work/entitlements.plist"); fi
# The former main executable becomes nested code; detach its old Info.plist binding.
/usr/bin/codesign "${sign_args[@]}" "$staged/Contents/MacOS/$original"
/usr/bin/codesign "${sign_args[@]}" "$staged"
/usr/bin/codesign --verify --deep --strict "$staged"
if [ -e "$target" ]; then mv "$target" "$root/.previous.app"; fi
mv "$staged" "$target"
mkdir -p "$root/profile"; chmod 700 "$root/profile"
# Profile starts empty on first creation; rebuilds preserve only this test profile.
if [ -d "$root/.previous.app" ]; then rm -rf "$root/.previous.app"; fi
printf 'Test copy ready: %s\nFresh profile: %s\n' "$target" "$root/profile"
