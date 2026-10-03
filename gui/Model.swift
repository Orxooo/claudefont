// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Orxooo
import SwiftUI
import AppKit
import CoreText

struct FontChoice: Identifiable {
    let family: String
    let localized: String?
    var id: String { family }
}
enum FontScanner {
    static func choices() -> (chinese: [FontChoice], latin: [FontChoice], mono: [FontChoice]) {
        let all = NSFontManager.shared.availableFontFamilies.sorted().map { family in
            FontChoice(family: family, localized: NSFontManager.shared.localizedName(forFamily: family, face: nil))
        }
        let chinese = all.filter {
            let f = CTFontCreateWithName($0.family as CFString, 14, nil)
            var character: UniChar = 0x4E2D; var glyph: CGGlyph = 0
            return CTFontGetGlyphsForCharacters(f, &character, &glyph, 1)
        }
        let mono = all.filter { family in
            guard let f = NSFont(name: family.family, size: 14) else { return false }
            return f.isFixedPitch || NSFontManager.shared.traits(of: f).contains(.fixedPitchFontMask)
        }
        return (chinese, all, mono)
    }
}
enum CodeRegion: String, CaseIterable, Identifiable {
    case reply, block, diff, editor, terminal
    var id: String { rawValue }
    var title: String { t("code.region." + rawValue) }
    var sample: String {
        switch self {
        case .reply: return "Let's make the output easier to read.\nconst title = \"Hello, 字体\";\nreturn title;"
        case .block: return "let title = \"Hello, 字体\"\nprint(title)\n// Simple and readable"
        case .diff: return "- let title = \"Hello\"\n+ let title = \"Hello, 字体\"\n  print(title)"
        case .editor: return "    let title = \"Hello, 字体\"\n    func greet() {\n        print(title)\n    }"
        case .terminal: return "$ swift greeting.swift\nHello, 字体\n$ git status --short"
        }
    }
}
struct CodeRegionSetting { var font = ""; var scale = 100.0 }
enum ClassicPreset { static let font = "Songti SC"; static let scale = 110.0; static let bg = "#F0EEE6" }
enum Target: String, CaseIterable, Identifiable {
    case production, testCopy, custom
    var id: String { rawValue }
    var label: String {
        let zh = Copy.shared.effective == .zh
        switch self {
        case .production: return zh ? "正式 Claude" : "Main Claude"
        case .testCopy: return zh ? "测试 Claude" : "Test Claude"
        case .custom: return zh ? "所选应用" : "Selected app"
        }
    }
}
struct TargetStatus {
    var loaded = false
    var missing = false
    var patched = false
    var stale = false
    var helperOK = true
    var canApply = false
    var settingsMatch = false
    var state = "loading"
    var reason = ""
    var version = "—"
    var font = ""
    var checkedAt = ""
    var signOK: Bool?
    var integrityOK: Bool?
    var backups: [String] = []
    var compatibility: CompatibilityStatus?
}
struct BackupInfo { var summary: String; var prunable: Int }
private struct StatusResponse: Decodable {
    let version: String
    let state: String
    let canApply: Bool
    let settingsMatch: Bool
    let permissionDenied: Bool
    let compatibility: CompatibilityStatus?
    let signOK: Bool?
    let integrityOK: Bool?
    let backups: Int?
    let font: String?
    let reason: String?
}
private struct BackupsResponse: Decodable { let summary: String; let prunable: Int }
struct CommandResult { let status: Int32; let output: Data; let error: Data }

