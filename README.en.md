<p align="center">
  <img src="gui/assets/claudefont-icon.png" alt="ClaudeFont app icon" width="96">
</p>

<h1 align="center">ClaudeFont</h1>

<p align="center"><strong>Make Claude desktop fit the way you read and work.</strong></p>
<p align="center">Independent Chinese and English fonts · Reading layout · Code region controls · Light and dark colors</p>

<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest"><img src="https://img.shields.io/github/v/release/Orxooo/claudefont?style=flat-square&color=C96049" alt="Latest release"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-242423?style=flat-square" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Apple-Silicon-242423?style=flat-square" alt="Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--only-C96049?style=flat-square" alt="GPL-3.0-only"></a>
</p>

<p align="center"><a href="README.md">简体中文</a> · <b>English</b></p>
<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest">Download</a> ·
  <a href="#quick-start">Quick start</a> ·
  <a href="#faq">FAQ</a> ·
  <a href="CHANGELOG.md">Changelog</a> ·
  <a href="https://github.com/Orxooo/claudefont/issues">Report an issue</a>
</p>

---

ClaudeFont is a native macOS appearance tool. Choose separate Chinese, English and code fonts in the Claude desktop app, adjust sizes, reading layout and colors, and save your preferences as shareable themes. The SwiftUI client includes a Swift engine; release packages need neither Python nor Xcode at runtime.

> ClaudeFont is an independent third-party project, unaffiliated with Anthropic. Applying settings modifies and re-signs the selected Claude app bundle. Start with a test copy.

## Features

| Feature | What you can customize |
| --- | --- |
| **Fonts and sizes** | Separate Chinese, English and shared code fonts, plus independent interface scaling. English changes can cover replies and headings, or also the interface, input and user messages. |
| **Reading layout** | Body line height, paragraph spacing and reading width, with options to keep Claude's original layout. |
| **Code regions** | Fonts and sizes for replies, code blocks and inline code, diffs, the file editor and terminal; separate controls for code line height and ligatures. |
| **Light and dark colors** | Light background presets and custom colors; dark palettes coordinating text, links, code and diff additions/deletions, with readability checks. |
| **Theme library** | Chinese reading, code review and large-text presets. Save, load, duplicate, rename and delete themes, or import/export JSON. |
| **Backup and restoration** | Main Claude, an independent test copy and custom installations; complete app backups, restoration, diagnostics and operation logs. |
| **Continue previous changes** | Validate and import settings with a complete pristine backup of the same version, then apply your current settings. |

Font scaling ranges from **80% to 150%**; body line height is **1.2–2.4×**, paragraph spacing **4–40 px**, and reading width **480–1100 px**. The terminal retains its own character grid and line height. Ligature support depends on the selected font.

## Screenshots

These screenshots are from V1.0.0 (build 4) and retain the earlier `claudefont` name. The current source uses **ClaudeFont** throughout.

<img src="docs/assets/fonts.png" alt="ClaudeFont Fonts page with Chinese and English previews, scope and font settings" width="1120">

<details>
<summary>View Code and Background</summary>

### Code

Independent region settings, with sample previews for code, diffs, the editor and terminal.

<img src="docs/assets/code.png" alt="ClaudeFont Code page with region settings and sample preview" width="1120">

### Background

Separate light backgrounds and dark palettes, with previews for text, links, code and diffs.

<img src="docs/assets/background.png" alt="ClaudeFont Background page with light/dark colors and preview" width="1120">

</details>

Previews use sample content and do not modify Claude. Confirm the final appearance in the selected Claude after applying.

## Installation

**Requirements:** an Apple Silicon Mac, macOS 26 or later, and an installed Claude desktop app.

