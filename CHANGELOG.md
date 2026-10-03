# Changelog

## V1.0.0 · build 4 — 2026-10-03

首个稳定版本，采用 GPL-3.0-only。

### 功能

- SwiftUI 原生客户端，中文与英文界面，六页工作区。
- 中文、英文、界面和代码字体，字号、阅读排版与深浅配色。
- 主题保存、载入与 JSON 导入导出。
- 目标选择、独立测试副本、完整应用备份、还原、诊断和日志。
- 经核验的设置与同版本原版备份导入。
- GitHub Releases 更新检查与手动下载。

### 构建 4 修正

- CoreText 解析真实本地字形名称，修复字体无法加载。
- 修复重新签名后的 Electron 动态库加载崩溃，保留嵌套框架签名。
- 验证持续运行的 renderer，加载失败或反复重启会回滚。
- 修复测试副本的运行文件签名与 helper 名称解析。
- 应用前提示退出；统一通知圆角，去掉菜单多余描边和图标白色外圈。

65 项引擎、6 项动态库/启动和 18 项浏览器样式/字形加载检查通过。
本机 Claude 2.19675.0 已确认启动与宋体显示。范围见 [验证记录](docs/VERIFICATION.md)。
已安装较早构建的用户请重新下载；版本仍为 1.0.0，同版本构建不会触发更新提示。

### English

The first stable release includes a bilingual native SwiftUI workspace, font
and typography settings, light/dark colors, portable themes, independent test
copies, full backups/restoration, diagnostics and GitHub release checks.

Build 4 resolves local font-face names with CoreText, fixes Electron library
loading after signing, validates persistent renderer readiness, repairs test
launcher signing/helper lookup and refines notification corners, dropdown
focus and the icon. Recorded results: 65 engine, 6 loader and 18 browser/font-load
checks passed. Startup and Songti glyphs were observed on local Claude 2.19675.0.
See the verification record for limits. Version remains 1.0.0; replace earlier
builds manually.
