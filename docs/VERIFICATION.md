# V1.0.0 verification

Current client: **1.0.0, build 4**. Latest runtime checks: **2026-10-03**.
Automated fixtures and actual Claude execution are recorded separately.

## Recorded results

| Check | Result | Scope |
| --- | --- | --- |
| Signed app fixtures | 65 PASS | Apply/reapply/restore, backups, archive integrity, interrupted recovery, import validation and rejected unsafe paths |
| Linked-library/startup fixtures | 6 PASS | Library loading, unchanged nested code, persistent renderer readiness, missing/rotating renderer rollback and test launcher signing |
| Browser styling/font loading | 18 PASS | Four actual local face loads, scaling, layout, palettes, dynamic DOM and open Shadow DOM |
| Portable themes | 14 PASS, recorded 2026-10-02 | Roundtrip and invalid input handling; unchanged in build 4 |
| Build 4 package | PASS | Apple Silicon/macOS 26 compilation and deep strict signature |
| Native client | PASS | Build/version/license identity, current screenshots, language menu, quit-first prompt and icon without an outer plate |
| Actual Claude 2.19675.0 on macOS 27.2 | PASS for startup and observed font rendering | Signed-in new-chat window, serif interface and unsent Chinese sample showing Songti glyphs |
| Isolated Claude test copy | PASS for font loading | Four registered aliases loaded, independent signed-out profile |
| Public release download | PASS | App/source/checksums match uploaded bytes; app is build 4 and signature is valid |

The sample was cleared without sending. Login and conversation data were not
reset. Private account screenshots, logs and crash reports are not distributed.

## Compatibility limits

- All code regions, Cowork/VM, chat/network transactions and other Claude
  versions: **NOT RUN** in this build's actual runtime checks.
- Previews and synthetic DOM checks do not prove every Claude view works.
- Unknown terminal resources reject adaptation.
- Claude updates can change resources and invalidate previously applied styles.
- Startup requires the same owned renderer PID alive for at least one second
  within a 20-second deadline; it does not verify account services or all features.

## Technical checks

CoreText resolves PostScript/full face names. Unresolved families retain the
requested name rather than silently substituting a default font.

For ad-hoc signing, runtime flags are retained and the main executable receives
the [library-validation entitlement](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.cs.disable-library-validation).
Nested framework bytes and signatures are preserved.

Packed ASAR entries require recorded size and SHA-256 integrity. External native
resources follow Electron's unpacked-entry semantics, retaining path, symlink,
signed-bundle and complete-backup checks. See Electron's
[archive reader](https://github.com/electron/electron/blob/main/shell/common/asar/archive.cc)
and [ASAR file reader](https://github.com/electron/asar/blob/main/src/disk.ts).

## Reproduce automated checks

Requires Apple Silicon/macOS 26+, Xcode's Swift/macOS SDK and Python 3.
The browser check also uses Node.js/npm and `agent-browser` browser setup.
Disposable fixtures do not target an installed Claude.

```sh
python3 tests/engine/check.py
CLAUDEFONT_TEST_BIN="$HOME/Library/Caches/claudefont/engine-tests/claudefont" python3 tests/engine/startup.py
python3 tests/style_browser.py
swiftc shared/Appearance.swift tests/check_themes.swift -o /tmp/claudefont-themes
/tmp/claudefont-themes
```

Build/test output belongs outside the checkout. See
[development instructions](DEVELOPMENT.md). Releases contain the
signed app, matching tagged source and `SHA256SUMS.txt`.
