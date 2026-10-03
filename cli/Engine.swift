// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

struct ApplicationTarget {
    let url: URL
    var resources: URL { url.appendingPathComponent("Contents/Resources") }
    var archive: URL { resources.appendingPathComponent("app.asar") }
    var plist: URL { url.appendingPathComponent("Contents/Info.plist") }
    var key: String { String(digest(Data(url.path.utf8)).prefix(20)) }
    func metadata() throws -> [String:Any] {
        try noSymlink(url); try noSymlink(plist)
        guard let object = try PropertyListSerialization.propertyList(from:Data(contentsOf:plist),format:nil) as? [String:Any] else { throw EngineError("Invalid application metadata") }
        return object
    }
    func runtime(_ info: [String:Any]) throws -> URL {
        let wrapper = info["CFBundleExecutable"] as? String ?? ""
        let name = info["CFBundleIdentifier"] as? String == "io.github.orxooo.claudefont.test"
            ? info["ClaudefontRuntimeExecutable"] as? String ?? wrapper : wrapper
        try require(safeComponent(name),"Invalid application executable")
        let result = url.appendingPathComponent("Contents/MacOS").appendingPathComponent(name)
        try noSymlink(result); try require(FileManager.default.isExecutableFile(atPath:result.path),"Application executable is missing")
        return result
    }
}
struct StoredBackup: Codable {
    let id: String
    let version: String
    let originalPath: String
    let treeHash: String
    let created: Double
    let pristine: Bool
}
struct PreviousInstallation: Codable {
    let targetPath: String
    let version: String
    let archiveHash: String
    let treeHash: String
    let backupID: String
}
struct Installation: Codable { let version: String; let backupID: String; let styleHash: String; let archiveHash: String; let settings: [String:String] }
struct OperationJournal: Codable {
    let appPath: String
    let held: String
    let staged: String
    let originalHash: String
    let replacementHash: String
    let previousInstallation: Installation?
}

