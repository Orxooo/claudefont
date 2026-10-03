# claudefont architecture

claudefont is an independently developed native macOS application. Its client,
command-line engine, archive handling, styling, backup and recovery logic are
implemented in this repository using Swift, SwiftUI, AppKit, CoreText and
macOS system tools. The project distributes neither Claude code nor font files.

## Source layout

| Location | Responsibility |
| --- | --- |
| `gui/WorkspaceView.swift` | Six-page workspace, controls and sample previews |
| `gui/Model.swift` | Selected target, configuration and CLI execution |
| `gui/Localization.swift` | Chinese and English interface text |
| `gui/Themes.swift` | Portable themes and compatibility presentation |
| `gui/Updates.swift` | GitHub release checks and download links |
| `shared/Appearance.swift` | Portable settings schema and validation |
| `shared/StyleCSS.swift` | CoreText face resolution, CSS and renderer payload |
| `cli/Archive.swift` | ASAR parsing, packing and integrity checks |
| `cli/Engine.swift` | Apply, status, backups, signing and transactional recovery |
| `cli/Migration.swift` | Validated settings and matching pristine-backup import |
| `cli/Terminal.swift` | Adaptation of recognized terminal resources |
| `gui/*test-copy.sh` | Managed test-copy creation and removal |
| `tests/` | Synthetic app, font-loading, stylesheet and theme checks |

## Applying settings

1. Validate the application, resource structure and configuration.
2. Preserve a complete backup and prepare a staged replacement.
3. Generate the renderer payload; update ASAR and recorded integrity.
4. Re-sign the modified executable, retaining nested framework signatures.
5. Start an isolated profile and require a persistent owned Electron renderer.
6. Complete the transaction, or restore the complete preceding app on failure.

Selected font families resolve to local PostScript/full face names with CoreText.
The styling payload handles supported DOM regions and open Shadow DOM. It does
not replace the main-process JavaScript entry point.

Re-signing changes Claude's original top-level signature. Ad-hoc signing adds
the library-validation entitlement needed to load retained vendor-signed
frameworks. Complete backups support restoration. Actual compatibility and
verification boundaries are in [VERIFICATION.md](VERIFICATION.md).

## Interfaces and storage

The client invokes its bundled CLI and reads JSON state. Commands are
`status`, `doctor`, `install`, `uninstall`, `backups` and `migrate`.
Use `--help` for flags. `doctor` tests write access with a temporary probe.

- Settings/themes: `~/.config/claudefont/`.
- Backups/logs/transactions: `~/.local/share/claudefont/`.
- Managed test app/profile: `~/Library/Application Support/claudefont/`.
- CLI overrides: `CLAUDEFONT_CONFIG` and `CLAUDEFONT_DATA_DIR`.
- Bundle identity: `io.github.orxooo.claudefont`.

Import validates settings and a pristine backup of the same application version.
It leaves the selected application unchanged until Apply. Test profiles do not
copy sign-in or conversations. Operations are local; release checks contact
GitHub. The distributed app has no third-party package dependency. Browser
regression tooling is used only during development.
