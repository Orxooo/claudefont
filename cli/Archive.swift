// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
// Independent reader/writer of the public Electron ASAR / Chromium Pickle format.
import Foundation
import CoreFoundation

struct Archive {
    var directories = Set<String>()
    var header: [String: Any]
    let bytes: Data
    let contentStart: Int
    let rawHeader: Data
    let unpacked: URL?
    var entries: [String: [String: Any]] = [:]
    static let blockSize = 4 * 1024 * 1024

    init(data: Data, unpacked: URL? = nil) throws {
        func u32(_ offset: Int) throws -> Int {
            try require(offset >= 0 && offset + 4 <= data.count, "Truncated ASAR pickle")
            return Int(data[offset]) | Int(data[offset+1]) << 8 | Int(data[offset+2]) << 16 | Int(data[offset+3]) << 24
        }
        try require(data.count >= 16, "Truncated ASAR size pickle")
        let sizeWord = try u32(0)
        try require(sizeWord == 4, "Invalid ASAR size pickle")
        let hs = try u32(4), payload = try u32(8), length = try u32(12)
        try require(hs >= 8 && hs <= 64 * 1024 * 1024 && hs % 4 == 0 && hs <= data.count - 8, "Invalid ASAR header size")
        try require(payload == hs - 4 && length > 0 && length <= hs - 8 && ((length + 3) / 4) * 4 == hs - 8, "Invalid ASAR header pickle")
        rawHeader = data.subdata(in: 16..<(16 + length))
        header = try jsonObject(rawHeader); bytes = data; contentStart = 8 + hs; self.unpacked = unpacked
        try require(header["files"] is [String: Any], "Missing ASAR files")
        try visit(header, prefix: "", depth: 0)
        for (name, node) in entries {
            if let link = node["link"] as? String {
                try require(safeRelative(link) && (entries[link] != nil || directories.contains(link)), "Invalid ASAR link: \(name)")
                var seen = Set([name]); var current = link
                while let next = entries[current]?["link"] as? String { try require(seen.insert(current).inserted, "ASAR link cycle"); current = next }
            } else {
                let contents = try read(name)
                // External resources may be signed after packing. Electron reads their
                // filesystem bytes and skips the archive's pre-signing hash/size.
                // Full bundle signature verification protects these unchanged files.
                if node["unpacked"] as? Bool != true, let integrity = node["integrity"] {
                    guard let i = integrity as? [String: Any], let block = i["blockSize"] as? NSNumber, CFGetTypeID(block) != CFBooleanGetTypeID(), let hashes = i["blocks"] as? [String], let hash = i["hash"] as? String else { throw EngineError("Malformed ASAR integrity: \(name)") }
                    let size = block.intValue
                    try require(i["algorithm"] as? String == "SHA256" && size > 0 && size <= 64 * 1024 * 1024 && Double(size) == block.doubleValue, "Unsupported ASAR integrity")
                    try require(hash == digest(contents) && hashes == Self.blocks(contents, size: size), "ASAR integrity mismatch: \(name)")
                }
            }
        }
    }
    init(url: URL) throws {
        try noSymlink(url)
        let u = URL(fileURLWithPath: url.path + ".unpacked", isDirectory: true)
        if exists(u) { try noSymlink(u) }
        try self.init(data: Data(contentsOf: url, options: .mappedIfSafe), unpacked: exists(u) ? u : nil)
    }
    mutating func visit(_ node: [String: Any], prefix: String, depth: Int) throws {
        try require(depth <= 128 && entries.count <= 500_000, "ASAR directory limit exceeded")
        guard let children = node["files"] as? [String: Any] else { throw EngineError("Malformed ASAR directory") }
        for name in children.keys.sorted() {
            try require(safeComponent(name), "Unsafe ASAR path component")
            guard let child = children[name] as? [String: Any] else { throw EngineError("Malformed ASAR node") }
            let path = prefix.isEmpty ? name : prefix + "/" + name
            if child["files"] != nil {
                try require(child["link"] == nil && child["offset"] == nil && child["size"] == nil, "Ambiguous ASAR directory")
                directories.insert(path)
                try visit(child, prefix: path, depth: depth + 1)
            } else {
                if child["link"] != nil { try require(child["link"] is String && child["size"] == nil && child["offset"] == nil, "Ambiguous ASAR link") }
                else {
                    guard let size = child["size"] as? NSNumber, CFGetTypeID(size) != CFBooleanGetTypeID() else { throw EngineError("Missing ASAR file size") }
                    try require(size.doubleValue >= 0 && size.doubleValue <= Double(Int.max / 2) && size.doubleValue.rounded() == size.doubleValue, "Invalid ASAR file size")
                    if let flag = child["unpacked"] { try require(flag is Bool, "Invalid unpacked flag") }
                    if (child["unpacked"] as? Bool) != true {
                        guard let value = child["offset"] as? String, let offset = Int(value), offset >= 0 else { throw EngineError("Invalid ASAR offset") }
                        try require(offset <= bytes.count - contentStart && size.intValue <= bytes.count - contentStart - offset, "ASAR file is outside payload")
                    }
                }
                entries[path] = child
            }
        }
    }
    // Resolve archive-relative paths and ASAR directory/file links before deciding
    // whether a resource belongs to Electron's main process.
    func resolvedPath(_ path: String) throws -> String {
        try require(!path.hasPrefix("/") && !path.contains("\\"), "Invalid archive entry path")
        var parts: [String] = []
        for part in path.split(separator: "/") {
            if part == "." { continue }
            if part == ".." { try require(!parts.isEmpty, "Archive entry escapes its root"); parts.removeLast() }
            else { try require(safeComponent(String(part)), "Invalid archive entry component"); parts.append(String(part)) }
        }
        var seen = Set<String>()
        while true {
            let name = parts.joined(separator: "/")
            try require(seen.insert(name).inserted && seen.count <= 128, "Archive entry link cycle")
            var expanded = false
            for end in 1..<(parts.count + 1) {
                let prefix = parts.prefix(end).joined(separator: "/")
                if let link = entries[prefix]?["link"] as? String {
                    parts = link.split(separator: "/").map(String.init) + parts.dropFirst(end)
                    expanded = true; break
                }
            }
            if !expanded { return name }
        }
    }
    func mainEntry() throws -> String {
        let packagePath = try resolvedPath("package.json")
        let package = try jsonObject(read(packagePath))
        let main = package["main"] as? String ?? "index.js"
        try require(!main.isEmpty, "Empty main-process entry")
        var visited = Set<String>()
        func resolve(_ input: String) throws -> String? {
            let path = try resolvedPath(input)
            try require(visited.insert(path).inserted && visited.count <= 128, "Main-process entry resolution cycle")
            for candidate in [path, path + ".js", path + ".json", path + ".node"] {
                let name = try resolvedPath(candidate)
                if let node = entries[name], node["link"] == nil { return name }
            }
            if directories.contains(path) {
                let nested = try resolvedPath(path + "/package.json")
                if entries[nested] != nil {
                    let metadata = try jsonObject(read(nested))
                    if let entry = metadata["main"] as? String, !entry.isEmpty,
                       let found = try resolve(path + "/" + entry) { return found }
                }
                for suffix in ["/index.js", "/index.json", "/index.node"] {
                    let name = try resolvedPath(path + suffix)
                    if entries[name] != nil { return name }
                }
            }
            return nil
        }
        guard let entry = try resolve(main) else { throw EngineError("Main-process entry cannot be resolved safely") }
        return entry
    }
    func read(_ name: String) throws -> Data {
        guard let node = entries[name] else { throw EngineError("Missing ASAR file: \(name)") }
        try require(node["link"] == nil, "ASAR injection cannot follow links")
        let size = (node["size"] as! NSNumber).intValue
        if node["unpacked"] as? Bool == true {
            guard let unpacked else { throw EngineError("Missing unpacked tree") }
            let file = unpacked.appendingPathComponent(name)
            try noSymlink(file); let a = try FileManager.default.attributesOfItem(atPath: file.path)
            try require(a[.type] as? FileAttributeType == .typeRegular, "Invalid unpacked file")
            return try Data(contentsOf: file, options: .mappedIfSafe)
        }
        let start = contentStart + Int(node["offset"] as! String)!
        return bytes.subdata(in: start..<(start + size))
    }
    static func blocks(_ data: Data, size: Int) -> [String] {
        if data.isEmpty { return [digest(Data())] }
        return stride(from: 0, to: data.count, by: size).map { digest(data.subdata(in: $0..<min($0 + size, data.count))) }
    }
    static func integrity(_ data: Data, block: Int) -> [String: Any] {
        ["algorithm": "SHA256", "hash": digest(data), "blockSize": block, "blocks": blocks(data, size: block)]
    }
    func replacing(_ replacements: [String: Data]) throws -> Data {
        try require(Set(replacements.keys).isSubset(of: Set(entries.keys)), "Cannot add unknown ASAR file")
        var payload = Data()
        func rebuild(_ node: [String: Any], prefix: String) throws -> [String: Any] {
            var output = node
            guard let children = node["files"] as? [String: Any] else { throw EngineError("Invalid directory") }
            var newChildren: [String: Any] = [:]
            for name in children.keys.sorted() {
                let path = prefix.isEmpty ? name : prefix + "/" + name
                var child = children[name] as! [String: Any]
                if child["files"] != nil { child = try rebuild(child, prefix: path) }
                else if child["link"] == nil && child["unpacked"] as? Bool != true {
                    let contents = try replacements[path] ?? read(path)
                    child["offset"] = String(payload.count); child["size"] = contents.count
                    if replacements[path] != nil {
                        let block = (child["integrity"] as? [String: Any])?["blockSize"] as? Int ?? Self.blockSize
                        child["integrity"] = Self.integrity(contents, block: block)
                    }
                    payload.append(contents)
                } else { try require(replacements[path] == nil, "Cannot patch unpacked file or link") }
                newChildren[name] = child
            }
            output["files"] = newChildren; return output
        }
        let rebuilt = try rebuild(header, prefix: "")
        let raw = try jsonData(rebuilt)
        try require(raw.count < 64 * 1024 * 1024, "ASAR header too large")
        let padded = (raw.count + 3) / 4 * 4
        func word(_ n: Int) -> Data { var v = UInt32(n).littleEndian; return withUnsafeBytes(of: &v) { Data($0) } }
        var result = word(4); result.append(word(padded + 8)); result.append(word(padded + 4)); result.append(word(raw.count)); result.append(raw)
        result.append(Data(repeating: 0, count: padded - raw.count)); result.append(payload)
        return result
    }
}
