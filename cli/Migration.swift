// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CoreFoundation

struct MigrationSettings {
    let sourceSettings: URL
    let sourceThemes: URL?
    let settingsData: Data
    let themesData: Data?
    init(settings:URL,themes:URL?) throws {
        sourceSettings = settings.standardizedFileURL
        sourceThemes = themes?.standardizedFileURL
        func read(_ url:URL) throws -> Data {
            try noSymlink(url)
            let size = try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            try require(size <= 1_000_000,"Imported settings or theme library is too large")
            let data = try Data(contentsOf:url)
            try require(data.count <= 1_000_000,"Imported settings or theme library is too large")
            return data
        }
        let object = try jsonObject(read(settings))
        var portable:[String:String] = [:]
        for (key,fallback) in StyleSchema.defaults where object[key] != nil {
            let value = object[key]!
            if fallback is String {
                guard let text = value as? String else { throw EngineError("Invalid imported setting: \(key)") }
                portable[key] = text
            } else if let text = value as? String { portable[key] = text }
            else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
                portable[key] = StyleSchema.cssNumber(number.doubleValue)
            } else { throw EngineError("Invalid imported setting: \(key)") }
        }
        let validated = try StyleSchema.validated(portable)
        _ = try StyleCSS.make(validated)
        settingsData = try jsonData(StyleSchema.portable(validated))
        if let themes {
            let documents = try JSONDecoder().decode([ThemeDocument].self,from:read(themes))
            try require(Set(documents.map(\.name)).count == documents.count,"Imported theme names must be unique")
            for theme in documents { _ = try StyleCSS.make(theme.validated()) }
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys,.withoutEscapingSlashes]
            themesData = try encoder.encode(documents)
        } else { themesData = nil }
    }
}

