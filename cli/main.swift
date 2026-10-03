// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import Foundation
import Darwin

let arguments = Array(CommandLine.arguments.dropFirst())
let usage = """
claudefont 1.0.0 — GPL-3.0-only
Usage: claudefont <status|doctor|install|uninstall|backups> [--app PATH] [--json] [-y]
       claudefont migrate --app TARGET --backup PRISTINE.app --settings CONFIG.json [--themes THEMES.json] -y
       claudefont backups [--prune|--purge] -y
       claudefont --help | --version
Configuration: CLAUDEFONT_CONFIG; backups/logs: CLAUDEFONT_DATA_DIR
Close the selected app before install/uninstall. Doctor tests write access with a temporary probe.
"""
if arguments.contains("--help") || arguments.contains("-h") || arguments.isEmpty { print(usage); exit(0) }
if arguments == ["--version"] { print("claudefont 1.0.0"); exit(0) }
var command = "", path = ProcessInfo.processInfo.environment["CLAUDEFONT_APP"] ?? "/Applications/Claude.app"
var migrationBackup: String?, migrationSettings: String?, migrationThemes: String?
var explicitApp = false
var json = false, yes = false, prune = false, purge = false, index = 0
while index < arguments.count {
    let value = arguments[index]
    switch value {
    case "--app":
        guard index+1 < arguments.count else { fputs("--app needs a path\n",stderr); exit(2) }; index += 1; path = arguments[index]; explicitApp = true
    case "--backup","--settings","--themes":
        guard index+1 < arguments.count else { fputs("\(value) needs a path\n",stderr); exit(2) }; index += 1
        if value == "--backup" { migrationBackup = arguments[index] }
        else if value == "--settings" { migrationSettings = arguments[index] }
        else { migrationThemes = arguments[index] }
    case "--json": json = true
    case "-y","--yes": yes = true
    case "--prune": prune = true
    case "--purge": purge = true
    default:
        guard command.isEmpty && ["status","doctor","install","uninstall","backups","migrate"].contains(value) else { fputs("Unknown argument: \(value)\n",stderr); exit(2) }; command = value
    }
    index += 1
}
func emit(_ object:[String:Any]) throws {
    if json { print(String(decoding:try jsonData(object),as:UTF8.self)) }
    else { for key in object.keys.sorted() { print("\(key): \(object[key]!)") } }
}
do {
    try require(command == "migrate" || (migrationBackup == nil && migrationSettings == nil && migrationThemes == nil),"Migration paths are only valid with migrate")
    if command == "migrate" {
        try require(yes && explicitApp && migrationBackup != nil && migrationSettings != nil,"Migration requires --app TARGET --backup PRISTINE.app --settings CONFIG.json and -y")
    }
    let engine = try FontEngine(path:path)
    switch command {
    case "migrate": try engine.migrate(backupPath:migrationBackup!,settingsPath:migrationSettings!,themesPath:migrationThemes)
    case "status": try emit(engine.status())
    case "doctor":
        let result = engine.status(probe:true); try emit(result)
        if result["permissionDenied"] as? Bool == true || result["canApply"] as? Bool != true { exit(1) }
    case "install","uninstall":
        guard yes else { throw EngineError("Use -y after reviewing the target and backup/restore operation") }
        if command == "install" { try engine.apply() } else { try engine.restore() }
    case "backups":
        if prune || purge { try require(yes,"Backup deletion requires -y") }
        try emit(engine.backupReport(prune:prune,purge:purge))
    default: throw EngineError("Missing command")
    }
} catch { fputs("claudefont: \(error)\n",stderr); exit(1) }