// Each pipe has its own drain task; neither stream can block process completion.
enum CommandRunner {
    static func run(_ executable: URL, _ arguments: [String], environment: [String:String],
                    stream: ((String) -> Void)? = nil, completion: @escaping (CommandResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process(); process.executableURL = executable; process.arguments = arguments
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
            let stdout = Pipe(), stderr = Pipe(); process.standardOutput = stdout; process.standardError = stderr
            do { try process.run() }
            catch {
                DispatchQueue.main.async { completion(CommandResult(status: -1, output: Data(), error: Data(error.localizedDescription.utf8))) }
                return
            }
            let group = DispatchGroup()
            let buffers = StreamBuffers()
            for (pipe, isError) in [(stdout, false), (stderr, true)] {
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    var data = Data()
                    var pending = Data()
                    while true {
                        let chunk = pipe.fileHandleForReading.availableData
                        if chunk.isEmpty { break }
                        data.append(chunk)
                        if let stream {
                            pending.append(chunk)
                            if let newline = pending.lastIndex(of: 10) {
                                let end = pending.index(after: newline)
                                let text = String(decoding: pending[..<end], as: UTF8.self)
                                pending.removeSubrange(..<end)
                                DispatchQueue.main.async { stream(text) }
                            }
                        }
                    }
                    if let stream, !pending.isEmpty {
                        let text = String(decoding: pending, as: UTF8.self)
                        DispatchQueue.main.async { stream(text) }
                    }
                    if isError { buffers.error = data } else { buffers.output = data }
                    group.leave()
                }
            }
            process.waitUntilExit(); group.wait()
            let result = CommandResult(status: process.terminationStatus, output: buffers.output, error: buffers.error)
            DispatchQueue.main.async { completion(result) }
        }
    }
    private final class StreamBuffers: @unchecked Sendable { var output = Data(); var error = Data() }
}

