# Contributing to ClaudeFont

欢迎提交问题与改进。先阅读 [README](README.md)、
[代码结构](docs/ARCHITECTURE.md)和 [验证记录](docs/VERIFICATION.md)。

## 问题反馈

使用 Bug report 或 Feature request 模板。注明 macOS、Claude、ClaudeFont
版本与构建号、目标、字体名称和复现步骤。日志和截图请移除登录信息、
API 密钥、用户名、私人路径与聊天内容。

## 代码修改

- 使用 Swift/SwiftUI；不要提交应用包、字体文件、用户备份或个人配置。
- 构建与测试输出放在仓库之外。签名要求见 [构建说明](docs/DEVELOPMENT.md)。
- 验证受影响的行为，分别说明样本检查与实际 Claude 检查。
- 同步中英文文案；公开接口变化时更新文档。
- Pull request 简述改动、原因、结果及未验证范围。
- 项目使用 GPL-3.0-only；沿用 SPDX 声明，保留适用的版权及第三方声明。

## English

Read the README, architecture and verification notes first. Use issue templates
with OS/app/build versions and reproduction steps; redact sensitive data.

Keep build/test output outside the repository. Do not commit app packages,
fonts, personal settings or backups. Verify affected behavior, keep bilingual
copy aligned and report changes, results and untested scope in pull requests.
The project is GPL-3.0-only; retain applicable copyright and licensing notices.
