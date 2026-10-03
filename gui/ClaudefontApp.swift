// SPDX-License-Identifier: GPL-3.0-only
// Copyright (C) 2026 Orxooo
import SwiftUI
import AppKit
import Darwin

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private var instanceLock: Int32 = -1
    func applicationWillFinishLaunching(_ notification: Notification) {
        let root = URL(fileURLWithPath: ProcessInfo.processInfo.environment["CLAUDEFONT_DATA_DIR"] ?? NSHomeDirectory() + "/.local/share/claudefont")
        do {
            try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
            instanceLock = open(root.appendingPathComponent("gui.lock").path, O_RDWR | O_CREAT | O_NOFOLLOW, 0o600)
            guard instanceLock >= 0, flock(instanceLock, LOCK_EX | LOCK_NB) == 0 else {
                if let id = Bundle.main.bundleIdentifier {
                    NSRunningApplication.runningApplications(withBundleIdentifier: id)
                        .first { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }?
                        .activate(options: [.activateAllWindows])
                }
                NSApplication.shared.terminate(nil); return
            }
        } catch { NSApplication.shared.terminate(nil) }
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
    func applicationWillTerminate(_ notification: Notification) {
        if instanceLock >= 0 { flock(instanceLock, LOCK_UN); close(instanceLock) }
    }
}

@main
struct ClaudefontApplication: App {
    @NSApplicationDelegateAdaptor(ApplicationDelegate.self) private var delegate
    var body: some Scene {
        Window("claudefont", id: "workspace") { WorkspaceView() }
            .defaultSize(width: 1280, height: 760)
            .commands {
                CommandGroup(replacing: .appInfo) {
                    Button(t("about.title")) {
                        NSApplication.shared.sendAction(#selector(NSApplication.orderFrontStandardAboutPanel(_:)), to: nil, from: nil)
                    }
                }
            }
        Window(t("about.title"), id: "about") { WorkspaceAboutView() }
            .windowResizability(.contentSize)
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
    var hexString: String {
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}