final class Model: ObservableObject {
    @Published var target: Target = .production { didSet { UserDefaults.standard.set(target.rawValue, forKey: "selectedTarget") } }
    @Published var customAppPath = "" { didSet { UserDefaults.standard.set(customAppPath, forKey: "customAppPath") } }
    @Published var fontFamily = "Songti SC"
    @Published var fontLatin = ""
    @Published var fontMono = ""
    @Published var fontScale = 100.0
    @Published var fontScaleLatin = 100.0
    @Published var fontMonoScale = 100.0
    @Published var fontScaleUI = 100.0
    @Published var scope = "cjk"
    @Published var mode = "auto"
    @Published var latinScope = "all"
    @Published var bgColor = ""
    @Published var appearance = StyleSchema.extraDefaults
    @Published var codeSettings = Dictionary(uniqueKeysWithValues: CodeRegion.allCases.map { ($0, CodeRegionSetting()) })
    @Published var fonts: [FontChoice] = []
    @Published var latinFonts: [FontChoice] = []
    @Published var monoFonts: [FontChoice] = []
    @Published var statuses: [Target:TargetStatus] = [:]
    @Published var backupInfo: [Target:BackupInfo] = [:]
    @Published var busy = false
    @Published var busyLabel = ""
    @Published var appMgmtDenied = false
    @Published var log = ""
    @Published var diskFree = "—"
    @Published var themes: [ThemeDocument] = []
    @Published var themeError = false
    @Published var themeMessage = ""
    var themeLibraryReadable = true
    private var configReadable = true
    private var appliedSnapshots: [Target:[String:String]] = [:]
    private var persistedSnapshot = StyleSchema.portable(StyleSchema.defaults)
    private var checking = Set<Target>()
    var configURL: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAUDEFONT_CONFIG"] ?? NSHomeDirectory() + "/.config/claudefont/config.json")
    }
    var dataURL: URL {
        URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAUDEFONT_DATA_DIR"] ?? NSHomeDirectory() + "/.local/share/claudefont")
    }
    var testRoot: URL { URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support/claudefont") }
    var helper: URL { Bundle.main.url(forResource: "claudefont", withExtension: nil) ?? Bundle.main.bundleURL.appendingPathComponent("Contents/Resources/claudefont") }
    var current: TargetStatus { statuses[target] ?? TargetStatus(missing: !exists(target), helperOK: FileManager.default.isExecutableFile(atPath: helper.path)) }
    var settingsSnapshot: [String:String] { StyleSchema.portable(styleValues) }
    var hasUnsavedChanges: Bool { settingsSnapshot != persistedSnapshot }
    var hasUnapplied: Bool { current.patched && (!current.settingsMatch || appliedSnapshots[target].map { $0 != settingsSnapshot } == true) }
    var logLines: [String] { log.components(separatedBy: .newlines).filter { !$0.isEmpty } }
    var replacesCJK: Bool { scope == "cjk" || scope == "both" }
    var replacesLatin: Bool { scope == "latin" || scope == "both" }
    var uiScaleApplies: Bool { replacesLatin && latinScope == "all" }
    init() {
        customAppPath = UserDefaults.standard.string(forKey: "customAppPath") ?? ""
        target = Target(rawValue: UserDefaults.standard.string(forKey: "selectedTarget") ?? "production") ?? .production
    }
    func appURL(_ choice: Target) -> URL {
        switch choice {
        case .production:
            let system = URL(fileURLWithPath: "/Applications/Claude.app")
            return FileManager.default.fileExists(atPath: system.path) ? system : URL(fileURLWithPath: NSHomeDirectory() + "/Applications/Claude.app")
        case .testCopy: return testRoot.appendingPathComponent("Claude Test.app")
        case .custom: return URL(fileURLWithPath: customAppPath.isEmpty ? "/nonexistent/Claude.app" : customAppPath)
        }
    }
    func exists(_ choice: Target) -> Bool { FileManager.default.fileExists(atPath: appURL(choice).appendingPathComponent("Contents/Info.plist").path) }
    func displayPath(_ choice: Target) -> String { appURL(choice).path.replacingOccurrences(of: NSHomeDirectory(), with: "~") }
    func loadFonts() { let scanned = FontScanner.choices(); fonts = scanned.chinese; latinFonts = scanned.latin; monoFonts = scanned.mono }
    func loadConfig() {
        guard FileManager.default.fileExists(atPath: configURL.path) else { return }
        do {
            let data = try Data(contentsOf: configURL)
            guard data.count <= 1_000_000, let values = try JSONSerialization.jsonObject(with: data) as? [String:Any] else { throw StyleError.invalid("config") }
            let style = try StyleSchema.validated(StyleSchema.portable(values))
            applyStyle(style); persistedSnapshot = StyleSchema.portable(style); configReadable = true
        } catch {
            configReadable = false
            appendLog(Copy.shared.effective == .zh ? "配置无法读取，已保留原文件。\n" : "Configuration could not be read. The original file is preserved.\n")
        }
    }
    func saveConfig() throws {
        guard configReadable else { throw StyleError.invalid("unreadable config") }
        let values = try StyleSchema.validated(settingsSnapshot)
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONSerialization.data(withJSONObject: values, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]).write(to: configURL, options: .atomic)
        persistedSnapshot = StyleSchema.portable(values)
    }
    private var environment: [String:String] { ["CLAUDEFONT_CONFIG":configURL.path, "CLAUDEFONT_DATA_DIR":dataURL.path] }
    private func appendLog(_ text: String) { log.append(text); if log.count > 250_000 { log = String(log.suffix(250_000)) } }
    func refreshAll() {
        for choice in Target.allCases where choice != .custom || !customAppPath.isEmpty { refresh(choice) }
        if let values = try? URL(fileURLWithPath: NSHomeDirectory()).resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]), let size = values.volumeAvailableCapacityForImportantUsage {
            diskFree = ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
        }
    }
    func refresh(_ choice: Target) {
        guard !checking.contains(choice) else { return }
        checking.insert(choice)
        let path = appURL(choice).path
        let checkedSettings = persistedSnapshot
        CommandRunner.run(helper, ["status", "--app", path, "--json"], environment: environment) { [weak self] result in
            guard let self else { return }; self.checking.remove(choice)
            guard self.appURL(choice).path == path else { self.refresh(choice); return }
            do {
                let response = try JSONDecoder().decode(StatusResponse.self, from: result.output)
                var state = TargetStatus()
                state.loaded = true; state.missing = response.state == "missing"; state.patched = response.state == "applied" || response.state == "changed" || response.state == "previous"
                state.stale = response.state == "changed" || response.state == "previous"; state.helperOK = true
                state.canApply = response.canApply; state.settingsMatch = response.settingsMatch
                state.state = response.state; state.reason = response.reason ?? ""
                if response.state == "unsupported" {
                    if state.reason.isEmpty { state.reason = Copy.shared.effective == .zh ? "目标结构不受支持。请查看诊断；如存在旧修改，请还原或重新安装目标应用。" : "Target structure is unsupported. Diagnose it; restore or reinstall the target if it contains earlier modifications." }
                    self.appendLog(state.reason + "\n")
                }
                state.version = response.version; state.font = response.font ?? ""
                state.signOK = response.signOK; state.integrityOK = response.integrityOK
                state.backups = Array(repeating: "backup", count: min(10_000, max(0, response.backups ?? 0)))
                state.compatibility = response.compatibility; state.checkedAt = Date().formatted(date: .omitted, time: .shortened)
                self.statuses[choice] = state
                if choice == self.target { self.appMgmtDenied = response.permissionDenied }
                if state.settingsMatch && state.patched { self.appliedSnapshots[choice] = checkedSettings }
                if !state.patched { self.appliedSnapshots.removeValue(forKey: choice) }
            } catch {
                var failed = TargetStatus(loaded: true, missing: !self.exists(choice), helperOK: FileManager.default.isExecutableFile(atPath: self.helper.path))
                failed.state = failed.missing ? "missing" : "unavailable"
                failed.reason = Copy.shared.effective == .zh ? "无法读取工具返回的状态，请查看日志。" : "The tool response could not be read. Check the log."
                self.statuses[choice] = failed
                self.appendLog("Status could not be read: " + String(decoding: result.error, as: UTF8.self) + "\n")
            }
        }
    }
    private func command(_ name: String, extra: [String] = [], completion: ((Bool) -> Void)? = nil) {
        guard !busy else { completion?(false); return }
        let choice = target; busy = true; busyLabel = name
        appendLog("\n→ " + name + " · " + displayPath(choice) + "\n")
        CommandRunner.run(helper, [name, "--app", appURL(choice).path, "-y"] + extra, environment: environment, stream: { [weak self] in self?.appendLog($0) }) { [weak self] result in
            guard let self else { completion?(false); return }
            self.busy = false; self.busyLabel = ""
            self.appendLog(result.status == 0 ? "✓ Completed\n" : "✗ Exit \(result.status)\n")
            self.refresh(choice); completion?(result.status == 0)
        }
    }
    func install(completion: @escaping (Bool) -> Void) {
        guard !busy else { completion(false); return }
        do { try saveConfig() }
        catch { appendLog("Cannot save settings: \(error)\n"); completion(false); return }
        command("install", completion: completion)
    }
    var targetRunning: Bool {
        let selected = appURL(target).standardizedFileURL
        return NSWorkspace.shared.runningApplications.contains {
            $0.bundleURL?.standardizedFileURL == selected && !$0.isTerminated
        }
    }
    func migratePrevious() {
        guard !busy else { return }
        let zh = Copy.shared.effective == .zh
        let backup = NSOpenPanel(); backup.allowedContentTypes = [.applicationBundle]
        backup.canChooseDirectories = false; backup.allowsMultipleSelection = false
        backup.message = zh ? "选择同版本的完整原版应用备份。当前应用会保持不变。" : "Choose the complete pristine app backup of the same version. The current app stays unchanged."
        guard backup.runModal() == .OK, let original = backup.url else { return }
        let settings = NSOpenPanel(); settings.canChooseFiles = false; settings.canChooseDirectories = true
        settings.allowsMultipleSelection = false
        settings.message = zh ? "选择之前的设置文件夹（包含 config.json，可选 themes.json）。原文件会保留。" : "Choose the previous settings folder containing config.json and optional themes.json. Original files are preserved."
        guard settings.runModal() == .OK, let folder = settings.url else { return }
        var extra = ["--backup",original.path,"--settings",folder.appendingPathComponent("config.json").path]
        let themes = folder.appendingPathComponent("themes.json")
        if FileManager.default.fileExists(atPath:themes.path) { extra += ["--themes",themes.path] }
        command("migrate",extra:extra) { [weak self] success in
            guard let self, success else { return }
            self.loadConfig(); self.loadThemes(); self.refreshAll()
        }
    }
    func uninstall() { command("uninstall") }
    func doctor(completion: ((Bool) -> Void)? = nil) {
        guard !busy else { completion?(false); return }
        busy = true; busyLabel = t("action.doctor")
        let choice = target
        CommandRunner.run(helper, ["doctor", "--app", appURL(choice).path, "--json"], environment: environment) { [weak self] result in
            guard let self else { completion?(false); return }
            self.busy = false; self.busyLabel = ""
            self.appendLog(String(decoding: result.output, as: UTF8.self) + String(decoding: result.error, as: UTF8.self) + "\n")
            let response = try? JSONDecoder().decode(StatusResponse.self, from: result.output)
            self.appMgmtDenied = response?.permissionDenied ?? false
            completion?(result.status == 0 && response?.permissionDenied == false && response?.canApply == true)
            self.refresh(choice)
        }
    }
    func loadBackups(_ choice: Target) {
        CommandRunner.run(helper, ["backups", "--app", appURL(choice).path, "--json"], environment: environment) { [weak self] result in
            guard let self else { return }
            if let value = try? JSONDecoder().decode(BackupsResponse.self, from: result.output) {
                self.backupInfo[choice] = BackupInfo(summary: value.summary, prunable: value.prunable)
            } else { self.appendLog("Backups could not be read.\n" + String(decoding: result.error, as: UTF8.self)) }
        }
    }
    func pruneBackups(_ choice: Target) {
        let alert = NSAlert(); alert.messageText = t("detail.prune", ["{n}": String(backupInfo[choice]?.prunable ?? 0)])
        alert.informativeText = Copy.shared.effective == .zh ? "保留可还原的最新完整备份。" : "The latest restorable full backup is retained."
        alert.addButton(withTitle: Copy.shared.effective == .zh ? "清理" : "Prune"); alert.addButton(withTitle: t("sheet.cancel"))
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        command("backups", extra: ["--prune"]) { [weak self] _ in self?.loadBackups(choice) }
    }
    func openTarget() {
        let app = appURL(target); guard exists(target) else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        if target == .testCopy { configuration.arguments = ["--user-data-dir=" + testRoot.appendingPathComponent("profile").path] }
        NSWorkspace.shared.openApplication(at: app, configuration: configuration) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.appendLog(error.localizedDescription + "\n") } }
        }
    }
    private func testCommand(_ resource: String, arguments: [String]) {
        guard !busy, let script = Bundle.main.url(forResource: resource, withExtension: "sh") else { return }
        busy = true; busyLabel = resource
        CommandRunner.run(URL(fileURLWithPath: "/bin/bash"), [script.path] + arguments, environment: environment, stream: { [weak self] in self?.appendLog($0) }) { [weak self] result in
            guard let self else { return }; self.busy = false; self.busyLabel = ""
            self.appendLog(result.status == 0 ? "✓ Completed\n" : "✗ Exit \(result.status)\n")
            if result.status == 0 && resource == "setup-test-copy" { self.target = .testCopy }
            self.refreshAll()
        }
    }
    func rebuildTestCopy() { testCommand("setup-test-copy", arguments: ["--source", appURL(target == .custom ? .custom : .production).path, "--replace"]) }
    func removeTestCopy() { testCommand("remove-test-copy", arguments: []) }
}

func bgReadable(_ color: String) -> Bool { StyleSchema.hex(color) && StyleSchema.contrast(color, "#252B32") >= 4.5 }