enum PreviousValidation {
    private static let previousMarker = #"/\*[^*\n]{0,100}font[-_]v[0-9]+[^*\n]*\*/"#
    private static func marker(_ data:Data) -> Bool {
        String(decoding:data,as:UTF8.self).range(of:previousMarker,options:.regularExpression) != nil
    }
    // Re-signing changes the Mach-O signature. Compare the executable code on
    // private temporary copies normalized to the same temporary signature, then
    // stripped. Direct stripping can leave different __LINKEDIT allocations.
    private static func runtimeIdentity(_ url:URL) throws -> String {
        try noSymlink(url)
        let root = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("claudefont-runtime-" + UUID().uuidString)
        try ensureDirectory(root); defer { try? FileManager.default.removeItem(at:root) }
        let copy = root.appendingPathComponent("runtime")
        try Data(contentsOf:url,options:.mappedIfSafe).write(to:copy)
        _ = try checked("/usr/bin/codesign",["--force","--sign","-",copy.path])
        _ = try checked("/usr/bin/codesign",["--remove-signature",copy.path])
        return digest(try Data(contentsOf:copy,options:.mappedIfSafe))
    }
    private struct BundleEntry: Equatable {
        let type: String
        let mode: Int
        let content: String
    }
    private static func inventory(_ root:URL,validatedFiles:Set<String>) throws -> [String:BundleEntry] {
        let fm = FileManager.default
        var failure:Error?
        guard let iterator = fm.enumerator(at:root,includingPropertiesForKeys:nil,options:[],errorHandler:{ _, error in failure = error; return false }) else {
            throw EngineError("Cannot inspect application bundle")
        }
        var result:[String:BundleEntry] = [:]
        while let item = iterator.nextObject() as? URL {
            let name = String(item.path.dropFirst(root.path.count + 1))
            let attributes = try fm.attributesOfItem(atPath:item.path)
            let mode = (attributes[.posixPermissions] as? NSNumber)?.intValue ?? 0
            guard let type = attributes[.type] as? FileAttributeType else { throw EngineError("Unknown application file type") }
            let content:String
            if validatedFiles.contains(name) {
                try require(type == .typeRegular,"Expected a regular application resource: \(name)")
                // These exact files have separate semantic or signature-independent checks.
                content = "validated"
            } else if type == .typeRegular {
                content = digest(try Data(contentsOf:item,options:.mappedIfSafe))
            } else if type == .typeDirectory { content = "directory" }
            else if type == .typeSymbolicLink {
                let resolved = item.resolvingSymlinksInPath().standardizedFileURL.path
                try require(resolved.hasPrefix(root.path + "/") && exists(URL(fileURLWithPath:resolved)),"Unsafe application link: \(name)")
                content = try fm.destinationOfSymbolicLink(atPath:item.path)
                iterator.skipDescendants()
            } else { throw EngineError("Unsupported application file: \(name)") }
            // Patched files may have been atomically replaced with different modes.
            // Every unrelated file and directory must retain its original mode.
            result[name] = BundleEntry(type:type.rawValue,mode:validatedFiles.contains(name) ? 0 : mode,content:content)
        }
        if let failure { throw failure }
        return result
    }
    private static func bundleIdentity(current:ApplicationTarget,pristine:ApplicationTarget,currentInfo:[String:Any],pristineInfo:[String:Any],runtime:URL) throws {
        var currentMetadata = currentInfo, pristineMetadata = pristineInfo
        currentMetadata.removeValue(forKey:"ElectronAsarIntegrity")
        pristineMetadata.removeValue(forKey:"ElectronAsarIntegrity")
        try require(NSDictionary(dictionary:currentMetadata).isEqual(NSDictionary(dictionary:pristineMetadata)),"Pristine backup application metadata differs")
        let runtimePath = String(runtime.path.dropFirst(current.url.path.count + 1))
        let separatelyValidated:Set<String> = [runtimePath,"Contents/Info.plist","Contents/_CodeSignature/CodeResources","Contents/Resources/app.asar"]
        var currentFiles = try inventory(current.url,validatedFiles:separatelyValidated)
        let pristineFiles = try inventory(pristine.url,validatedFiles:separatelyValidated)
        let artifact = "Contents/Resources/app.asar.bak"
        try require(pristineFiles[artifact] == nil,"Selected pristine backup contains a previous archive backup")
        if currentFiles[artifact] != nil {
            let backup = current.url.appendingPathComponent(artifact)
            try noSymlink(backup)
            try require(try Data(contentsOf:backup,options:.mappedIfSafe) == Data(contentsOf:pristine.archive,options:.mappedIfSafe),"Previous archive backup is not identical to the pristine archive")
            currentFiles.removeValue(forKey:artifact)
        }
        try require(currentFiles.keys.sorted() == pristineFiles.keys.sorted(),"Pristine backup application file set differs")
        for name in pristineFiles.keys.sorted() {
            try require(currentFiles[name] == pristineFiles[name],"Pristine backup application resource differs: \(name)")
        }
    }
    static func verify(current:ApplicationTarget,pristine:ApplicationTarget,currentInfo:[String:Any],pristineInfo:[String:Any],
                       currentArchive:Archive,pristineArchive:Archive,currentPreload:Data,pristinePreload:Data) throws {
        let identifier = currentInfo["CFBundleIdentifier"] as? String ?? ""
        try require(["com.anthropic.claudefordesktop","io.github.orxooo.claudefont.test"].contains(identifier),"Previous application identity is unsupported")
        for key in ["CFBundleIdentifier","CFBundleShortVersionString","CFBundleVersion","CFBundleExecutable","ClaudefontRuntimeExecutable"] {
            try require((currentInfo[key] as? String) == (pristineInfo[key] as? String),"Pristine backup does not match application \(key)")
        }
        try require(!(currentInfo["CFBundleShortVersionString"] as? String ?? "").isEmpty,"Application version is missing")
        let currentRuntime = try current.runtime(currentInfo), pristineRuntime = try pristine.runtime(pristineInfo)
        try require(try runtimeIdentity(currentRuntime) == runtimeIdentity(pristineRuntime),"Pristine backup runtime does not match")
        try bundleIdentity(current:current,pristine:pristine,currentInfo:currentInfo,pristineInfo:pristineInfo,runtime:currentRuntime)
        let currentMain = try currentArchive.mainEntry(), pristineMain = try pristineArchive.mainEntry()
        try require(currentMain == pristineMain && currentMain != FontEngine.preload,"Pristine backup main entry does not match")
        try require(Set(currentArchive.entries.keys) == Set(pristineArchive.entries.keys) && currentArchive.directories == pristineArchive.directories,"Pristine backup archive file set does not match")
        let ownMarker = Data(RendererScript.marker.utf8)
        for name in pristineArchive.entries.keys {
            let originalNode = pristineArchive.entries[name]!, currentNode = currentArchive.entries[name]!
            try require((originalNode["link"] as? String) == (currentNode["link"] as? String) &&
                        (originalNode["unpacked"] as? Bool ?? false) == (currentNode["unpacked"] as? Bool ?? false),"Pristine backup archive structure differs")
            if originalNode["link"] != nil { continue }
            let original = try pristineArchive.read(name), changed = try currentArchive.read(name)
            if name.hasSuffix(".js") || name.hasSuffix(".html") {
                try require(!marker(original) && original.range(of:ownMarker) == nil,"Selected backup already contains font modifications")
            }
            if original == changed { continue }
            let renderer = name == FontEngine.preload || (name.hasPrefix(".vite/renderer/") && (name.hasSuffix(".js") || name.hasSuffix(".html")))
            try require(renderer && name != currentMain && originalNode["unpacked"] as? Bool != true,"Previous changes include a non-renderer resource: \(name)")
        }
        try require(currentPreload.count > pristinePreload.count && currentPreload.starts(with:pristinePreload),"Previous preload is not an appended patch on the pristine backup")
        let suffix = currentPreload.dropFirst(pristinePreload.count)
        let text = String(decoding:suffix,as:UTF8.self)
        // The marker must start the appended patch; leading line breaks/semicolon
        // are accepted because a pristine preload may end in a source-map comment.
        let pattern = #"\A[\s;]*/\*[^*\n]{0,100}font[-_]v[0-9]+[^*\n]*\*/"#
        try require(text.range(of:pattern,options:.regularExpression) != nil && currentPreload.range(of:ownMarker) == nil,
                    "Previous preload patch marker is not recognized")
    }
}
