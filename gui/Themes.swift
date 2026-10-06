// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct CompatibilityStatus: Decodable {
    let version: String
    let versionEvidence: String
    let runtime: String
    let injection: Bool
    let settingsMatch: Bool
    let canReapply: Bool
    let regions: [String:String]
    let installedRegions: [String:Bool]
}

extension Model {
    var styleValues: [String:Any] {
        var d = appearance
        d.merge(["scope":scope, "mode":mode, "latin_scope":latinScope,
            "font":fontFamily, "font_scale":fontScale, "font_latin":fontLatin,
            "font_scale_latin":fontScaleLatin, "font_mono":fontMono, "font_mono_scale":fontMonoScale,
            "font_scale_ui":fontScaleUI, "bg_color":bgColor]) { _, new in new }
        for region in CodeRegion.allCases {
            let s = codeSettings[region] ?? CodeRegionSetting()
            d["code_font_" + region.rawValue] = s.font; d["code_scale_" + region.rawValue] = s.scale
        }
        return d
    }
    var recommendedThemes: [ThemeDocument] {
        let zh = Copy.shared.effective == .zh
        var reading = StyleSchema.defaults
        reading.merge(["body_line_height":1.8,"paragraph_spacing":20,"reading_width":680,"bg_color":"#F0EEE6","dark_theme":"warm"]) { _, new in new }
        var review = StyleSchema.defaults
        review.merge(["font_mono":"Menlo","code_line_height":1.6,"code_ligatures":"off","dark_theme":"graphite","code_scale_diff":110,"code_scale_editor":110]) { _, new in new }
        var large = StyleSchema.defaults
        large.merge(["scope":"both","font_latin":"Helvetica Neue","font_scale":125,"font_scale_latin":125,"font_scale_ui":125,"font_mono":"Menlo","font_mono_scale":125,"body_line_height":1.7,"reading_width":760]) { _, new in new }
        return [ThemeDocument(name:zh ? "中文阅读" : "Chinese reading",settings:StyleSchema.portable(reading)),
                ThemeDocument(name:zh ? "代码审查" : "Code review",settings:StyleSchema.portable(review)),
                ThemeDocument(name:zh ? "大字模式" : "Large type",settings:StyleSchema.portable(large))]
    }
    var appearanceValid: Bool { (try? StyleSchema.validateAppearance(appearance)) != nil }
    var missingStyleFonts: [String] {
        let installed = Set((fonts + latinFonts + monoFonts).map(\.family))
        let names = [fontFamily,fontLatin,fontMono] + codeSettings.values.map(\.font)
        return Array(Set(names.filter { !$0.isEmpty && !installed.contains($0) })).sorted()
    }
    func applyStyle(_ values: [String:Any]) {
        fontFamily = values["font"] as? String ?? "Songti SC"
        fontLatin = values["font_latin"] as? String ?? ""
        scope = values["scope"] as? String ?? "cjk"; mode = values["mode"] as? String ?? "auto"
        latinScope = values["latin_scope"] as? String ?? "all"
        fontMono = values["font_mono"] as? String ?? ""; bgColor = values["bg_color"] as? String ?? ""
        fontScale = StyleSchema.number(values,"font_scale"); fontScaleLatin = StyleSchema.number(values,"font_scale_latin")
        fontMonoScale = StyleSchema.number(values,"font_mono_scale"); fontScaleUI = StyleSchema.number(values,"font_scale_ui")
        for region in CodeRegion.allCases {
            codeSettings[region] = CodeRegionSetting(font:values["code_font_" + region.rawValue] as? String ?? "",
                scale:StyleSchema.number(values,"code_scale_" + region.rawValue))
        }
        appearance = StyleSchema.extraDefaults.mapValues { $0 }
        for key in appearance.keys { if let value = values[key] { appearance[key] = value } }
    }
    private var themeURL: URL {
        let config = ProcessInfo.processInfo.environment["CLAUDEFONT_CONFIG"] ?? NSHomeDirectory() + "/.config/claudefont/config.json"
        return URL(fileURLWithPath:config).deletingLastPathComponent().appendingPathComponent("themes.json")
    }
    private func message(_ zh: String, _ en: String, error: Bool = false) {
        themeError = error; themeMessage = Copy.shared.effective == .zh ? zh : en
    }
    func loadThemes() {
        guard FileManager.default.fileExists(atPath:themeURL.path) else { return }
        do {
            let data = try Data(contentsOf:themeURL)
            guard data.count <= 1_000_000 else { throw StyleError.invalid("size") }
            let documents = try JSONDecoder().decode([ThemeDocument].self,from:data)
            for theme in documents { _ = try theme.validated() }
            guard Set(documents.map(\.name)).count == documents.count else { throw StyleError.invalid("names") }
            themes = documents
            themeLibraryReadable = true
        } catch { themeLibraryReadable = false; message("主题库无法读取，原文件已保留。", "Could not read the theme library. The original file is preserved.",error:true) }
    }
    private func storeThemes(_ documents: [ThemeDocument]) throws {
        guard themeLibraryReadable else { throw StyleError.invalid("library unreadable") }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
        let data = try encoder.encode(documents)
        try FileManager.default.createDirectory(at:themeURL.deletingLastPathComponent(),withIntermediateDirectories:true)
        try data.write(to:themeURL,options:.atomic)
        themes = documents
    }
    func uniqueThemeName(_ base: String) -> String {
        let name = String(base.trimmingCharacters(in:.whitespacesAndNewlines).prefix(50))
        var result = name; var index = 2
        while themes.contains(where: { $0.name == result }) { result = "\(name) \(index)"; index += 1 }
        return result
    }
    func saveTheme(name: String, replacing: String? = nil) {
        do {
            let saved = replacing.flatMap { oldName in themes.first { $0.name == oldName } }
            let theme = ThemeDocument(name:name.trimmingCharacters(in:.whitespacesAndNewlines),settings:saved?.settings ?? settingsSnapshot)
            _ = try theme.validated()
            guard !themes.contains(where:{ $0.name == theme.name && $0.name != replacing }) else { throw StyleError.invalid("duplicate") }
            var documents = themes
            if let replacing, let i = documents.firstIndex(where:{$0.name == replacing}) {
                // Rename preserves the saved style, even when current controls have changed.
                var renamed = documents[i]; renamed.name = theme.name; documents[i] = renamed
            } else { documents.append(theme) }
            try storeThemes(documents)
            message("主题已保存。", "Theme saved.")
        } catch { message("保存失败，请使用未占用的名称并检查设置和配色。", "Could not save. Use a unique name and check settings and color contrast.",error:true) }
    }
    func selectTheme(_ theme: ThemeDocument) {
        do { applyStyle(try theme.validated()); message("已载入主题，点击“应用设置”后生效。", "Theme loaded. Choose Apply settings to use it in Claude.") }
        catch { message("主题格式或配色无效。", "Invalid theme format or color contrast.",error:true) }
    }
    func duplicateTheme(_ theme: ThemeDocument) {
        do {
            var duplicate = theme; duplicate.name = uniqueThemeName(theme.name)
            try storeThemes(themes + [duplicate]); message("主题已复制。", "Theme duplicated.")
        } catch { message("复制失败，主题库未改变。", "Could not duplicate. The library is unchanged.",error:true) }
    }
    func deleteTheme(_ theme: ThemeDocument) {
        do { try storeThemes(themes.filter { $0.name != theme.name }); message("主题已删除。", "Theme deleted.") }
        catch { message("删除失败，主题库未改变。", "Could not delete. The library is unchanged.",error:true) }
    }
    func importTheme() {
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size <= 64_000 else { throw StyleError.invalid("size") }
            var theme = try JSONDecoder().decode(ThemeDocument.self,from:Data(contentsOf:url))
            _ = try theme.validated()
            theme.name = uniqueThemeName(theme.name)
            try storeThemes(themes + [theme])
            message("主题已导入，可在列表中载入。", "Theme imported. Load it from the library.")
        } catch { message("导入失败：请选择有效的 ClaudeFont 主题 JSON 文件。", "Import failed. Choose a valid ClaudeFont theme JSON file.",error:true) }
    }
    func exportTheme(_ theme: ThemeDocument) {
        do {
            _ = try theme.validated()
            let panel = NSSavePanel(); panel.allowedContentTypes = [.json]
            panel.nameFieldStringValue = "ClaudeFont-theme.json"
            guard panel.runModal() == .OK, let url = panel.url else { return }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted,.sortedKeys,.withoutEscapingSlashes]
            try encoder.encode(theme).write(to:url,options:.atomic)
            message("主题已导出，仅包含样式设置。", "Theme exported with style settings only.")
        } catch { message("无法导出，请检查设置和保存位置。", "Could not export. Check settings and the save location.",error:true) }
    }
}