final class FontEngine {
    static let preload = ".vite/build/mainView.js"
    let target: ApplicationTarget
    let folder: URL
    let configURL: URL
    let logURL: URL
    let journalURL: URL
    let installationURL: URL
    let previousURL: URL
    private var lockFD: Int32 = -1
    private let fm = FileManager.default
    init(path: String) throws {
        target = ApplicationTarget(url:URL(fileURLWithPath:path).standardizedFileURL)
        let env = ProcessInfo.processInfo.environment
        let home = fm.homeDirectoryForCurrentUser.path
        let data = URL(fileURLWithPath:env["CLAUDEFONT_DATA_DIR"] ?? home + "/.local/share/claudefont",isDirectory:true)
        folder = data.appendingPathComponent("targets").appendingPathComponent(target.key)
        configURL = URL(fileURLWithPath:env["CLAUDEFONT_CONFIG"] ?? home + "/.config/claudefont/config.json")
        try ensureDirectory(folder)
        logURL = folder.appendingPathComponent("operation.log")
        journalURL = folder.appendingPathComponent("journal.json")
        installationURL = folder.appendingPathComponent("installed.json")
        previousURL = folder.appendingPathComponent("previous.json")
        let lock = folder.appendingPathComponent("engine.lock")
        try noSymlink(lock,allowMissing:true)
        lockFD = open(lock.path,O_CREAT|O_RDWR|O_NOFOLLOW,0o600)
        guard lockFD >= 0, flock(lockFD,LOCK_EX|LOCK_NB) == 0 else { throw EngineError("Another operation is using this target") }
    }
    deinit { if lockFD >= 0 { flock(lockFD,LOCK_UN); close(lockFD) } }
    func note(_ text: String) {
        print(text)
        let record = Data((ISO8601DateFormatter().string(from:Date()) + " " + text + "\n").utf8)
        if !exists(logURL) { _ = fm.createFile(atPath:logURL.path,contents:nil,attributes:[.posixPermissions:0o600]) }
        if let handle = try? FileHandle(forWritingTo:logURL) { _ = try? handle.seekToEnd(); try? handle.write(contentsOf:record); try? handle.close() }
    }
    func settings() throws -> [String:Any] {
        var values = StyleSchema.defaults
        if exists(configURL) {
            try noSymlink(configURL)
            let data = try Data(contentsOf:configURL)
            try require(data.count <= 1_000_000,"Configuration is too large")
            values.merge(try jsonObject(data)) { _, new in new }
        }
        return try StyleSchema.validated(StyleSchema.portable(values))
    }
    func installation() throws -> Installation? {
        guard exists(installationURL) else { return nil }; try noSymlink(installationURL)
        return try JSONDecoder().decode(Installation.self,from:Data(contentsOf:installationURL))
    }
    private func save<T:Encodable>(_ value:T, at url:URL) throws {
        try noSymlink(url,allowMissing:true); try JSONEncoder().encode(value).write(to:url,options:.atomic)
    }
    private var backupsRoot: URL { folder.appendingPathComponent("backups",isDirectory:true) }
    func backups() throws -> [StoredBackup] {
        guard exists(backupsRoot) else { return [] }; try noSymlink(backupsRoot)
        return try fm.contentsOfDirectory(at:backupsRoot,includingPropertiesForKeys:nil).map { item in
            try noSymlink(item)
            try require(safeComponent(item.lastPathComponent),"Invalid backup directory")
            let manifest = item.appendingPathComponent("manifest.json"); try noSymlink(manifest)
            let record = try JSONDecoder().decode(StoredBackup.self,from:Data(contentsOf:manifest))
            try require(record.id == item.lastPathComponent && record.originalPath == target.url.path,"Backup belongs to another target")
            return record
        }.sorted { $0.created > $1.created }
    }
    private func backupApp(_ backup:StoredBackup, verifySignature:Bool = true) throws -> URL {
        try require(safeComponent(backup.id) && backup.originalPath == target.url.path,"Unsafe backup identity")
        let url = backupsRoot.appendingPathComponent(backup.id).appendingPathComponent("Application.app")
        try noSymlink(url)
        try require(try treeDigest(url) == backup.treeHash,"Backup content changed; refusing restoration")
        if verifySignature { _ = try checked("/usr/bin/codesign",["--verify","--deep","--strict",url.path]) }
        return url
    }
    private func createBackup(info:[String:Any],pristine:Bool,source:URL? = nil) throws -> StoredBackup {
        try ensureDirectory(backupsRoot)
        let id = UUID().uuidString.lowercased(), place = backupsRoot.appendingPathComponent(id)
        try ensureDirectory(place)
        do {
            let source = source ?? target.url
            let hash = try treeDigest(source)
            let copy = place.appendingPathComponent("Application.app")
            try copyBundle(source,copy)
            try require(try treeDigest(copy) == hash,"Backup copy did not preserve the application")
            let record = StoredBackup(id:id,version:info["CFBundleShortVersionString"] as? String ?? "unknown",originalPath:target.url.path,treeHash:hash,created:Date().timeIntervalSince1970,pristine:pristine)
            try save(record,at:place.appendingPathComponent("manifest.json")); return record
        } catch { try? fm.removeItem(at:place); throw error }
    }
    private func validate(_ candidate:ApplicationTarget? = nil) throws -> (info:[String:Any], archive:Archive, preload:Data) {
        let target = candidate ?? self.target
        try require(target.url.pathExtension.lowercased() == "app","Choose an application bundle")
        let info = try target.metadata(); _ = try target.runtime(info)
        let archive = try Archive(url:target.archive)
        let script = try archive.read(Self.preload)
        let source = String(decoding:script,as:UTF8.self)
        try require(source.contains("ipcRenderer") || source.contains("contextBridge"),"Renderer preload is not recognized")
        try require(!["app.whenReady","new BrowserWindow","app.on("].contains(where:source.contains),"Preload contains main-process code")
        try require(try archive.mainEntry() != Self.preload,"Cannot modify the main-process entry")
        if let table = info["ElectronAsarIntegrity"] as? [String:Any], let entry = table["Resources/app.asar"] as? [String:Any] {
            try require((entry["algorithm"] as? String)?.uppercased() == "SHA256" && entry["hash"] as? String == digest(archive.rawHeader),"Electron archive integrity metadata does not match")
        } else { throw EngineError("Electron archive integrity metadata is missing") }
        return (info,archive,script)
    }
    private func foreignPatch(_ source:String) -> Bool {
        source.range(of:#"/\*[^*\n]{0,100}font[-_]v[0-9]+[^*\n]*\*/"#,options:.regularExpression) != nil
    }
    private func previous() throws -> PreviousInstallation? {
        guard exists(previousURL) else { return nil }
        try noSymlink(previousURL)
        return try JSONDecoder().decode(PreviousInstallation.self,from:Data(contentsOf:previousURL))
    }
    private func previousBackup(info:[String:Any],archive:Archive) throws -> StoredBackup? {
        guard let receipt = try previous(), receipt.targetPath == target.url.path,
              receipt.version == info["CFBundleShortVersionString"] as? String,
              receipt.archiveHash == digest(archive.rawHeader) else { return nil }
        try require(try treeDigest(target.url) == receipt.treeHash,"Previous installation changed after migration")
        _ = try checked("/usr/bin/codesign",["--verify","--deep","--strict",target.url.path])
        guard let backup = try backups().first(where:{$0.id == receipt.backupID && $0.pristine && $0.version == receipt.version}) else {
            throw EngineError("Previous installation has no verified pristine backup")
        }
        _ = try backupApp(backup)
        return backup
    }
    // This explicit import is the only path that accepts earlier font modifications.
    // It never runs or changes either supplied application or its user profile.
    func migrate(backupPath:String,settingsPath:String,themesPath:String? = nil) throws {
        try require(!exists(journalURL),"Recover interrupted operation before migrating")
        let imported = try MigrationSettings(settings:URL(fileURLWithPath:settingsPath),themes:themesPath.map { URL(fileURLWithPath:$0) })
        let pristineTarget = ApplicationTarget(url:URL(fileURLWithPath:backupPath).standardizedFileURL)
        try require(pristineTarget.url != target.url,"Choose a separate pristine application backup")
        let currentHash = try treeDigest(target.url), pristineHash = try treeDigest(pristineTarget.url)
        let current = try validate(), pristine = try validate(pristineTarget)
        for item in [target.url,pristineTarget.url] {
            _ = try checked("/usr/bin/codesign",["--verify","--deep","--strict",item.path])
        }
        try PreviousValidation.verify(current:target,pristine:pristineTarget,currentInfo:current.info,pristineInfo:pristine.info,
                                      currentArchive:current.archive,pristineArchive:pristine.archive,
                                      currentPreload:current.preload,pristinePreload:pristine.preload)
        try require(try treeDigest(target.url) == currentHash && treeDigest(pristineTarget.url) == pristineHash,"Applications changed during migration validation")
        // Preflight output paths and preserve byte-for-byte existing files before importing.
        let themeURL = configURL.deletingLastPathComponent().appendingPathComponent("themes.json")
        var outputs:[(URL,Data)] = [(configURL,imported.settingsData)]
        if let data = imported.themesData { outputs.append((themeURL,data)) }
        try require(!outputs.contains(where:{ $0.0.standardizedFileURL == imported.sourceSettings || $0.0.standardizedFileURL == imported.sourceThemes }),"Select previous settings outside the new configuration folder")
        var originals:[URL:Data] = [:]
        for (url,_) in outputs + [(previousURL,Data())] {
            try noSymlink(url,allowMissing:true)
            if exists(url) { originals[url] = try Data(contentsOf:url) }
        }
        let saved = try createBackup(info:pristine.info,pristine:true,source:pristineTarget.url)
        var written:[URL] = []
        do {
            _ = try backupApp(saved)
            try require(saved.treeHash == pristineHash,"Pristine backup changed while copying")
            try require(try treeDigest(target.url) == currentHash,"Target changed while preparing migration")
            for (url,data) in outputs { try ensureDirectory(url.deletingLastPathComponent()); try data.write(to:url,options:.atomic); written.append(url) }
            let receipt = PreviousInstallation(targetPath:target.url.path,version:saved.version,archiveHash:digest(current.archive.rawHeader),treeHash:currentHash,backupID:saved.id)
            try save(receipt,at:previousURL)
        } catch {
            var rollbackError:Error?
            for url in written.reversed() {
                do {
                    if let data = originals[url] { try data.write(to:url,options:.atomic) }
                    else if exists(url) { try fm.removeItem(at:url) }
                } catch { rollbackError = error }
            }
            try? fm.removeItem(at:backupsRoot.appendingPathComponent(saved.id))
            if let rollbackError { throw EngineError("Migration failed and settings rollback needs inspection: \(rollbackError); original error: \(error)") }
            throw error
        }
        note("Previous changes preserved. Settings and themes imported; apply settings to transition using the verified pristine backup")
    }
    private func notRunning() throws {
        let result = try checked("/bin/ps",["-axo","comm="])
        let paths = String(decoding:result.output,as:UTF8.self).split(separator:"\n")
        try require(!paths.contains(where:{$0.trimmingCharacters(in:.whitespaces).hasPrefix(target.url.path + "/")}),"Close the selected Claude application before applying or restoring")
    }
    private func signed(_ app:URL) throws {
        let ent = try run("/usr/bin/codesign",["-d","--entitlements",":-",app.path])
        try require(ent.status == 0,"Cannot read original signing capabilities")
        var dictionary:[String:Any] = [:]
        if !ent.output.isEmpty { dictionary = try PropertyListSerialization.propertyList(from:ent.output,format:nil) as? [String:Any] ?? [:] }
        let identity = ProcessInfo.processInfo.environment["CLAUDEFONT_TARGET_SIGN_IDENTITY"] ?? "-"
        if identity == "-" {
            for key in ["application-identifier","com.apple.application-identifier","com.apple.developer.team-identifier","keychain-access-groups","com.apple.security.application-groups"] { dictionary.removeValue(forKey:key) }
        }
        // Nested frameworks retain their vendor signatures. The re-signed main
        // executable must permit those libraries when its Team ID changes.
        dictionary["com.apple.security.cs.disable-library-validation"] = true
        let details = try run("/usr/bin/codesign",["-d","--verbose=4",app.path])
        let text = String(decoding:details.error,as:UTF8.self)
        let regex = try NSRegularExpression(pattern:#"flags=(0x[0-9a-fA-F]+)"#)
        guard let found = regex.firstMatch(in:text,range:NSRange(text.startIndex...,in:text)),let range = Range(found.range(at:1),in:text) else { throw EngineError("Cannot read original signature flags") }
        let temp = folder.appendingPathComponent("signing-entitlements.plist")
        try PropertyListSerialization.data(fromPropertyList:dictionary,format:.xml,options:0).write(to:temp,options:.atomic)
        defer { try? fm.removeItem(at:temp) }
        for name in ["com.apple.FinderInfo","com.apple.ResourceFork"] { _ = try run("/usr/bin/xattr",["-dr",name,app.path]) }
        let arguments = ["--force","--sign",identity,"--options",String(text[range]),"--entitlements",temp.path]
        let stagedTarget = ApplicationTarget(url:app), info = try stagedTarget.metadata()
        let runtime = try stagedTarget.runtime(info)
        if runtime.lastPathComponent != info["CFBundleExecutable"] as? String {
            _ = try checked("/usr/bin/codesign",arguments + [runtime.path])
        }
        _ = try checked("/usr/bin/codesign",arguments + [app.path])
        _ = try checked("/usr/bin/codesign",["--verify","--deep","--strict",app.path])
    }
    private func smoke() throws {
        let info = try target.metadata(), executable = try target.runtime(info)
        let profile = fm.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("claudefont-smoke-" + UUID().uuidString)
        try ensureDirectory(profile); defer { try? fm.removeItem(at:profile) }
        let child = Process(); child.executableURL = executable; child.arguments = ["--user-data-dir=" + profile.path]
        let out = folder.appendingPathComponent("smoke.log"); _ = fm.createFile(atPath:out.path,contents:nil)
        let handle = try FileHandle(forWritingTo:out); defer { try? handle.close() }
        child.standardOutput = handle; child.standardError = handle
        try child.run()
        defer {
            if child.isRunning {
                child.terminate(); let deadline = Date().addingTimeInterval(2)
                while child.isRunning && Date() < deadline { Thread.sleep(forTimeInterval:0.05) }
                if child.isRunning { kill(child.processIdentifier,SIGKILL) }
                child.waitUntilExit()
            }
        }
        let electron = target.url.appendingPathComponent("Contents/Frameworks/Electron Framework.framework/Electron Framework")
        let expectsRenderer = exists(electron)
        let startupDeadline = Date().addingTimeInterval(expectsRenderer ? 20 : 5)
        var rendererSince: [Int32:Date] = [:]
        while child.isRunning && Date() < startupDeadline {
            if expectsRenderer {
                // Observing our renderer descendant proves that dyld loaded
                // Electron; a main process stalled in the loader is insufficient.
                let renderers = try rendererProcesses(parent:child.processIdentifier)
                rendererSince = rendererSince.filter { renderers.contains($0.key) }
                for pid in renderers where rendererSince[pid] == nil { rendererSince[pid] = Date() }
                if rendererSince.values.contains(where:{Date().timeIntervalSince($0) >= 1}) { return }
            }
            Thread.sleep(forTimeInterval:0.1)
        }
        try require(child.isRunning,"Application stopped during the isolated startup check; see smoke.log")
        try require(!expectsRenderer,"Electron renderer did not start during the isolated startup check; see smoke.log")
    }
    private func rendererProcesses(parent:Int32) throws -> Set<Int32> {
        let result = try checked("/bin/ps",["-axo","pid=,ppid=,comm="])
        let rows = String(decoding:result.output,as:UTF8.self).split(separator:"\n").compactMap { line -> (Int32,Int32,String)? in
            let parts = line.split(maxSplits:2,omittingEmptySubsequences:true,whereSeparator:{$0 == " " || $0 == "\t"})
            guard parts.count == 3, let pid = Int32(parts[0]), let ppid = Int32(parts[1]) else { return nil }
            return (pid,ppid,String(parts[2]))
        }
        var descendants:Set<Int32> = [parent]
        var count = 0
        while descendants.count != count {
            count = descendants.count
            for (pid,ppid,_) in rows where descendants.contains(ppid) { descendants.insert(pid) }
        }
        return Set(rows.compactMap { pid,_,path in
            pid != parent && descendants.contains(pid) && path.hasPrefix(target.url.path + "/") && path.hasSuffix(" (Renderer)") ? pid : nil
        })
    }
    func recover() throws {
        guard exists(journalURL) else { return }; try noSymlink(journalURL)
        let record = try JSONDecoder().decode(OperationJournal.self,from:Data(contentsOf:journalURL))
        try require(record.appPath == target.url.path,"Journal belongs to another target")
        let parent = target.url.deletingLastPathComponent()
        let held = URL(fileURLWithPath:record.held), staged = URL(fileURLWithPath:record.staged)
        for item in [held,staged] {
            try require(item.deletingLastPathComponent() == parent && item.lastPathComponent.hasPrefix(".claudefont-") && item.pathExtension == "app","Unsafe journal artifact")
            try noSymlink(item,allowMissing:true)
        }
        if exists(held) {
            try require(try treeDigest(held) == record.originalHash,"Original held app changed")
            if exists(target.url) {
                try require(try treeDigest(target.url) == record.replacementHash,"Target changed after interruption; inspect before recovering")
                try fm.removeItem(at:target.url)
            }
            try fm.moveItem(at:held,to:target.url)
        } else {
            try require(exists(target.url) && (try treeDigest(target.url)) == record.originalHash,"Interrupted transaction needs manual inspection")
        }
        if exists(staged) { try fm.removeItem(at:staged) }
        if let previous = record.previousInstallation { try save(previous,at:installationURL) }
        else if exists(installationURL) { try fm.removeItem(at:installationURL) }
        try fm.removeItem(at:journalURL)
        note("Recovered the original application from an interrupted operation")
    }
    private func replace(with staged:URL, installationAfter:Installation?) throws {
        try notRunning()
        let held = target.url.deletingLastPathComponent().appendingPathComponent(".claudefont-held-" + UUID().uuidString + ".app")
        let record = OperationJournal(appPath:target.url.path,held:held.path,staged:staged.path,originalHash:try treeDigest(target.url),replacementHash:try treeDigest(staged),previousInstallation:try installation())
        try save(record,at:journalURL)
        do {
            try fm.moveItem(at:target.url,to:held)
            try fm.moveItem(at:staged,to:target.url)
            try smoke()
            if let installationAfter { try save(installationAfter,at:installationURL) }
            else if exists(installationURL) { try fm.removeItem(at:installationURL) }
            try fm.removeItem(at:journalURL)
            try? fm.removeItem(at:held)
        } catch {
            try recover(); throw error
        }
    }
    func apply() throws {
        try recover(); try notRunning()
        let cfg = try settings(), css = try StyleCSS.make(cfg)
        let current = try validate()
        _ = try checked("/usr/bin/codesign",["--verify","--deep","--strict",target.url.path])
        let source = String(decoding:current.preload,as:UTF8.self)
        let previous = try previousBackup(info:current.info,archive:current.archive)
        try require(!foreignPatch(source) || previous != nil,"Another font patch is present. Use explicit migration with its pristine backup and settings, or restore/reinstall Claude")
        let prior = try installation()
        let own = source.contains(RendererScript.marker)
        var base = target.url
        var original:StoredBackup? = previous
        if let previous { base = try backupApp(previous) }
        if own {
            guard let prior, prior.version == current.info["CFBundleShortVersionString"] as? String,
                  let saved = try backups().first(where:{$0.id == prior.backupID && $0.pristine}) else { throw EngineError("Current installation has no verified original backup") }
            base = try backupApp(saved); original = saved
        }
        // Terminal dimensions must be adjusted through supported resources, not canvas CSS.
        let terminalRequested = !(cfg["code_font_terminal"] as? String ?? "").isEmpty || StyleSchema.number(cfg,"code_scale_terminal") != 100
        let baseTarget = ApplicationTarget(url:base), archive = try Archive(url:baseTarget.archive)
        let originalScript = try archive.read(Self.preload)
        var replacements = [Self.preload:originalScript + Data(RendererScript.make(css:css).utf8)]
        if terminalRequested { replacements.merge(try TerminalResource.replacements(archive,settings:cfg,excluding:try archive.mainEntry())) { _, new in new } }
        let packed = try archive.replacing(replacements)
        let newArchive = try Archive(data:packed,unpacked:archive.unpacked)
        let backup = try createBackup(info:current.info,pristine:!own && previous == nil)
        if original == nil { original = backup }
        let staged = target.url.deletingLastPathComponent().appendingPathComponent(".claudefont-stage-" + UUID().uuidString + ".app")
        defer { if exists(staged) { try? fm.removeItem(at:staged) } }
        try copyBundle(base,staged)
        let stagedTarget = ApplicationTarget(url:staged)
        try packed.write(to:stagedTarget.archive,options:.atomic)
        var info = try stagedTarget.metadata()
        var table = info["ElectronAsarIntegrity"] as? [String:Any] ?? [:]
        var entry = table["Resources/app.asar"] as? [String:Any] ?? [:]
        entry["hash"] = digest(newArchive.rawHeader); table["Resources/app.asar"] = entry; info["ElectronAsarIntegrity"] = table
        try PropertyListSerialization.data(fromPropertyList:info,format:.xml,options:0).write(to:stagedTarget.plist,options:.atomic)
        try signed(staged)
        try require(try treeDigest(target.url) == backup.treeHash,"Target changed while preparing styles")
        note("Backup verified. Applying renderer styles; original app is retained until startup succeeds")
        let installed = Installation(version:info["CFBundleShortVersionString"] as? String ?? "unknown",backupID:original!.id,styleHash:digest(try jsonData(StyleSchema.portable(cfg))),archiveHash:digest(newArchive.rawHeader),settings:StyleSchema.portable(cfg))
        try replace(with:staged,installationAfter:installed)
        note("Applied styles. Isolated startup survived; check the actual Claude session visually")
    }
    func restore() throws {
        try recover(); try notRunning()
        let info = try target.metadata()
        let installed = try installation()
        let migrated = installed == nil ? try previousBackup(info:info,archive:Archive(url:target.archive)) : nil
        guard installed != nil || migrated != nil else { note("No claudefont installation remains on this target"); return }
        try require((installed?.version ?? migrated?.version) == info["CFBundleShortVersionString"] as? String,"Target version changed; refusing to replace it with an older backup")
        guard let backup = try backups().first(where:{$0.id == (installed?.backupID ?? migrated?.id) && $0.pristine}) else { throw EngineError("No original backup for this target version") }
        let source = try backupApp(backup)
        let before = try createBackup(info:info,pristine:false)
        let staged = target.url.deletingLastPathComponent().appendingPathComponent(".claudefont-restore-" + UUID().uuidString + ".app")
        defer { if exists(staged) { try? fm.removeItem(at:staged) } }
        try copyBundle(source,staged)
        try require(try treeDigest(target.url) == before.treeHash,"Target changed while preparing restoration")
        try replace(with:staged,installationAfter:nil)
        if exists(previousURL) { try fm.removeItem(at:previousURL) }
        note("Restored the complete original application and its signature")
    }
    func status(probe:Bool = false) -> [String:Any] {
        var output:[String:Any] = ["version":"unknown","state":"unsupported","canApply":false,"settingsMatch":false,"permissionDenied":false,"backups":0,"font":""]
        do {
            guard exists(target.url) else { output["state"] = "missing"; return output }
            let state = try validate(), info = state.info, cfg = try settings()
            _ = try StyleCSS.make(cfg)
            let source = String(decoding:state.preload,as:UTF8.self), own = source.contains(RendererScript.marker)
            output["version"] = info["CFBundleShortVersionString"] as? String ?? "unknown"
            let installed = try installation(), saved = try backups()
            let migratedBackup = try previousBackup(info:info,archive:state.archive)
            let migrated = migratedBackup != nil
            let supportArchive = try migratedBackup.map { try Archive(url:ApplicationTarget(url:backupApp($0)).archive) } ?? state.archive
            output["backups"] = saved.count
            output["signOK"] = (try run("/usr/bin/codesign",["--verify","--deep","--strict",target.url.path])).status == 0
            output["integrityOK"] = true
            let desiredHash = digest(try jsonData(StyleSchema.portable(cfg)))
            let matches = own && installed?.styleHash == desiredHash && installed?.archiveHash == digest(state.archive.rawHeader)
            let terminal = !(cfg["code_font_terminal"] as? String ?? "").isEmpty || StyleSchema.number(cfg,"code_scale_terminal") != 100
            let adaptedTerminal = try state.archive.entries.keys.filter { $0.hasPrefix(".vite/renderer/") && $0.hasSuffix(".js") && state.archive.entries[$0]?["link"] == nil }.contains { name in
                String(decoding:try state.archive.read(name),as:UTF8.self).contains(TerminalResource.marker)
            }
            let terminalAvailable = (try? TerminalResource.candidates(supportArchive,excluding:try supportArchive.mainEntry()).count) == 1 || (own && adaptedTerminal)
            let canApply = (!foreignPatch(source) || migrated) && (!terminal || terminalAvailable) && (!own || saved.contains(where:{$0.id == installed?.backupID && $0.pristine && $0.version == output["version"] as? String})) && output["signOK"] as? Bool == true && !exists(journalURL)
            output["state"] = migrated ? "previous" : foreignPatch(source) ? "unsupported" : own ? (matches ? "applied" : "changed") : "clean"
            output["previousReady"] = migrated
            output["canApply"] = canApply; output["settingsMatch"] = matches
            if own || migrated { output["font"] = cfg["font"] as? String ?? "" }
            var regions = Dictionary(uniqueKeysWithValues:StyleSchema.regions.map { ($0,"unverified") })
            // Archive structure alone establishes renderer support, not private page selectors.
            regions["terminal"] = terminalAvailable ? "matched" : "unsupported"
            let written = Dictionary(uniqueKeysWithValues:StyleSchema.regions.map { region in
                (region, own && (region != "terminal" || adaptedTerminal) && (!(installed?.settings["code_font_"+region] ?? "").isEmpty || Double(installed?.settings["code_scale_"+region] ?? "100") != 100))
            })
            output["compatibility"] = ["version":output["version"]!,"versionEvidence":"unverified","runtime":"not_checked","injection":own,"settingsMatch":matches,"canReapply":canApply,"regions":regions,"installedRegions":written]
            if migrated { output["reason"] = "Previous changes preserved; apply settings to transition using the verified pristine backup" }
            if foreignPatch(source) && !migrated { output["reason"] = "Existing foreign font patch: restore with its corresponding tool or reinstall Claude first" }
            if terminal && !terminalAvailable { output["reason"] = "Terminal resource adapter unavailable; restore terminal defaults" }
            if exists(journalURL) { output["reason"] = "Interrupted transaction exists; use uninstall to recover before applying" }
            if probe {
                let temp = target.resources.appendingPathComponent(".claudefont-access-" + UUID().uuidString)
                let fd = open(temp.path,O_CREAT|O_EXCL|O_NOFOLLOW|O_WRONLY,0o600)
                if fd >= 0 { close(fd); unlink(temp.path) }
                else { output["permissionDenied"] = true; output["canApply"] = false; output["reason"] = "macOS denied a temporary access probe. Enable App Management access" }
            }
        } catch { output["reason"] = String(describing:error) }
        return output
    }
    func backupReport(prune:Bool,purge:Bool) throws -> [String:Any] {
        let saved = try backups()
        var retained = Set<String>(), versions = Set<String>()
        for backup in saved where backup.pristine {
            if versions.insert(backup.version).inserted { retained.insert(backup.id) }
        }
        for backup in saved.filter({!$0.pristine}).prefix(2) { retained.insert(backup.id) }
        if let installed = try installation() { retained.insert(installed.backupID) }
        if let receipt = try previous() { retained.insert(receipt.backupID) }
        let removable = saved.filter { !retained.contains($0.id) }
        if purge || prune {
            try require(!exists(journalURL),"Recover interrupted operation before deleting backups")
            if purge { try require(try installation() == nil && previous() == nil,"Restore the installed styles before purging original backups") }
            for record in purge ? saved : removable {
                _ = try backupApp(record,verifySignature:false)
                try fm.removeItem(at:backupsRoot.appendingPathComponent(record.id))
            }
        }
        let current = try backups()
        return ["summary":"\(current.count) complete backups","prunable":prune || purge ? 0 : removable.count,"items":current.map {["id":$0.id,"version":$0.version,"created":$0.created,"pristine":$0.pristine] as [String:Any]}]
    }
}
