// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CoreText

enum StyleCSS {
    static let zones: [String: String] = [
        "reply": ".font-claude-response, [data-testid=assistant-message]",
        "block": "pre, :not(pre) > code",
        "diff": "[data-diff], [data-diff-container]",
        "editor": ".cm-content, .cm-gutters"
    ]

    static func make(_ input: [String: Any]) throws -> String {
        let config = try StyleSchema.validated(StyleSchema.portable(input))
        func string(_ key: String) -> String { config[key] as? String ?? "" }
        func numeric(_ key: String) -> Double { StyleSchema.number(config, key) }
        func css(_ value: Double) -> String { StyleSchema.cssNumber(value) }
        func quoted(_ text: String) -> String {
            "\"" + text.replacingOccurrences(of:"\\",with:"\\\\").replacingOccurrences(of:"\"",with:"\\\"") + "\""
        }
        var rules: [String] = ["/* claudefont stylesheet 1 */"]
        func face(_ alias: String, family: String, range: String, scale: Double) {
            guard !family.isEmpty else { return }
            // CSS local() identifies a font face by PostScript/full name, while
            // the client selects a family. Resolve that face through CoreText.
            let font = CTFontCreateWithName(family as CFString,12,nil)
            let resolved = [CTFontCopyPostScriptName(font) as String,CTFontCopyFullName(font) as String,CTFontCopyFamilyName(font) as String]
            let matches = resolved.contains { $0.caseInsensitiveCompare(family) == .orderedSame }
            let names = matches ? Array(resolved.prefix(2)) + [family] : [family]
            var seen = Set<String>()
            let sources = names.filter { seen.insert($0).inserted }.map { "local(\(quoted($0)))" }.joined(separator:",")
            rules.append("@font-face{font-family:\(quoted(alias));src:\(sources);unicode-range:\(range);size-adjust:\(css(scale))%;font-display:swap;}")
        }
        let han = "U+2E80-2EFF,U+3000-303F,U+3400-4DBF,U+4E00-9FFF,U+F900-FAFF,U+FF00-FFEF"
        let latinBody = "U+0020-007E,U+00C0-024F"
        let scope = string("scope")
        var bodyFaces: [String] = [], uiFaces: [String] = []
        if scope != "latin" {
            face("CFHanBody", family: string("font"), range: han, scale: numeric("font_scale"))
            face("CFHanUI", family: string("font"), range: han, scale: numeric("font_scale_ui"))
            bodyFaces.append("CFHanBody"); uiFaces.append("CFHanUI")
        }
        if scope != "cjk", !string("font_latin").isEmpty {
            face("CFLatinBody", family: string("font_latin"), range: latinBody, scale: numeric("font_scale_latin"))
            bodyFaces.append("CFLatinBody")
            if string("latin_scope") == "all" {
                face("CFLatinUI", family: string("font_latin"), range: "U+0020-007E", scale: numeric("font_scale_ui"))
                uiFaces.append("CFLatinUI")
            }
        }
        func stack(_ faces: [String], suffix: String) -> String {
            (faces.map(quoted) + [suffix]).joined(separator: ",")
        }
        if !bodyFaces.isEmpty {
            rules.append(":root{--font-anthropic-serif:\(stack(bodyFaces,suffix:"anthropic-serif,Georgia,serif")) !important;}")
        }
        if !uiFaces.isEmpty {
            rules.append(":root{--font-anthropic-sans:\(stack(uiFaces,suffix:"anthropic-sans,system-ui,sans-serif")) !important;}")
        }
        let prose = zones["reply"]!
        if string("mode") == "brute", !bodyFaces.isEmpty {
            rules.append("\(prose){font-family:\(stack(bodyFaces,suffix:"anthropic-serif,Georgia,serif")) !important;}")
        }
        if !string("font_mono").isEmpty {
            rules.append("[data-claudefont-mono]{font-family:\(quoted(string("font_mono"))),monospace !important;font-size:calc(var(--cf-natural-size,1em) * \(css(numeric("font_mono_scale")/100))) !important;}")
        }
        if numeric("body_line_height") > 0 {
            rules.append("\(prose){line-height:\(css(numeric("body_line_height"))) !important;}")
        }
        if numeric("paragraph_spacing") > 0 {
            rules.append(".font-claude-response p,[data-testid=assistant-message] p{margin-block:\(css(numeric("paragraph_spacing")))px !important;}")
        }
        if numeric("reading_width") > 0 {
            rules.append("\(prose){max-width:min(100%,\(css(numeric("reading_width")))px) !important;}")
        }
        if numeric("code_line_height") > 0 {
            rules.append("pre,code,.cm-content{line-height:\(css(numeric("code_line_height"))) !important;}")
        }
        switch string("code_ligatures") {
        case "on": rules.append("pre,code,.cm-content{font-variant-ligatures:normal !important;font-feature-settings:\"liga\" 1,\"calt\" 1 !important;}")
        case "off": rules.append("pre,code,.cm-content{font-variant-ligatures:none !important;font-feature-settings:\"liga\" 0,\"calt\" 0 !important;}")
        default: break
        }
        for zone in ["reply", "block", "diff", "editor"] {
            let family = string("code_font_" + zone)
            let scale = numeric("code_scale_" + zone)
            guard !family.isEmpty || scale != 100 else { continue }
            var declarations = "font-size:calc(var(--cf-natural-size,1em) * \(css(scale/100))) !important;"
            if !family.isEmpty { declarations += "font-family:\(quoted(family)),monospace !important;" }
            rules.append("[data-claudefont-zone=\(zone)]{\(declarations)}")
        }
        if !string("bg_color").isEmpty {
            rules.append(":root:not(.dark):not([data-theme=dark]) body,:root:not(.dark):not([data-theme=dark]) main,:root:not(.dark):not([data-theme=dark]) .bg-bg-000{background-color:\(string("bg_color")) !important;}")
        }
        if let palette = StyleSchema.palette(config) {
            let selectors = [":root.dark", ":root[data-theme=dark]", ":host-context(.dark)", ":host-context([data-theme=dark])"]
            for root in selectors {
                rules.append("\(root) body,\(root) main,\(root) .bg-bg-000{background-color:\(palette["bg"]!) !important;color:\(palette["text"]!) !important;}")
                rules.append("\(root) a{color:\(palette["link"]!) !important;}")
                rules.append("\(root) pre,\(root) pre code,\(root) .cm-editor{background-color:\(palette["code"]!) !important;color:\(palette["text"]!) !important;}")
                rules.append("\(root) [data-line-type=addition],\(root) [data-line-type=change-addition]{background-color:\(palette["added"]!) !important;}")
                rules.append("\(root) [data-line-type=deletion],\(root) [data-line-type=change-deletion]{background-color:\(palette["removed"]!) !important;}")
            }
        }
        rules.append("[data-claudefont-mono] code,[data-claudefont-zone=block] code{font-family:inherit !important;font-size:inherit !important;line-height:inherit !important;}")
        return rules.joined(separator: "\n") + "\n"
    }
}

