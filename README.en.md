<p align="center">
  <img src="gui/assets/claudefont-icon.png" alt="claudefont icon" width="88">
</p>

<h1 align="center">claudefont</h1>

<p align="center">Fonts, reading layout and colors for Claude desktop.</p>

<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest"><img src="https://img.shields.io/github/v/release/Orxooo/claudefont" alt="Latest release"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--only-blue" alt="GPL-3.0-only"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-lightgrey" alt="macOS 26+">
</p>

<p align="center"><a href="README.md">简体中文</a> · <b>English</b></p>

**[Download claudefont](https://github.com/Orxooo/claudefont/releases/download/v1.0.0/claudefont-1.0.0-macOS-arm64.zip)** · [Changelog](CHANGELOG.md) · [Report an issue](https://github.com/Orxooo/claudefont/issues)

Current version: **V1.0.0 (build 4)**. Requires **Apple Silicon, macOS 26+** and Claude desktop.

<img src="docs/assets/fonts.png" alt="claudefont font settings" width="960">

## What you can adjust

- **Fonts**: Chinese, English, interface and code fonts, with per-region sizes.
- **Layout**: Reading line height, paragraph spacing, width, code line height and ligatures.
- **Colors**: Light reading backgrounds and dark themes.
- **Themes and restoration**: Save/import/export settings, create independent test copies, back up and restore apps.

<details>
<summary>See code and color settings</summary>

<img src="docs/assets/code.png" alt="Code font settings and sample preview" width="960">
<img src="docs/assets/background.png" alt="Reading backgrounds and dark colors" width="960">

</details>

## Quick start

1. **Install**: Download the ZIP above, extract it and move `claudefont.app` into Applications.
2. **Choose a target**: Select the main Claude or a test copy in Overview. Verify a test copy first.
3. **Set the style**: Adjust Fonts, Code and Background, or load a theme.
4. **Apply**: Quit Claude from its app menu, then choose Apply changes in claudefont. Closing its window is insufficient.
5. **Check**: Reopen the selected Claude and inspect the actual fonts and layout. Use Restore app in the actions menu to undo changes.

Apply preserves a complete app backup. Failed writes or startup checks trigger rollback. Client previews use sample content; check the real Claude page for the result.

## FAQ

<details>
<summary>What if macOS blocks the app?</summary>

The release is signed with an Apple development certificate and is not notarized. Verify its source and checksum, then allow it in System Settings → Privacy & Security.

Download `SHA256SUMS.txt` from the [release page](https://github.com/Orxooo/claudefont/releases/latest). Compute the app ZIP's digest and compare it with the matching filename:

```sh
shasum -a 256 claudefont-1.0.0-macOS-arm64.zip
```

</details>

<details>
<summary>Why can't I apply changes, or why is the font unchanged?</summary>

- Confirm the font is installed in macOS.
- Quit the selected Claude completely before applying.
- If access is denied, follow the client's App Management permission instructions and check again.
- For a target with existing font changes, choose Continue previous changes in Overview. Provide a complete pristine `.app` backup of the same version and a settings folder with `config.json` and optional `themes.json`. Apply after validation succeeds.

Include version/build numbers, reproduction steps and redacted logs in issue reports.

</details>

<details>
<summary>What about Claude updates or earlier claudefont builds?</summary>

Claude updates can change resources. Check compatibility again and verify a test copy.

Client updates are manual downloads. The current version is 1.0.0; download again if About shows a build below 4. Release checks do not notify you about same-version build changes.

Startup and Songti rendering were verified on local Claude 2.19675.0. See the [verification record](docs/VERIFICATION.md) for other versions and code-region limits. Terminal fonts require matching resource structures.

</details>

<details>
<summary>Where are settings, backups and test data stored?</summary>

| Data | Location |
| --- | --- |
| Settings and themes | `~/.config/claudefont/` |
| App backups, logs and transactions | `~/.local/share/claudefont/` |
| Test app and independent profile | `~/Library/Application Support/claudefont/` |

Test copies do not copy the main Claude's sign-in or sessions. Applying changes alters Claude's code signature; Restore uses the complete backup.

</details>

Operations are local and do not read or upload conversations, credentials or API keys. Release checks contact GitHub Releases.

## Development and contribution

Built with Swift, SwiftUI and macOS system tools. The client and engine are implemented in this repository. The packaged app needs neither Python nor Xcode.

[Build and CLI](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Verification](docs/VERIFICATION.md) · [Contributing](CONTRIBUTING.md)

## License

Copyright © 2026 Orxooo. **GPL-3.0-only**. See [LICENSE](LICENSE) for the full terms and [NOTICE](NOTICE) for project notices.

claudefont is unaffiliated with Anthropic and distributes no Claude application code.
