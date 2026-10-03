// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Orxooo
import SwiftUI
import Foundation

enum Updater {
    static let version = "1.0.0"
    static let releases = URL(string: "https://github.com/Orxooo/claudefont/releases")!
    static let endpoint = URL(string: "https://api.github.com/repos/Orxooo/claudefont/releases/latest")!
    static func isNewer(_ tag: String) -> Bool {
        let normalized = tag.hasPrefix("v") || tag.hasPrefix("V") ? String(tag.dropFirst()) : tag
        let parts = normalized.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 3, normalized.split(separator: ".").count == 3 else { return false }
        let current = version.split(separator: ".").compactMap { Int($0) }
        for (a, b) in zip(parts, current) { if a != b { return a > b } }
        return false
    }
}
struct AvailableRelease { let tag: String; let page: URL }
final class UpdateWatcher: ObservableObject {
    @Published var available: AvailableRelease?
    @Published var checking = false
    @Published var message = ""
    private struct Release: Decodable { let tag_name: String; let html_url: String; let draft: Bool; let prerelease: Bool }
    func checkIfDue() {
        let defaults = UserDefaults.standard
        guard defaults.object(forKey: "autoCheckUpdates") as? Bool ?? true else { return }
        let last = defaults.double(forKey: "lastReleaseCheck")
        if Date().timeIntervalSince1970 - last >= 86400 { check(manual: false) }
    }
    func skip() {
        if let available { UserDefaults.standard.set(available.tag, forKey: "skippedRelease") }
        available = nil
    }
    func check(manual: Bool = true) {
        guard !checking else { return }; checking = true; message = ""
        var request = URLRequest(url: Updater.endpoint); request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("claudefont/" + Updater.version, forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self else { return }; self.checking = false
                guard error == nil, let response = response as? HTTPURLResponse, response.statusCode == 200,
                      let data, let release = try? JSONDecoder().decode(Release.self, from: data),
                      let page = URL(string: release.html_url), page.scheme == "https", page.host == "github.com",
                      page.path.hasPrefix("/Orxooo/claudefont/releases/") else {
                    self.message = Copy.shared.effective == .zh ? "检查失败，请稍后重试。" : "Could not check. Try again later."; return
                }
                UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "lastReleaseCheck")
                if !release.draft && !release.prerelease && Updater.isNewer(release.tag_name),
                   manual || UserDefaults.standard.string(forKey: "skippedRelease") != release.tag_name {
                    self.available = AvailableRelease(tag: release.tag_name, page: page)
                    self.message = t("update.title", ["{tag}":release.tag_name])
                } else { self.available = nil; self.message = Copy.shared.effective == .zh ? "当前已是最新稳定版。" : "You have the latest stable release." }
            }
        }.resume()
    }
}
struct UpdateCheckButton: View {
    @StateObject private var updates = UpdateWatcher()
    @ObservedObject private var copy = Copy.shared
    var body: some View {
        HStack {
            Button(copy.effective == .zh ? "检查新版本" : "Check for updates") { updates.check() }
                .buttonStyle(WorkspaceActionStyle()).disabled(updates.checking)
            if updates.checking { ProgressView().controlSize(.small) }
            if let release = updates.available { Link(t("update.download"), destination: release.page) }
            else { Text(updates.message).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
