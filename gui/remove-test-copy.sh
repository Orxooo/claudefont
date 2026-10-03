#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (C) 2026 Orxooo
set -euo pipefail
[ "$#" -eq 0 ] || { echo "usage: remove-test-copy.sh" >&2; exit 2; }
root="$HOME/Library/Application Support/claudefont"
target="$root/Claude Test.app"
for path in "$HOME/Library" "$HOME/Library/Application Support" "$root" "$root/.managed-test-copy" "$target" "$root/profile"; do
  [ ! -L "$path" ] || { echo "Refusing symlink test location" >&2; exit 2; }
done
if [ ! -e "$root" ]; then echo "No test copy exists"; exit 0; fi
[ -f "$root/.managed-test-copy" ] && [ "$(cat "$root/.managed-test-copy")" = 'io.github.orxooo.claudefont.test' ] || { echo "Directory is not a managed test copy" >&2; exit 2; }
if /bin/ps -axo comm= | /usr/bin/grep -F "$target/Contents/" >/dev/null; then
  echo "Close the test app before removing it" >&2; exit 2
fi
if [ -e "$target" ]; then
  [ -f "$target/Contents/Info.plist" ] && [ ! -L "$target/Contents" ] && [ ! -L "$target/Contents/Info.plist" ] || { echo "Invalid test bundle" >&2; exit 2; }
  [ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$target/Contents/Info.plist")" = 'io.github.orxooo.claudefont.test' ] || { echo "Unexpected target identity" >&2; exit 2; }
fi
# Delete only the fixed application and profile, leaving backups, logs and markers intact.
[ ! -e "$target" ] || rm -rf "$target"
[ ! -e "$root/profile" ] || rm -rf "$root/profile"
echo "Managed test app and profile removed"
