<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/assets/readme-header-dark.svg">
  <img src="docs/assets/readme-header-light.svg" alt="ClaudeFont — fonts, reading layout and colors for Claude desktop" width="1200">
</picture>

**Give Claude desktop the fonts and reading layout you prefer.** Set Chinese and English separately, customize code, and save your style as a reusable theme.

<p>
  <a href="https://github.com/Orxooo/claudefont/releases/latest"><img src="https://img.shields.io/badge/Download-A75E46?style=for-the-badge&logo=apple&logoColor=white" alt="Download for macOS" height="30"></a>
  &nbsp; <a href="README.md">简体中文</a> · <a href="CHANGELOG.md">Changelog</a>
</p>

Apple Silicon · macOS 26+ · GPL-3.0-only · No Python or Xcode needed at runtime

<img src="docs/assets/fonts.png" alt="ClaudeFont font settings with Chinese/English previews and reading layout" width="1200">

<sub>Screenshots are from V1.0.0 (build 4) and retain the historical claudefont name. Current source uses ClaudeFont. Interface previews use sample content.</sub>

## Make it yours

<table>
<tr>
<td width="50%" valign="top"><strong>Separate Chinese and English fonts</strong><br>Choose fonts and sizes for each language, with independent interface scaling.</td>
<td width="50%" valign="top"><strong>A comfortable reading layout</strong><br>Adjust body line height, paragraph spacing and reading width.</td>
</tr>
<tr>
<td width="50%" valign="top"><strong>Individual code regions</strong><br>Customize replies, code blocks, diffs, the editor and terminal.</td>
<td width="50%" valign="top"><strong>Light backgrounds and dark themes</strong><br>Coordinate text, links, code and diff colors.</td>
</tr>
<tr>
<td width="50%" valign="top"><strong>Save and share themes</strong><br>Reading, code review and large-text presets, with JSON import/export.</td>
<td width="50%" valign="top"><strong>Back up, test and restore</strong><br>Complete app backups, independent test copies and operation logs.</td>
</tr>
</table>

<details>
<summary>See Code and Background</summary>

**Code:** Set fonts and sizes by region, with corresponding sample previews.

<img src="docs/assets/code.png" alt="Code page with region fonts and sample preview" width="1200">

**Background:** Configure light backgrounds and dark palettes separately.

<img src="docs/assets/background.png" alt="Background page with light and dark colors" width="1200">

</details>

## Download, customize, apply

1. **Install.** Download the macOS ZIP from [Releases](https://github.com/Orxooo/claudefont/releases/latest), verify its checksum, extract it and move the app to Applications.
2. **Choose a target.** Select Claude and check access in Overview. Start with a test copy.
3. **Customize and apply.** Choose fonts, code and colors, or load a theme. Quit the target Claude completely, then choose Apply settings.
4. **Confirm.** Reopen the selected Claude and check the actual appearance. Choose Restore app to undo changes.

Closing a window does not quit Claude. Previews and loaded themes do not apply automatically. A complete backup is created before writing, with attempted rollback on failure.

<details>
<summary>Download checksums and first launch on macOS</summary>

The existing V1.0.0 (build 4) release is signed with an Apple development certificate and is not notarized. If macOS blocks the first launch, verify the source and checksum, then choose Open Anyway in System Settings → Privacy & Security.

Download `SHA256SUMS.txt` and compare the ZIP's digest with the matching filename:

```sh
shasum -a 256 claudefont-1.0.0-macOS-arm64.zip
```

Current source builds produce `ClaudeFont.app`; historical packages may still use `claudefont.app`. Each release page lists its filenames and version.

</details>

## Before applying

- **Compatibility:** The [existing verification record](docs/VERIFICATION.md) covers startup and Songti rendering on Claude 2.19675.0. Other versions, all code regions, Cowork / virtual machines and account/network features have not been individually verified. Unrecognized terminal resources reject adaptation.
- **Apply and restore:** The tool modifies and re-signs Claude; nested components retain their signatures. Restoration requires a complete pristine backup matching the current version. Without one, [reinstall official Claude](https://claude.ai/download).
- **Test copies and data:** Test copies use separate profiles without copying Main Claude's sign-in or conversations. Operations run locally; update checks contact GitHub Releases.

<details>
<summary>Setting ranges, themes and updates</summary>

- Font scaling: 80%–150%; body line height: 1.2–2.4×; paragraph spacing: 4–40 px; reading width: 480–1100 px.
- English changes can cover replies and headings, or also the interface, input and user messages.
- Light backgrounds and dark themes apply separately, without switching Claude's appearance mode.
- The terminal retains its own character grid and line height. Code ligatures depend on font support.
- Themes share style settings, without font files. Missing fonts are reported.
- Check compatibility after Claude updates before reapplying. Tool updates install manually; same-version builds do not trigger a version notice.

</details>

<details>
<summary>Apply problems, previous changes and issue reports</summary>

Confirm the font is installed, the correct target is selected and Claude has quit completely. If access is denied, follow the App Management instructions and check again.

For existing font modifications, choose Continue previous changes in Overview. Provide a complete pristine `.app` backup of the same version and a settings folder with `config.json` and optional `themes.json`. Apply after validation succeeds.

Use [Issues](https://github.com/Orxooo/claudefont/issues/new/choose) with system, Claude and ClaudeFont versions/build numbers, target type, reproduction steps and redacted logs. Remove usernames, private paths, conversation content and login data.

</details>

<details>
<summary>Local data locations</summary>

| Content | Default location |
| --- | --- |
| Settings and themes | `~/.config/claudefont/` |
| Complete backups, logs and transactions | `~/.local/share/claudefont/` |
| Test app and separate profile | `~/Library/Application Support/claudefont/` |

The rename preserves the bundle ID, CLI command and data directories. A normal replacement retains settings, themes and backups. The tool does not upload conversations, login data or API keys.

</details>

## Development and contribution

[Build and CLI](docs/DEVELOPMENT.md) · [Architecture](docs/ARCHITECTURE.md) · [Verification scope](docs/VERIFICATION.md) · [Contributing](CONTRIBUTING.md)

Use an Xcode / Swift toolchain supporting macOS 26 and a valid Apple signing identity. Keep build output outside the repository and iCloud.

```sh
git clone https://github.com/Orxooo/claudefont.git
cd claudefont
./gui/build.sh
```

---

Copyright © 2026 Orxooo · [GPL-3.0-only](LICENSE) · [Project notices](NOTICE)

ClaudeFont is unaffiliated with Anthropic and distributes neither Claude application code nor font files.
