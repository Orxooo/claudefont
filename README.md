<p align="center">
  <img src="gui/assets/claudefont-icon.png" alt="claudefont 图标" width="88">
</p>

<h1 align="center">claudefont</h1>

<p align="center">为 Claude 桌面版设置字体、阅读排版与配色。</p>

<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest"><img src="https://img.shields.io/github/v/release/Orxooo/claudefont" alt="最新版本"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--only-blue" alt="GPL-3.0-only"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-lightgrey" alt="macOS 26+">
</p>

<p align="center"><b>简体中文</b> · <a href="README.en.md">English</a></p>

**[下载 claudefont](https://github.com/Orxooo/claudefont/releases/download/v1.0.0/claudefont-1.0.0-macOS-arm64.zip)** · [更新记录](CHANGELOG.md) · [反馈问题](https://github.com/Orxooo/claudefont/issues)

当前版本 **V1.0.0（构建 4）**。需要 **Apple Silicon Mac、macOS 26+** 和 Claude 桌面版。

<img src="docs/assets/fonts.png" alt="claudefont 字体设置页面" width="960">

## 可以调整什么

- **字体**：中文、英文、界面与代码字体，以及各区域的字号。
- **排版**：正文行距、段落间距、阅读宽度、代码行距与连字。
- **配色**：浅色阅读底色与深色主题。
- **主题与还原**：保存和导入导出设置，创建独立测试副本，备份和还原应用。

<details>
<summary>查看代码与配色页面</summary>

<img src="docs/assets/code.png" alt="代码字体设置与示例预览" width="960">
<img src="docs/assets/background.png" alt="阅读底色与深色配色设置" width="960">

</details>

## 快速开始

1. **安装**：下载上方 ZIP，解压，将 `claudefont.app` 放入「应用程序」并打开。
2. **选择目标**：在「概览」选择正式 Claude 或测试副本。首次使用建议先在测试副本确认效果。
3. **设置样式**：在「字体」「代码」「背景」调整，或从「主题」载入组合。
4. **应用**：从 Claude 菜单彻底退出应用，再点击 claudefont 的「应用设置」。关闭窗口不等于退出。
5. **检查效果**：重新打开所选 Claude，查看实际字体和排版。需要撤销时，在更多操作中选择「还原应用」。

应用前会备份完整的 Claude 应用；写入或启动检查失败时会回滚。客户端预览使用示例内容，实际效果以 Claude 页面为准。

## 常见问题

<details>
<summary>macOS 阻止打开，怎么办？</summary>

发行包使用 Apple 开发证书签名，未经 Apple 公证。核对下载来源和文件摘要后，可在「系统设置 → 隐私与安全性」中允许打开。

在 [发行页](https://github.com/Orxooo/claudefont/releases/latest) 下载 `SHA256SUMS.txt`，然后计算客户端 ZIP 的摘要，与清单中的同名条目核对：

```sh
shasum -a 256 claudefont-1.0.0-macOS-arm64.zip
```

</details>

<details>
<summary>无法应用，或字体没有变化？</summary>

- 确认所选字体已安装在 macOS 中。
- 确认已彻底退出所选 Claude，再应用设置。
- 若提示权限不足，按客户端提示开启 macOS「App 管理」权限，再重新检测。
- 若目标已有字体修改，在「概览」选择「接续已有修改」，提供同版本的完整原版 `.app` 备份，以及含 `config.json` 和可选 `themes.json` 的设置文件夹。核验通过后，再应用当前设置。

仍有问题时，请提交版本与构建号、复现步骤和脱敏日志。

</details>

<details>
<summary>Claude 更新后，或者下载了较早构建，如何处理？</summary>

Claude 更新可能改变资源结构，需要重新检查兼容性，并先在测试副本验证。

客户端更新采用手动下载替换。目前版本号为 1.0.0；若「关于」显示的构建号低于 4，请重新下载。同版本构建不会触发更新提示。

本机已验证 Claude 2.19675.0 的启动与宋体显示。其他版本及全部代码区域的验证范围见 [验证记录](docs/VERIFICATION.md)。终端字体仅在资源结构匹配时适配。

</details>

<details>
<summary>设置、备份和测试数据存在哪里？</summary>

| 内容 | 位置 |
| --- | --- |
| 设置与主题 | `~/.config/claudefont/` |
| 应用备份、日志与事务记录 | `~/.local/share/claudefont/` |
| 测试副本与独立配置 | `~/Library/Application Support/claudefont/` |

测试副本使用独立配置，不复制正式 Claude 的登录和会话数据。应用修改会改变 Claude 的代码签名，还原使用完整备份。

</details>

操作在本机执行，不读取或上传聊天记录、登录信息或 API 密钥。更新检查会访问 GitHub Releases。

## 开发与贡献

claudefont 使用 Swift、SwiftUI 与 macOS 系统工具，客户端和引擎在本仓库实现。发行客户端无需 Python 或 Xcode。

[构建与 CLI](docs/DEVELOPMENT.md) · [代码结构](docs/ARCHITECTURE.md) · [验证记录](docs/VERIFICATION.md) · [贡献指南](CONTRIBUTING.md)

## 许可

Copyright © 2026 Orxooo。采用 **GPL-3.0-only**，完整条款见 [LICENSE](LICENSE)，项目声明见 [NOTICE](NOTICE)。

claudefont 与 Anthropic 无隶属关系，不分发 Claude 的应用代码。
