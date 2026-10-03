// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@main
struct ThemeChecks {
    static func main() throws {
        var count = 0
        func check(_ name: String, _ body: () throws -> Bool) throws {
            guard try body() else { fatalError(name) }; count += 1; print("PASS: " + name)
        }
        func rejected(_ settings: [String:String]) -> Bool {
            do { _ = try StyleSchema.validated(settings); return false } catch { return true }
        }
        var raw = StyleSchema.defaults
        raw["last_install_targets"] = ["default":["path":"PRIVATE_TARGET","secret":"PRIVATE_SECRET"]]
        raw["font_regular"] = "MACHINE_FONT_FACE"
        raw["customAppPath"] = "PRIVATE_PATH"
        raw["reading_width"] = 680; raw["dark_theme"] = "warm"
        let doc = ThemeDocument(name:"中文阅读",settings:StyleSchema.portable(raw))
        let data = try JSONEncoder().encode(doc)
        try check("export excludes runtime records and paths") {
            let text = String(decoding:data,as:UTF8.self)
            return !text.contains("PRIVATE") && !text.contains("MACHINE_FONT_FACE")
        }
        let decoded = try JSONDecoder().decode(ThemeDocument.self,from:data)
        let restored = try decoded.validated()
        try check("theme roundtrip retains typography and palette") { StyleSchema.number(restored,"reading_width") == 680 && restored["dark_theme"] as? String == "warm" }
        try check("unknown install keys rejected") { rejected(["last_install":"secret"]) }
        try check("unsafe font names rejected") { rejected(["font":"x\";body{color:red}"]) }
        try check("unsupported scope rejected") { rejected(["scope":"everything"]) }
        try check("unbounded scale rejected") { rejected(["font_scale":"999"]) }
        try check("NaN rejected") { rejected(["body_line_height":"nan"]) }
        try check("infinity rejected") { rejected(["reading_width":"inf"]) }
        try check("invalid layout range rejected") { rejected(["body_line_height":"0.5"]) }
        try check("unreadable dark palette rejected") { rejected(["dark_theme":"custom","dark_bg":"#FFFFFF","dark_text":"#FFFFFF"]) }
        try check("unreadable light palette rejected") { rejected(["bg_color":"#000000"]) }
        try check("missing font retains portable name") { try StyleSchema.validated(["font":"Example missing font"])["font"] as? String == "Example missing font" }
        try check("unknown schema rejected") {
            do { _ = try ThemeDocument(schemaVersion:99,name:"Future",settings:doc.settings).validated(); return false } catch { return true }
        }
        try check("blank name rejected") {
            do { _ = try ThemeDocument(name:"   ",settings:doc.settings).validated(); return false } catch { return true }
        }
        print("All \(count) theme checks passed")
    }
}
