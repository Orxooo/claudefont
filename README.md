<p align="center">
  <img src="gui/assets/claudefont-icon.png" alt="ClaudeFont 应用图标" width="96">
</p>

<h1 align="center">ClaudeFont</h1>

<p align="center"><strong>让 Claude 桌面版更适合你的阅读与工作习惯。</strong></p>
<p align="center">中英文独立字体 · 阅读排版 · 代码区域设置 · 浅深色配色</p>

<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest"><img src="https://img.shields.io/github/v/release/Orxooo/claudefont?style=flat-square&color=C96049" alt="最新发行版本"></a>
  <img src="https://img.shields.io/badge/macOS-26%2B-242423?style=flat-square" alt="macOS 26+">
  <img src="https://img.shields.io/badge/Apple-Silicon-242423?style=flat-square" alt="Apple Silicon">
  <a href="LICENSE"><img src="https://img.shields.io/badge/License-GPL--3.0--only-C96049?style=flat-square" alt="GPL-3.0-only"></a>
</p>

<p align="center"><b>简体中文</b> · <a href="README.en.md">English</a></p>
<p align="center">
  <a href="https://github.com/Orxooo/claudefont/releases/latest">下载应用</a> ·
  <a href="#快速开始">快速开始</a> ·
  <a href="#常见问题">常见问题</a> ·
  <a href="CHANGELOG.md">更新记录</a> ·
  <a href="https://github.com/Orxooo/claudefont/issues">反馈问题</a>
</p>

---

ClaudeFont 是一款原生 macOS 外观定制工具。为 Claude 桌面应用分别选择中文、英文与代码字体，调整字号、阅读布局和配色，再将常用组合保存为可分享的主题。客户端使用 SwiftUI，发行包内置 Swift 引擎，运行时无需 Python 或 Xcode。

> ClaudeFont 是独立的第三方项目，与 Anthropic 无隶属关系。应用设置会修改并重新签名所选 Claude 的应用包；建议先用测试副本确认效果。

## 功能

| 功能 | 可以调整什么 |
| --- | --- |
| **字体与字号** | 中文、英文和通用代码字体分别设置；界面字号独立调整。英文可仅覆盖回复与标题，或同时覆盖界面、输入框和用户消息。 |
| **阅读排版** | 正文行距、段落间距与阅读宽度，支持保留 Claude 原有排版。 |
| **代码区域** | 回复、代码块与行内代码、Diff、文件编辑器、终端分别设置字体与字号；代码行距与连字单独控制。 |
| **浅深色配色** | 浅色底色预设与自选颜色；深色主题协调正文、链接、代码及 Diff 增删底色，并检查配色可读性。 |
| **主题库** | 中文阅读、代码审查与大字模式预设；命名保存、载入、复制、重命名、删除，以及 JSON 导入导出。 |
| **备份与还原** | 正式 Claude、独立测试副本和自选安装位置；完整应用备份、还原、诊断与操作日志。 |
| **接续已有修改** | 核验并导入设置文件与同版本的完整原版备份，通过后再应用当前设置。 |

字体与字号调整范围为 **80%–150%**；正文行距 **1.2–2.4 倍**、段落间距 **4–40 px**、阅读宽度 **480–1100 px**。终端保留自身字符网格与行距，连字效果取决于所选字体。

## 界面预览

以下截图来自 V1.0.0（构建 4）发行版，保留当时的 `claudefont` 名称；当前源码已统一为 **ClaudeFont**。

<img src="docs/assets/fonts.png" alt="ClaudeFont 字体页：中英文预览、替换范围与字体设置" width="1120">

<details>
<summary>查看代码与配色页面</summary>

### 代码

各区域独立设置，配有代码、Diff、编辑器与终端示例预览。

<img src="docs/assets/code.png" alt="ClaudeFont 代码页：区域字体设置与示例预览" width="1120">

### 背景

分别配置浅色底色与深色主题，预览正文、链接、代码和 Diff 配色。

<img src="docs/assets/background.png" alt="ClaudeFont 背景页：浅深色配色与预览" width="1120">

</details>

预览使用示例内容，不会修改 Claude。最终效果需在应用设置后，到所选 Claude 中确认。

## 安装

**系统要求：** Apple Silicon Mac、macOS 26 或更高版本，以及已安装的 Claude 桌面应用。

