// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CoreFoundation

// Portable style data only. No target paths, install records or device font faces.
enum StyleSchema {
    static let regions = ["reply", "block", "diff", "editor", "terminal"]
    static let extraDefaults: [String: Any] = [
        "body_line_height": 0.0, "paragraph_spacing": 0, "reading_width": 0,
        "code_line_height": 0.0, "code_ligatures": "default", "dark_theme": "default",
        "dark_bg": "#202020", "dark_text": "#ECE8E1", "dark_link": "#DCA98C",
        "dark_code": "#292929", "dark_added": "#183326", "dark_removed": "#3D2426"
    ]
    static let defaults: [String: Any] = {
        var d: [String: Any] = ["scope": "cjk", "font": "Songti SC", "font_latin": "",
            "mode": "auto", "font_scale": 100, "font_scale_latin": 100,
            "font_mono": "", "font_mono_scale": 100, "font_scale_ui": 100,
            "bg_color": "", "latin_scope": "all"]
        d.merge(extraDefaults) { _, new in new }
        for region in regions { d["code_font_" + region] = ""; d["code_scale_" + region] = 100 }
        return d
    }()
    static let ranges: [String: ClosedRange<Double>] = [
        "body_line_height": 1.2...2.4, "paragraph_spacing": 4...40,
        "reading_width": 480...1100, "code_line_height": 1.2...2.4
    ]
    static func number(_ d: [String: Any], _ key: String) -> Double {
        if let n = d[key] as? NSNumber { return n.doubleValue }
        return Double(d[key] as? String ?? "") ?? 0
    }
    static func cssNumber(_ number: Double) -> String {
        String(format: "%g", locale: Locale(identifier: "en_US_POSIX"), number)
    }
    static func hex(_ value: String) -> Bool {
        value.range(of: "^#[0-9A-Fa-f]{6}$", options: .regularExpression) != nil
    }
    static func contrast(_ a: String, _ b: String) -> Double {
        func luminance(_ s: String) -> Double {
            let n = UInt32(s.dropFirst(), radix: 16) ?? 0
            let values = [Double((n >> 16) & 255), Double((n >> 8) & 255), Double(n & 255)].map { x in
                let v = x / 255; return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return values[0] * 0.2126 + values[1] * 0.7152 + values[2] * 0.0722
        }
        let x = luminance(a), y = luminance(b)
        return (max(x,y) + 0.05) / (min(x,y) + 0.05)
    }
    static func palette(_ d: [String: Any]) -> [String: String]? {
        switch d["dark_theme"] as? String ?? "default" {
        case "graphite": return ["bg":"#202020", "text":"#ECE8E1", "link":"#DCA98C", "code":"#292929", "added":"#183326", "removed":"#3D2426"]
        case "warm": return ["bg":"#25211F", "text":"#F1E7DC", "link":"#E5B394", "code":"#302A26", "added":"#26382B", "removed":"#422A2A"]
        case "custom": return Dictionary(uniqueKeysWithValues: ["bg","text","link","code","added","removed"].map { ($0, d["dark_" + $0] as? String ?? extraDefaults["dark_" + $0] as! String) })
        default: return nil
        }
    }
    static func validateAppearance(_ d: [String: Any]) throws {
        for (key, range) in ranges {
            let n: Double
            if let value = d[key] {
                if let numeric = value as? NSNumber, CFGetTypeID(numeric) != CFBooleanGetTypeID() { n = numeric.doubleValue }
                else if let text = value as? String, let numeric = Double(text) { n = numeric }
                else { throw StyleError.invalid(key) }
            } else { n = 0 }
            guard n.isFinite && (n == 0 || range.contains(n)) else { throw StyleError.invalid(key) }
        }
        let ligatures: String
        let theme: String
        if let value = d["code_ligatures"] { guard let text = value as? String else { throw StyleError.invalid("code_ligatures") }; ligatures = text } else { ligatures = "default" }
        if let value = d["dark_theme"] { guard let text = value as? String else { throw StyleError.invalid("dark_theme") }; theme = text } else { theme = "default" }
        guard ["default","on","off"].contains(ligatures), ["default","graphite","warm","custom"].contains(theme) else { throw StyleError.invalid("appearance") }
        if theme == "custom" {
            for key in ["bg","text","link","code","added","removed"] {
                if let value = d["dark_" + key], !(value is String) { throw StyleError.invalid("dark_" + key) }
            }
        }
        if let p = palette(d) {
            guard p.values.allSatisfy(hex),
                  ["bg","code","added","removed"].allSatisfy({ contrast(p["text"]!,p[$0]!) >= 4.5 }),
                  contrast(p["link"]!,p["bg"]!) >= 4.5 else { throw StyleError.invalid("dark contrast") }
        }
    }
    static func portable(_ d: [String: Any]) -> [String: String] {
        Dictionary(uniqueKeysWithValues: defaults.map { key, fallback in
            let value = d[key] ?? fallback
            return (key, (value as? String) ?? cssNumber((value as? NSNumber)?.doubleValue ?? 0))
        })
    }
    static func validated(_ settings: [String: String]) throws -> [String: Any] {
        var d = defaults
        guard !settings.isEmpty, Set(settings.keys).isSubset(of: Set(defaults.keys)) else { throw StyleError.invalid("settings") }
        for (key, value) in settings {
            guard value.count <= 160, !value.contains(where: { "\"'`$\\;{}<>".contains($0) || $0.isNewline || $0.asciiValue.map({ $0 < 32 }) == true }) else { throw StyleError.invalid(key) }
            if key.contains("scale") || ranges[key] != nil {
                guard let n = Double(value), n.isFinite else { throw StyleError.invalid(key) }
                if key.contains("scale"), (!(80...150).contains(n) || n.rounded() != n) { throw StyleError.invalid(key) }
                d[key] = n
            } else { d[key] = value }
        }
        for (key, options) in ["scope":["cjk","latin","both"],"mode":["auto","brute"],"latin_scope":["all","body"]] {
            guard options.contains(d[key] as? String ?? "") else { throw StyleError.invalid(key) }
        }
        for key in ["bg_color","dark_bg","dark_text","dark_link","dark_code","dark_added","dark_removed"] {
            let v = d[key] as? String ?? ""
            guard (key == "bg_color" && v.isEmpty) || hex(v) else { throw StyleError.invalid(key) }
        }
        if let bg = d["bg_color"] as? String, !bg.isEmpty, contrast(bg,"#252B32") < 4.5 { throw StyleError.invalid("light contrast") }
        try validateAppearance(d)
        return d
    }
}
enum StyleError: Error { case invalid(String) }
struct ThemeDocument: Codable, Identifiable {
    var schemaVersion = 1
    var name: String
    var settings: [String: String]
    var id: String { name }
    func validated() throws -> [String: Any] {
        guard schemaVersion == 1, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              name.count <= 60, !name.contains(where: { $0.isNewline || $0.asciiValue.map({ $0 < 32 }) == true }) else { throw StyleError.invalid("theme") }
        return try StyleSchema.validated(settings)
    }
}
