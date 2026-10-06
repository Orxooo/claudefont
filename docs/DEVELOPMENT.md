# 构建与 CLI / Build and CLI

[简体中文 README](../README.md) · [English README](../README.en.md)

## 开发环境

- Apple Silicon Mac，macOS 26+。
- Xcode 26+（含 macOS SDK），已配置命令行工具。
- GUI 构建需要钥匙串中有效的 Apple Development 或 Developer ID Application 签名身份。
- 自动化检查另需 Python 3；浏览器检查使用 Node.js/npm 和 agent-browser。见 [验证记录](VERIFICATION.md)。

## 构建客户端

```sh
git clone https://github.com/Orxooo/claudefont.git
cd claudefont
./gui/build.sh
```

默认产物位于 `~/Library/Caches/claudefont/rewrite-20261002/ClaudeFont.app`。

`CLAUDEFONT_BUILD_DIR` 仅接受以下目录的子目录，且必须在仓库和 iCloud 外：

- `~/Library/Caches/claudefont/`
- `~/Library/Application Support/claudefont-development/`

有多个签名身份时，用 `CLAUDEFONT_SIGN_IDENTITY` 指定其中一个；没有签名身份时，应先配置证书。

## 构建 CLI

```sh
./cli/build.sh "$HOME/Library/Caches/claudefont/cli/claudefont"
CLAUDEFONT_SWIFT_BIN="$HOME/Library/Caches/claudefont/cli/claudefont" ./claudefont --help
```

发行包的 CLI 位于 `ClaudeFont.app/Contents/Resources/claudefont`。

| 命令 | 用途 |
| --- | --- |
| `status` | 目标状态与兼容性；支持 `--json` |
| `doctor` | 诊断；通过临时探针检查写权限 |
| `install` | 备份并应用设置 |
| `uninstall` | 从完整备份还原 |
| `backups` | 查看及管理备份；支持 `--json` |
| `migrate` | 核验并导入设置与匹配的原版备份 |

使用 `--help` 查看完整参数。应用和还原前须退出目标。

配置读取路径可用 `CLAUDEFONT_CONFIG` 覆盖；备份与日志目录可用 `CLAUDEFONT_DATA_DIR` 覆盖。

## English

Development requires Apple Silicon, macOS 26+, Xcode 26+ with its macOS SDK and configured command-line tools. GUI builds need a valid Apple Development or Developer ID Application identity in Keychain.

Use the client and CLI commands above. Default app output is `~/Library/Caches/claudefont/rewrite-20261002/ClaudeFont.app`. Override `CLAUDEFONT_BUILD_DIR` only with a subdirectory of the two listed build roots, outside the repository and iCloud. Select a signing identity with `CLAUDEFONT_SIGN_IDENTITY` when several are available.

The bundled CLI supports status/diagnostics, apply/restore, backup management and validated import. `status` and `backups` offer JSON output. `doctor` probes write access with a temporary file. Quit the target before apply/restore. Use `--help` for flags.

`CLAUDEFONT_CONFIG` overrides the settings file; `CLAUDEFONT_DATA_DIR` overrides backups/logs. Test requirements and scope are in [VERIFICATION.md](VERIFICATION.md).