1. 从 [最新发行页](https://github.com/Orxooo/claudefont/releases/latest) 下载 macOS 应用 ZIP 与 `SHA256SUMS.txt`。
2. 核对 ZIP 的 SHA-256 摘要，再解压并将应用移到「应用程序」文件夹。
3. 打开应用。若 macOS 阻止首次打开，确认下载来源后，到「系统设置 → 隐私与安全性」选择「仍要打开」。

现有 **V1.0.0（构建 4）** 发行包使用 Apple 开发证书签名，未经 Apple 公证。其文件名仍为 `claudefont-1.0.0-macOS-arm64.zip`，可执行：

```sh
shasum -a 256 claudefont-1.0.0-macOS-arm64.zip
```

将结果与 `SHA256SUMS.txt` 中的同名条目核对。此次源码改名后的构建产物为 **`ClaudeFont.app`**；历史安装包可能仍使用 `claudefont.app` 名称，发行内容以对应发行页为准。

## 快速开始

1. **选择目标。** 在「概览」选择正式 Claude、测试副本或其他安装位置。首次使用建议先建立测试副本。
2. **检测权限。** 点击「检测权限」。若 macOS 拒绝访问，按提示开启「App 管理」权限，再重新检测。
3. **调整外观。** 在「字体」「代码」「背景」选择样式，或从「主题」载入组合。载入主题不会自动应用。
4. **退出并应用。** 从目标 Claude 的应用菜单彻底退出，再点击底部「应用设置」。关闭窗口不等于退出应用。
5. **确认效果。** 重新打开所选 Claude，检查实际字体、配色和常用功能。需要撤销时，在更多操作中选择「还原应用」。

应用前会创建完整备份，随后写入样式、更新完整性信息、重新签名，并使用独立配置检查启动。写入或启动检查失败时会尝试回滚；进度与结果可在日志中查看。

### 使用要点

- **浅色与深色分别生效。** 浅色底色只影响浅色模式，深色主题只影响深色模式；工具不会主动切换 Claude 的外观模式。
- **字体需安装在本机。** 主题 JSON 只包含名称、格式版本与样式设置，不打包字体文件；缺失字体会提示。
- **Claude 更新后先检查。** 更新可能覆盖样式或改变资源结构，建议先在测试副本确认兼容性，再重新应用。
- **测试副本使用独立配置。** 不复制正式 Claude 的登录或会话数据；副本中的账号与网络功能需要单独确认。

## 兼容性与恢复

现有[验证记录](docs/VERIFICATION.md)记录了 **2026-10-03** 在 macOS **27.2**、Claude **2.19675.0** 上的启动与宋体显示检查，以及隔离引擎、动态库、浏览器样式和主题检查。

**其他 Claude 版本、全部代码区域、Cowork / 虚拟机及账号网络功能尚未完成逐项实机验证。** 终端字体依赖可识别的资源结构，无法匹配时会拒绝适配。界面预览和隔离检查不能证明所有 Claude 功能正常；启动检查验证持续运行的渲染进程，不验证账号服务。

修改会改变 Claude 的原始顶层代码签名，嵌套组件保留原有签名。登录及系统权限的影响需在自己的使用环境中确认。

「还原应用」使用完整备份恢复目标。目标已更新时，需要匹配当前版本的原版备份；没有匹配备份时，请从 [Claude 官方下载页](https://claude.ai/download) 重新安装。失败回滚与主动还原的结果，以操作日志为准。

## 常见问题

<details>
<summary>字体没变化，或无法应用？</summary>

确认所选字体已安装、目标选择正确，并已彻底退出 Claude。预览不会自动写入目标，载入主题后也需点击「应用设置」。若提示权限不足，开启「App 管理」后重新检测。

已有字体修改时，在「概览」选择「接续已有修改」，提供同版本的完整原版 `.app` 备份，以及包含 `config.json` 和可选 `themes.json` 的设置文件夹。核验通过后再应用。

</details>

<details>
<summary>工具更新会自动安装吗？同版本的新构建会提示吗？</summary>

更新检查只提示版本并打开 GitHub 发行页，需要手动下载替换。同版本的构建更新不会触发提示，可在「关于」核对构建号与发行说明。

退出旧应用后再替换。改名保留原有 Bundle ID、CLI 命令与数据目录，正常替换应用会保留设置、主题与备份。

</details>

<details>
<summary>设置、备份和测试数据存在哪里？</summary>

| 内容 | 默认位置 |
| --- | --- |
| 设置与主题 | `~/.config/claudefont/` |
| 完整应用备份、日志与事务记录 | `~/.local/share/claudefont/` |
| 测试应用与独立配置 | `~/Library/Application Support/claudefont/` |

操作在本机执行，应用样式不需要读取聊天内容。工具不会上传聊天记录、登录信息或 API 密钥；更新检查会访问 GitHub Releases。

</details>

<details>
<summary>如何反馈问题？</summary>

通过 [Issues](https://github.com/Orxooo/claudefont/issues/new/choose) 提供 macOS、Claude 与 ClaudeFont 版本及构建号、目标类型、字体名称、复现步骤和脱敏日志。截图与日志请移除用户名、私人路径、聊天内容和登录资料。

</details>

## 开发与贡献

客户端、样式引擎、备份和恢复逻辑均在本仓库实现，使用 Swift、SwiftUI、AppKit、CoreText 与 macOS 系统工具。

```sh
git clone https://github.com/Orxooo/claudefont.git
cd claudefont
./gui/build.sh
```

构建需要支持 macOS 26 的 Xcode / Swift 工具链，以及有效的 Apple Development 或 Developer ID Application 签名身份。默认产物为 `~/Library/Caches/claudefont/rewrite-20261002/ClaudeFont.app`；构建输出须在仓库与 iCloud 目录之外。

[构建与 CLI](docs/DEVELOPMENT.md) · [代码结构](docs/ARCHITECTURE.md) · [验证范围与复现](docs/VERIFICATION.md) · [贡献指南](CONTRIBUTING.md)

## 许可

Copyright © 2026 Orxooo。采用 **GPL-3.0-only**，完整条款见 [LICENSE](LICENSE)，项目声明见 [NOTICE](NOTICE)。ClaudeFont 与 Anthropic 无隶属关系，不分发 Claude 的应用代码或字体文件。
