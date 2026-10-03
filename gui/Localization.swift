// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Orxooo
import SwiftUI

enum Lang: String, CaseIterable, Identifiable {
    case auto, zh, en
    var id: String { rawValue }
}
final class Copy: ObservableObject {
    static let shared = Copy()
    @Published var lang: Lang {
        didSet { UserDefaults.standard.set(lang.rawValue, forKey: "interfaceLanguage") }
    }
    private init() { lang = Lang(rawValue: UserDefaults.standard.string(forKey: "interfaceLanguage") ?? "auto") ?? .auto }
    var effective: Lang {
        lang == .auto ? (Locale.preferredLanguages.first?.hasPrefix("zh") == true ? .zh : .en) : lang
    }
}
func t(_ key: String, _ replacements: [String:String] = [:]) -> String {
    let pair = localization[key] ?? (key, key)
    var result = Copy.shared.effective == .zh ? pair.0 : pair.1
    for (token, value) in replacements { result = result.replacingOccurrences(of: token, with: value) }
    return result
}
private let localization: [String:(String,String)] = [
    "about.title": ("关于 claudefont", "About claudefont"),
    "about.version": ("版本 {v} · 构建 {b}", "Version {v} · Build {b}"),
    "about.tagline": ("为 Claude 桌面版调整字体、阅读排版和配色。", "Tune fonts, reading layout and colors in Claude Desktop."),
    "about.lang": ("界面语言", "Language"), "about.lang.auto": ("跟随系统", "System language"),
    "about.footer": ("GPL-3.0-only 开源软件。与 Anthropic 无隶属关系。", "Open source under GPL-3.0-only. Unaffiliated with Anthropic."),
    "action.doctor": ("自检", "Diagnose"), "action.open": ("打开目标", "Open target"),
    "action.restore": ("还原应用", "Restore app"), "action.apply": ("应用到 {target}", "Apply to {target}"),
    "action.reapply": ("重新应用到 {target}", "Reapply to {target}"),
    "appmgmt.body": ("macOS 拒绝修改目标。请检查 App 管理权限，再重新检测。", "macOS denied changes to the target. Check App Management access, then diagnose again."),
    "appmgmt.open": ("打开系统设置", "Open System Settings"), "appmgmt.recheck": ("重新检测", "Check again"),
    "code.desc": ("选择已安装的等宽字体，留空保持原样。", "Choose an installed monospace font, or leave the current font unchanged."),
    "code.font": ("代码字体", "Code font"), "code.keep": ("保持原有字体", "Keep existing font"), "code.size": ("代码字号", "Code size"),
    "code.region.reply": ("代码回复", "Code reply"), "code.region.block": ("代码块", "Code block"),
    "code.region.diff": ("差异", "Diff"), "code.region.editor": ("编辑器", "Editor"), "code.region.terminal": ("终端", "Terminal"),
    "detail.prune": ("清理 {n} 份旧备份", "Prune {n} old backups"),
    "font.cjk": ("中文字体", "Chinese font"), "font.cjk.size": ("中文字号", "Chinese size"),
    "font.latin": ("英文字体", "English font"), "font.latin.size": ("英文字号", "English size"),
    "font.latin.all": ("所有文字区域", "All text regions"), "font.latin.body": ("仅正文", "Body only"),
    "font.latin.where.desc": ("选择英文字体覆盖的区域。", "Choose where English font overrides apply."),
    "font.mode": ("覆盖方式", "Coverage"), "font.mode.desc": ("扩展覆盖可用于标准方式未覆盖的文字。", "Extended coverage can reach text outside standard coverage."),
    "font.mode.ext": ("扩展", "Extended"), "font.mode.std": ("标准", "Standard"),
    "font.preview.cjk": ("清晰的字形，让阅读回归内容。", "Clear type keeps attention on the content."),
    "font.reset": ("恢复默认大小", "Reset size"), "font.scope.both": ("中文与英文", "Chinese and English"),
    "font.scope.cjk": ("中文", "Chinese"), "font.scope.latin": ("英文", "English"),
    "font.scope.desc": ("选择需要替换字体的语言。", "Choose the language whose fonts should change."),
    "font.ui.size": ("界面字号", "Interface size"),
    "help.title": ("使用说明", "Help"), "helper.title": ("命令工具不可用", "Command tool unavailable"),
    "helper.body": ("请使用完整的 claudefont 应用包。", "Use a complete claudefont app bundle."), "log.clear": ("清空显示", "Clear display"),
    "look.bg.blue": ("浅蓝", "Pale blue"), "look.bg.classic": ("暖纸", "Warm paper"),
    "look.bg.custom": ("自定义", "Custom"), "look.bg.darknow": ("当前系统为深色模式，浅色底色将在浅色模式中显示。", "The system is dark; this background appears in light mode."),
    "look.bg.desc": ("浅色模式的阅读底色。", "Reading background for light mode."), "look.bg.grey": ("浅灰", "Soft gray"),
    "look.bg.light": ("米白", "Cream"), "look.bg.off": ("原有底色", "Original"),
    "look.bg.toodark": ("底色与正文对比不足，请选择更浅的颜色。", "Text contrast is too low. Choose a lighter background."),
    "sheet.apply.go": ("备份并应用", "Back up and apply"),
    "sheet.applying.keychain": ("签名过程中 macOS 可能请求使用开发证书。", "macOS may request access to the development certificate during signing."),
    "sheet.applying.title": ("正在应用", "Applying changes"), "sheet.cancel": ("取消", "Cancel"), "sheet.ok": ("好", "OK"),
    "sheet.create.body": ("复制所选 Claude 应用并建立空白独立配置。不复制登录信息或会话。重建会替换已有测试副本。", "Copy the selected Claude app with a fresh separate profile. Sign-in and sessions are not copied. Rebuilding replaces the existing test copy."),
    "sheet.create.title": ("建立测试副本？", "Create a test copy?"),
    "sheet.delete.body": ("删除 claudefont 管理的测试应用和测试配置。", "Remove the test app and profile managed by claudefont."),
    "sheet.delete.ok": ("删除测试副本", "Delete test copy"), "sheet.delete.title": ("删除测试副本？", "Delete test copy?"),
    "sheet.restart.body": ("已写入设置。请在打开的 Claude 中核验实际效果。", "Settings were written. Check the result in Claude."),
    "sheet.restart.title": ("设置已应用", "Changes applied"),
    "sheet.restore.body": ("从完整备份还原 {target}。还原前请关闭目标应用。", "Restore {target} from its full backup. Close the target app first."),
    "sheet.restore.title": ("还原目标应用？", "Restore target app?"),
    "stale.body": ("目标已变化，请先检查兼容性，再重新应用设置。", "The target changed. Check compatibility before reapplying."), "stale.title": ("需要重新检查", "Check again"),
    "status.loading": ("读取状态中", "Reading status"), "status.missing": ("未找到应用", "App not found"),
    "status.stale": ("应用已变化", "App changed"), "status.applied": ("样式已应用", "Styles applied"), "status.none": ("尚未应用样式", "No styles applied"),
    "target.choose": ("选择应用…", "Choose app…"), "target.choose.msg": ("选择 Claude 的 .app 文件。", "Select Claude’s .app bundle."),
    "target.create": ("建立测试副本", "Create test copy"), "target.delete": ("删除测试副本", "Delete test copy"),
    "target.forget": ("忘记此路径", "Forget this path"), "target.none": ("尚未建立", "Not available"), "target.rebuild": ("重建测试副本", "Rebuild test copy"),
    "update.auto": ("自动检查新版本", "Check for updates automatically"), "update.body": ("可前往 GitHub 查看变更并下载。", "View the changes and download on GitHub."),
    "update.download": ("查看发行版", "View release"), "update.later": ("忽略此版本", "Skip this version"), "update.title": ("发现新版本 {tag}", "New version {tag}")
]
