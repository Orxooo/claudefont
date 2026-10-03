// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation

@main struct StyleChecks {
    static func main() throws {
        var settings = StyleSchema.defaults
        settings.merge(["scope":"both", "font":"Songti TC", "font_latin":"Georgia", "font_mono":"Menlo", "font_mono_scale":150,
                        "code_font_block":"Courier New", "code_scale_block":125, "code_font_reply":"Georgia", "code_scale_reply":110,
                        "body_line_height":1.8, "paragraph_spacing":20, "reading_width":680,
                        "code_line_height":1.6, "code_ligatures":"off", "dark_theme":"warm", "bg_color":"#F0EEE6"]) { _, value in value }
        let stylesheet = try StyleCSS.make(settings)
        precondition(stylesheet.contains("CFLatinBody") && stylesheet.contains("CFHanBody"))
        precondition(stylesheet.contains("size-adjust:100%") && stylesheet.contains("max-width:min(100%,680px)"))
        precondition(stylesheet.contains("data-claudefont-zone=block") && stylesheet.contains("* 1.25"))
        precondition(stylesheet.contains(":root.dark body") && stylesheet.contains("font-variant-ligatures:none"))
        var missing = settings
        missing["font"] = "___claudefont_missing_font___"; missing["font_latin"] = ""
        let unavailable = try StyleCSS.make(missing)
        precondition(unavailable.contains("local(\"___claudefont_missing_font___\")"))
        precondition(!unavailable.contains("local(\"Helvetica\")"), "CoreText fallback must not replace a missing selected family")
        let script = RendererScript.make(css:stylesheet)
        precondition(script.hasPrefix("\n"), "preload source-map comment must be separated")
        precondition(!script.contains("fetch(") && !script.contains("require("), "renderer must not access app/network")
        for invalid in ["x\";color:red", "bad\\name", "bad\nname"] {
            var values = settings; values["font"] = invalid
            do { _ = try StyleCSS.make(values); fatalError("invalid CSS family accepted") } catch {}
        }
        let dir = URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
        try stylesheet.write(to:dir.appendingPathComponent("style.css"),atomically:true,encoding:.utf8)
        try script.write(to:dir.appendingPathComponent("renderer.js"),atomically:true,encoding:.utf8)
        print("style schema, CSS generation and renderer payload: PASS")
    }
}
