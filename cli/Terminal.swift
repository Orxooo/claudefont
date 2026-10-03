// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation

// A finite renderer-resource adapter for xterm's public constructor options.
// It changes the options before xterm measures its canvas and character grid.
enum TerminalResource {
    static let marker = "/* claudefont-terminal-1 */"
    static func optionsRange(_ text:String) -> Range<String.Index>? {
        guard text.contains("xterm"), !text.contains(marker) else { return nil }
        let regex = try! NSRegularExpression(pattern:#"new\s+[A-Za-z_$][A-Za-z0-9_$]*\s*\(\s*\{"#)
        var matches:[Range<String.Index>] = []
        for found in regex.matches(in:text,range:NSRange(text.startIndex...,in:text)) {
            guard let prefix = Range(found.range,in:text),let start = text[prefix].lastIndex(of:"{") else { continue }
            var index = start, depth = 0, quote:Character?, escaping = false
            var finish:String.Index?
            while index < text.endIndex {
                let character = text[index]
                if let active = quote {
                    if escaping { escaping = false }
                    else if character == "\\" { escaping = true }
                    else if character == active { quote = nil }
                } else if character == "\"" || character == "'" || character == "`" { quote = character }
                else if character == "{" { depth += 1 }
                else if character == "}" { depth -= 1; if depth == 0 { finish = text.index(after:index); break } }
                index = text.index(after:index)
            }
            guard let finish else { continue }
            let range = start..<finish, object = String(text[range])
            // Comments and regular expressions need a full JavaScript parser; reject them.
            guard !object.contains("//"), !object.contains("/*"), !object.contains("/"),
                  object.range(of:#"\ballowProposedApi\s*:\s*true\b"#,options:.regularExpression) != nil,
                  object.range(of:#"\bfontSize\s*:"#,options:.regularExpression) != nil else { continue }
            matches.append(range)
        }
        return matches.count == 1 ? matches[0] : nil
    }
    static func candidates(_ archive:Archive, excluding main:String) throws -> [(String,String,Range<String.Index>)] {
        var output:[(String,String,Range<String.Index>)] = []
        for name in archive.entries.keys.sorted() where name != main && name.hasPrefix(".vite/renderer/") && name.hasSuffix(".js") {
            let node = archive.entries[name]!
            guard node["link"] == nil, (node["size"] as? Int ?? 0) <= 30_000_000 else { continue }
            let bytes = try archive.read(name)
            guard let text = String(data:bytes,encoding:.utf8), let range = optionsRange(text) else { continue }
            try require(node["unpacked"] as? Bool != true,"Terminal adapter requires a packed renderer asset")
            output.append((name,text,range))
        }
        return output
    }
    static func replacements(_ archive:Archive, settings:[String:Any], excluding main:String) throws -> [String:Data] {
        let found = try candidates(archive,excluding:main)
        try require(found.count == 1,"Terminal resource structure is unknown or ambiguous; restore terminal defaults")
        let (name,text,range) = found[0], object = String(text[range])
        let family = settings["code_font_terminal"] as? String ?? ""
        let fontJSON = String(decoding:try JSONSerialization.data(withJSONObject:[family],options:[.fragmentsAllowed]),as:UTF8.self)
        let literal = String(fontJSON.dropFirst().dropLast())
        let scale = StyleSchema.cssNumber(StyleSchema.number(settings,"code_scale_terminal")/100)
        let familyRule = family.isEmpty ? "" : "fontFamily:" + literal + ","
        let replacement = marker + "((options)=>({...options," + familyRule + "fontSize:(Number.isFinite(options.fontSize)?options.fontSize:15)*" + scale + "}))(" + object + ")"
        let changed = text.replacingCharacters(in:range,with:replacement)
        return [name:Data(changed.utf8)]
    }
}
