#!/bin/bash
# Copyright (C) 2026 Orxooo
# SPDX-License-Identifier: GPL-3.0-only
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
out=${1:-"$HOME/Library/Caches/claudefont/cli/claudefont"}
mkdir -p "$(dirname "$out")"
/usr/bin/xcrun swiftc -swift-version 5 -O -target arm64-apple-macos26.0 "$repo"/shared/*.swift "$repo"/cli/*.swift -o "$out"
printf 'Built %s\n' "$out"