// Renderer preload payload: styles and DOM attributes only, no network or application APIs.
enum RendererScript {
    static let marker = "/* claudefont-renderer-1 */"
    static func make(css: String) -> String {
        let encoded = Data(css.utf8).base64EncodedString()
        let selectorData = (try? JSONSerialization.data(withJSONObject: StyleCSS.zones, options: [.sortedKeys])) ?? Data("{}".utf8)
        let selectors = String(decoding: selectorData, as: UTF8.self)
        return "\n" + marker + "\n" + #"""
        (() => {
          if (typeof document === 'undefined') return;
          const sheet = new TextDecoder().decode(Uint8Array.from(atob('__ENCODED__'), character => character.charCodeAt(0)));
          const selectors = __SELECTORS__;
          const roots = new WeakSet();
          let queued = false;
          const update = () => {
            queued = false;
            const visit = root => {
              const container = root === document ? document.head : root;
              if (!container) return;
              let style = container.querySelector('style[data-claudefont-sheet]');
              if (!style) {
                style = document.createElement('style');
                style.setAttribute('data-claudefont-sheet', '1');
                style.textContent = sheet;
                container.append(style);
              } else if (style.parentNode === container && container.lastChild !== style) {
                container.append(style);
              }
              // Measure unstyled sizes, including nodes added below scaled ancestors.
              if (style.sheet) style.sheet.disabled = true;
              const remember = element => {
                if (!element.style.getPropertyValue('--cf-natural-size')) {
                  element.style.setProperty('--cf-natural-size', getComputedStyle(element).fontSize);
                }
              };
              root.querySelectorAll('pre,code').forEach(element => {
                if (element.tagName === 'CODE' && element.closest('pre')) return;
                remember(element);
                element.setAttribute('data-claudefont-mono', '1');
              });
              Object.entries(selectors).forEach(([zone, selector]) => {
                root.querySelectorAll(selector).forEach(element => {
                  if (zone === 'block' && element.tagName === 'CODE' && element.closest('pre')) return;
                  remember(element);
                  if (element.getAttribute('data-claudefont-zone') !== zone) element.setAttribute('data-claudefont-zone', zone);
                });
              });
              root.querySelectorAll('*').forEach(element => { if (element.shadowRoot) visit(element.shadowRoot); });
              if (style.sheet) style.sheet.disabled = false;
              if (!roots.has(root)) {
                roots.add(root);
                new MutationObserver(() => {
                  if (!queued) { queued = true; queueMicrotask(update); }
                }).observe(root, { childList:true, subtree:true });
              }
            };
            visit(document);
          };
          if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', update, {once:true});
          else update();
          // attachShadow on an existing host does not emit a document mutation.
          // Rediscover roots without remeasuring or restyling an unchanged document.
          const findNewRoot = root => {
            for (const element of root.querySelectorAll('*')) {
              if (!element.shadowRoot) continue;
              if (!roots.has(element.shadowRoot) || findNewRoot(element.shadowRoot)) return true;
            }
            return false;
          };
          setInterval(() => { if (findNewRoot(document)) update(); }, 1000);
        })();
        """#.replacingOccurrences(of: "__ENCODED__", with: encoded)
            .replacingOccurrences(of: "__SELECTORS__", with: selectors) + "\n"
    }
}