1. Download the macOS app ZIP and `SHA256SUMS.txt` from the [latest release](https://github.com/Orxooo/claudefont/releases/latest).
2. Verify the ZIP's SHA-256, extract it and move the app to Applications.
3. Open the app. If macOS blocks the first launch, verify the source, then choose Open Anyway in System Settings → Privacy & Security.

The existing **V1.0.0 (build 4)** release is signed with an Apple development certificate and is not notarized. Its filename remains `claudefont-1.0.0-macOS-arm64.zip`:

```sh
shasum -a 256 claudefont-1.0.0-macOS-arm64.zip
```

Compare the result with the matching filename in `SHA256SUMS.txt`. Source builds with this rename produce **`ClaudeFont.app`**. Historical packages may still use `claudefont.app`; each release page describes its contents.

## Quick start

1. **Choose a target.** In Overview, select Main Claude, a test copy or another installation. Start by creating a test copy.
2. **Check access.** Choose Check access. If macOS denies access, follow the App Management instructions and check again.
3. **Set the appearance.** Use Fonts, Code and Background, or load a theme. Loading a theme does not apply it automatically.
4. **Quit and apply.** Quit the target Claude from its app menu, then choose Apply settings at the bottom. Closing a window does not quit the app.
5. **Confirm the result.** Reopen the selected Claude and check the appearance and your usual workflows. Choose Restore app from the actions menu to undo changes.

Applying creates a complete backup, writes styles, updates integrity metadata, re-signs the app and checks startup using an independent profile. Failed writes or startup checks trigger an attempted rollback; logs show progress and results.

### Usage notes

- **Light and dark settings apply separately.** Light backgrounds affect light mode; dark themes affect dark mode. The tool does not switch Claude's appearance mode.
- **Fonts must be installed locally.** Theme JSON includes only the name, schema version and style settings, without font files. Missing fonts are reported.
- **Check after Claude updates.** Updates may overwrite styles or change resource structures. Confirm compatibility in a test copy before reapplying.
- **Test copies use independent profiles.** They do not copy Main Claude's sign-in or conversations. Account and network features in a test copy need separate confirmation.

## Compatibility and recovery

The existing [verification record](docs/VERIFICATION.md) documents startup and Songti rendering on **2026-10-03**, with macOS **27.2** and Claude **2.19675.0**, along with isolated engine, library-loading, browser styling and theme checks.

**Other Claude versions, all code regions, Cowork / virtual machines and account/network functions have not completed individual checks in the actual app.** Terminal fonts require recognizable resources; unmatched structures reject adaptation. Previews and isolated checks do not establish that every Claude feature works. Startup checks verify a persistent renderer, without verifying account services.

Applying changes alters Claude's original top-level code signature; nested components retain their existing signatures. Confirm sign-in and system permission behavior in your own environment.

Restore app uses a complete backup. After a target update, restoration requires a pristine backup matching that version. Without one, reinstall from the [official Claude download page](https://claude.ai/download). Check operation logs for rollback and restoration results.

## FAQ

<details>
<summary>Why is the font unchanged, or why can't I apply?</summary>

Confirm that the font is installed, the correct target is selected and Claude has quit completely. Previews and loaded themes do not apply automatically. Choose Apply settings. If access is denied, enable App Management and check again.

For existing font modifications, choose Continue previous changes in Overview. Supply a complete pristine `.app` backup of the same version and a settings folder with `config.json` and optional `themes.json`. Apply after validation succeeds.

</details>

<details>
<summary>Do updates install automatically? Are same-version builds announced?</summary>

Update checks announce versions and open GitHub Releases; download and replace the app manually. A new build with the same version does not trigger a notice. Compare the build number in About with the release notes.

Quit the old app before replacing it. The rename preserves the bundle ID, CLI command and data directories, so a normal replacement retains settings, themes and backups.

</details>

<details>
<summary>Where are settings, backups and test data stored?</summary>

| Content | Default location |
| --- | --- |
| Settings and themes | `~/.config/claudefont/` |
| Complete app backups, logs and transactions | `~/.local/share/claudefont/` |
| Test app and independent profile | `~/Library/Application Support/claudefont/` |

Operations run locally; applying styles does not require reading conversation content. The tool does not upload conversations, login data or API keys. Update checks contact GitHub Releases.

</details>

<details>
<summary>How should I report an issue?</summary>

Use [Issues](https://github.com/Orxooo/claudefont/issues/new/choose) with macOS, Claude and ClaudeFont versions/build numbers, target type, font names, reproduction steps and redacted logs. Remove usernames, private paths, conversation content and login data from logs and screenshots.

</details>

## Development and contribution

The client, style engine, backup and recovery logic are implemented in this repository using Swift, SwiftUI, AppKit, CoreText and macOS system tools.

```sh
git clone https://github.com/Orxooo/claudefont.git
cd claudefont
./gui/build.sh
```

Builds require an Xcode / Swift toolchain supporting macOS 26 and a valid Apple Development or Developer ID Application signing identity. The default output is `~/Library/Caches/claudefont/rewrite-20261002/ClaudeFont.app`. Keep build output outside the repository and iCloud.

[Build and CLI](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Verification scope and reproduction](docs/VERIFICATION.md) · [Contributing](CONTRIBUTING.md)

## License

Copyright © 2026 Orxooo. **GPL-3.0-only**; see [LICENSE](LICENSE) and [NOTICE](NOTICE). ClaudeFont is unaffiliated with Anthropic and distributes neither Claude application code nor font files.
