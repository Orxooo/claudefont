// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import CryptoKit
import Darwin

struct EngineError: Error, CustomStringConvertible {
    let description: String
    init(_ message: String) { description = message }
}
func require(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw EngineError(message) }
}
func digest(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func jsonData(_ object: Any) throws -> Data { try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .withoutEscapingSlashes]) }
func jsonObject(_ data: Data) throws -> [String: Any] {
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw EngineError("Expected a JSON object") }; return object
}
func writeJSON(_ object: Any, _ url: URL) throws { try jsonData(object).write(to: url, options: .atomic) }
func exists(_ url: URL) -> Bool { FileManager.default.fileExists(atPath: url.path) }
func safeComponent(_ name: String) -> Bool {
    !name.isEmpty && name != "." && name != ".." && !name.contains("/") && !name.contains("\\") && !name.contains(where: { $0.asciiValue.map { $0 < 32 } == true })
}
func safeRelative(_ name: String) -> Bool {
    !name.hasPrefix("/") && name.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { safeComponent(String($0)) }
}
func noSymlink(_ url: URL, allowMissing: Bool = false) throws {
    var current = URL(fileURLWithPath: "/", isDirectory: true)
    for part in url.standardizedFileURL.pathComponents.dropFirst() {
        current.appendPathComponent(part)
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: current.path)
            if attributes[.type] as? FileAttributeType == .typeSymbolicLink {
                // Foundation normalizes /private aliases back to these protected macOS paths.
                let systemAliases = ["/var":"private/var", "/tmp":"private/tmp", "/etc":"private/etc"]
                let destination = try FileManager.default.destinationOfSymbolicLink(atPath:current.path)
                try require(systemAliases[current.path] == destination || systemAliases[current.path].map { "/" + $0 } == destination,
                            "Symbolic link path is not supported: \(current.path)")
            }
        } catch let error as EngineError { throw error }
        catch { if allowMissing && !exists(current) { return }; throw error }
    }
}
func ensureDirectory(_ url: URL) throws {
    try noSymlink(url, allowMissing: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    try noSymlink(url)
}
struct ProcessResult { let status: Int32; let output: Data; let error: Data }
@discardableResult func run(_ executable: String, _ args: [String], log: URL? = nil) throws -> ProcessResult {
    let process = Process(); process.executableURL = URL(fileURLWithPath: executable); process.arguments = args
    let work = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("claudefont-process-" + UUID().uuidString)
    try ensureDirectory(work); defer { try? FileManager.default.removeItem(at: work) }
    let out = work.appendingPathComponent("out"), err = work.appendingPathComponent("err")
    FileManager.default.createFile(atPath: out.path, contents: nil); FileManager.default.createFile(atPath: err.path, contents: nil)
    let oh = try FileHandle(forWritingTo: out), eh = try FileHandle(forWritingTo: err)
    process.standardOutput = oh; process.standardError = eh
    try process.run(); process.waitUntilExit(); try oh.close(); try eh.close()
    let output = try Data(contentsOf: out), errors = try Data(contentsOf: err)
    if let log { var record = Data(("$ \(executable) \(args.joined(separator: " "))\nexit=\(process.terminationStatus)\n").utf8); record.append(output); record.append(errors); try record.write(to: log) }
    return ProcessResult(status: process.terminationStatus, output: output, error: errors)
}
func checked(_ executable: String, _ args: [String], log: URL? = nil) throws -> ProcessResult {
    let result = try run(executable, args, log: log)
    try require(result.status == 0, "\(URL(fileURLWithPath: executable).lastPathComponent) failed (\(result.status)): \(String(data: result.error.suffix(1500), encoding: .utf8) ?? "see log")")
    return result
}
// Tree identity includes regular file contents, mode bits and internal symlink targets.
// Framework symlinks are permitted only when their resolved destination stays in the bundle.
func treeDigest(_ root: URL) throws -> String {
    try noSymlink(root)
    let fm = FileManager.default
    var enumerationError: Error?
    guard let iterator = fm.enumerator(at: root, includingPropertiesForKeys: nil, options: [], errorHandler: { _, error in enumerationError = error; return false }) else { throw EngineError("Cannot enumerate bundle") }
    var records = [String]()
    while let item = iterator.nextObject() as? URL {
        let relative = String(item.path.dropFirst(root.path.count + 1))
        let a = try fm.attributesOfItem(atPath: item.path)
        let kind = a[.type] as? FileAttributeType
        let mode = (a[.posixPermissions] as? NSNumber)?.intValue ?? 0
        if kind == .typeSymbolicLink {
            let target = try fm.destinationOfSymbolicLink(atPath: item.path)
            let resolved = item.resolvingSymlinksInPath().standardizedFileURL.path
            try require(resolved.hasPrefix(root.path + "/") && exists(URL(fileURLWithPath: resolved)), "Unsafe bundle link: \(relative)")
            records.append("L \(mode) \(relative) \(target)"); iterator.skipDescendants()
        } else if kind == .typeDirectory { records.append("D \(mode) \(relative)") }
        else if kind == .typeRegular { records.append("F \(mode) \(relative) \(digest(try Data(contentsOf: item, options: .mappedIfSafe)))") }
        else { throw EngineError("Unsupported bundle file: \(relative)") }
    }
    if let enumerationError { throw enumerationError }
    let rootMode = (try fm.attributesOfItem(atPath: root.path)[.posixPermissions] as? NSNumber)?.intValue ?? 0
    return digest(try jsonData(["rootMode":rootMode,"entries":records.sorted()]))
}
func copyBundle(_ source: URL, _ destination: URL, log: URL? = nil) throws {
    try require(!exists(destination), "Destination already exists: \(destination.path)")
    try noSymlink(destination.deletingLastPathComponent())
    _ = try checked("/usr/bin/ditto", ["--rsrc", "--extattr", source.path, destination.path], log: log)
}
