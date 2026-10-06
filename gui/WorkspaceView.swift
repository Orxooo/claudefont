// Copyright (C) 2026 Orxooo
// SPDX-License-Identifier: GPL-3.0-only
import SwiftUI
import AppKit

// The workspace owns presentation only. Model remains the sole owner of CLI work.
private enum WorkspaceTab: String, CaseIterable, Identifiable {
    case overview, fonts, code, background, themes, logs
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .overview: "square.grid.2x2"
        case .fonts: "textformat"
        case .code: "curlybraces"
        case .background: "circle.lefthalf.filled"
        case .themes: "square.stack.3d.up"
        case .logs: "list.bullet.rectangle"
        }
    }
    func title(_ lang: Lang) -> String {
        switch (self, lang) {
        case (.overview, .zh): "概览"
        case (.fonts, .zh): "字体"
        case (.code, .zh): "代码"
        case (.background, .zh): "背景"
        case (.themes, .zh): "主题"
        case (.logs, .zh): "日志"
        case (.overview, _): "Overview"
        case (.fonts, _): "Fonts"
        case (.code, _): "Code"
        case (.background, _): "Background"
        case (.themes, _): "Themes"
        case (.logs, _): "Logs"
        }
    }
}

private enum WorkspaceDesign {
    static let accent = Color(hex: 0xA75E46)
    static func ink(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0xEEEAE4 : 0x292A2C) }
    static func canvas(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x222222 : 0xF5F3EF) }
    static func surface(_ scheme: ColorScheme) -> Color { Color(hex: scheme == .dark ? 0x2D2D2D : 0xFFFEFC) }
    static let radius: CGFloat = 28
}

struct WorkspaceActionStyle: ButtonStyle {
    var prominent = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var enabled
    @Environment(\.isFocused) private var focused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(prominent ? .white : Color.primary)
            .padding(.horizontal, 20)
            .frame(minHeight: 40)
            .background(prominent ? WorkspaceDesign.accent : WorkspaceDesign.surface(colorScheme),
                        in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                focused ? WorkspaceDesign.accent : Color.primary.opacity(prominent ? 0 : 0.08), lineWidth: focused ? 1.5 : 1))
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .opacity(enabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .focusEffectDisabled()
            .animation(reduceMotion ? nil : .smooth(duration: 0.18), value: configuration.isPressed)
    }
}

private struct WorkspaceInputStyle: ViewModifier {
    @FocusState private var focused: Bool
    @Environment(\.colorScheme) private var scheme
    func body(content: Content) -> some View {
        content.textFieldStyle(.plain).font(.system(size: 13))
            .focused($focused).focusEffectDisabled()
            .padding(.horizontal, 14).frame(height: 40)
            .background(WorkspaceDesign.canvas(scheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(
                focused ? WorkspaceDesign.accent : Color.primary.opacity(0.08), lineWidth: focused ? 1.5 : 1))
            .tint(WorkspaceDesign.accent)
    }
}

private final class WorkspaceScaleCell: NSSliderCell {
    override func drawBar(inside rect: NSRect, flipped: Bool) {
        let track = NSRect(x: rect.minX, y: rect.midY - 2.5, width: rect.width, height: 5)
        NSColor.labelColor.withAlphaComponent(0.09).setFill()
        NSBezierPath(roundedRect: track, xRadius: 2.5, yRadius: 2.5).fill()
        let progress = CGFloat((doubleValue - minValue) / (maxValue - minValue))
        let fill = NSRect(x: track.minX, y: track.minY, width: track.width * progress, height: track.height)
        NSColor(calibratedRed: 0.655, green: 0.369, blue: 0.275, alpha: 1).setFill()
        NSBezierPath(roundedRect: fill, xRadius: 2.5, yRadius: 2.5).fill()
    }

    override func drawKnob(_ knobRect: NSRect) {
        let thumb = NSRect(x: knobRect.midX - 7, y: knobRect.midY - 10, width: 14, height: 20)
        let path = NSBezierPath(roundedRect: thumb, xRadius: 5, yRadius: 5)
        NSColor.controlBackgroundColor.setFill(); path.fill()
        NSColor(calibratedRed: 0.655, green: 0.369, blue: 0.275, alpha: 0.8).setStroke()
        path.lineWidth = 1.5; path.stroke()
        NSColor(calibratedRed: 0.655, green: 0.369, blue: 0.275, alpha: 0.65).setFill()
        NSBezierPath(roundedRect: NSRect(x: thumb.midX - 1, y: thumb.midY - 4, width: 2, height: 8),
                     xRadius: 1, yRadius: 1).fill()
    }
}

private final class WorkspaceScaleControl: NSSlider {
    override func keyDown(with event: NSEvent) {
        let direction: Double
        switch event.keyCode {
        case 123, 125: direction = -1
        case 124, 126: direction = 1
        default: super.keyDown(with: event); return
        }
        guard isEnabled else { return }
        doubleValue = min(maxValue, max(minValue, doubleValue + direction * altIncrementValue))
        if let action { sendAction(action, to: target) }
    }
}

private struct WorkspaceScaleSlider: NSViewRepresentable {
    @Binding var value: Double
    var range: ClosedRange<Double> = 80...150
    var step: Double = 5
    @Environment(\.isEnabled) private var enabled

    final class Coordinator: NSObject {
        var parent: WorkspaceScaleSlider
        init(_ parent: WorkspaceScaleSlider) { self.parent = parent }
        @objc func changed(_ sender: NSSlider) {
            let snapped = min(parent.range.upperBound, max(parent.range.lowerBound, (sender.doubleValue / parent.step).rounded() * parent.step))
            sender.doubleValue = snapped
            parent.value = snapped
        }
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSSlider {
        let slider = WorkspaceScaleControl()
        slider.cell = WorkspaceScaleCell()
        slider.minValue = range.lowerBound; slider.maxValue = range.upperBound
        slider.altIncrementValue = step
        slider.numberOfTickMarks = 0
        slider.isContinuous = true
        slider.focusRingType = .none
        slider.target = context.coordinator; slider.action = #selector(Coordinator.changed(_:))
        return slider
    }
    func updateNSView(_ slider: NSSlider, context: Context) {
        context.coordinator.parent = self
        slider.minValue = range.lowerBound; slider.maxValue = range.upperBound
        slider.altIncrementValue = step
        slider.doubleValue = min(range.upperBound, max(range.lowerBound, value)); slider.isEnabled = enabled
        slider.needsDisplay = true
    }
}

private struct WorkspaceOption<Value: Hashable>: Identifiable {
    let value: Value
    let title: String
    var enabled = true
    var destructive = false
    var id: Value { value }
}

private struct WorkspaceOptionRow: View {
    let title: String
    let selected: Bool
    var enabled = true
    var destructive = false
    let action: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Text(title).lineLimit(1)
                Spacer(minLength: 8)
                Image(systemName: "checkmark").font(.system(size: 11, weight: .semibold))
                    .opacity(selected ? 1 : 0).frame(width: 16)
            }
            .font(.system(size: 13, weight: selected ? .semibold : .regular))
            .foregroundStyle(destructive ? .red : selected ? WorkspaceDesign.accent : Color.primary)
            .padding(.horizontal, 12).frame(height: 34)
            .background(WorkspaceDesign.accent.opacity(selected ? 0.10 : hovered ? 0.05 : 0),
                        in: RoundedRectangle(cornerRadius: 12))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
        .onHover { hovered = $0 }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

private struct WorkspaceDropdown<Value: Hashable>: View {
    let title: String
    @Binding var selection: Value
    let options: [WorkspaceOption<Value>]
    var searchable = false
    var symbol: String? = nil
    @State private var expanded = false
    @State private var query = ""
    @Environment(\.colorScheme) private var colorScheme

    private var selectedTitle: String { options.first { $0.value == selection }?.title ?? "—" }
    private var filtered: [WorkspaceOption<Value>] {
        query.isEmpty ? options : options.filter { $0.title.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        Button { query = ""; expanded.toggle() } label: {
            HStack(spacing: 10) {
                if let symbol { Image(systemName: symbol).frame(width: 18) }
                else { Text(selectedTitle).lineLimit(1).truncationMode(.middle) }
                Spacer(minLength: symbol == nil ? 4 : 0)
                Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
            }
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(WorkspaceDesign.ink(colorScheme))
            .padding(.horizontal, 14).frame(width: symbol == nil ? nil : 62, height: 38)
            .background(WorkspaceDesign.canvas(colorScheme), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.primary.opacity(expanded ? 0.18 : 0.08), lineWidth: 1))
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityLabel(title)
        .accessibilityValue(selectedTitle)
        .popover(isPresented: $expanded, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                    .padding(.horizontal, 12).padding(.top, 4)
                if searchable {
                    TextField(Copy.shared.effective == .zh ? "搜索字体" : "Search fonts", text: $query)
                        .modifier(WorkspaceInputStyle())
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 3) {
                            if filtered.isEmpty {
                                Text(Copy.shared.effective == .zh ? "没有匹配的字体" : "No matching fonts")
                                    .font(.system(size: 12)).foregroundStyle(.secondary).padding(12)
                            }
                            ForEach(filtered) { option in
                                WorkspaceOptionRow(title: option.title, selected: option.value == selection,
                                                   enabled: option.enabled, destructive: option.destructive) {
                                    selection = option.value
                                    expanded = false
                                }.id(option.value)
                            }
                        }
                    }
                    .frame(height: min(CGFloat(max(1, filtered.count)) * 37, 296))
                    .onAppear { proxy.scrollTo(selection, anchor: .center) }
                }
            }
            .padding(10).frame(width: searchable ? 286 : 220)
            .background(WorkspaceDesign.surface(colorScheme), in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(Color.primary.opacity(0.10)))
            .tint(WorkspaceDesign.accent)
            .presentationBackground(WorkspaceDesign.surface(colorScheme))
        }
    }
}

private enum WorkspaceCommand: Hashable { case doctor, open, restore, help, about }

// A native color well owns the shared panel connection, so other ColorPickers
// can take over normally. The visible entry point is the entire background card.
private final class WorkspaceBackgroundPicker: NSObject, ObservableObject {
    private let well = NSColorWell()
    private var selection: Binding<Color>?

    func open(_ selection: Binding<Color>) {
        self.selection = selection
        well.color = NSColor(selection.wrappedValue)
        well.target = self
        well.action = #selector(colorChanged(_:))
        well.supportsAlpha = false
        well.activate(true)
        NSColorPanel.shared.makeKeyAndOrderFront(nil)
    }

    @objc private func colorChanged(_ sender: NSColorWell) {
        selection?.wrappedValue = Color(nsColor: sender.color)
    }
}

struct WorkspaceView: View {
    @StateObject private var model = Model()
    @StateObject private var updates = UpdateWatcher()
    @StateObject private var backgroundPicker = WorkspaceBackgroundPicker()
    @ObservedObject private var copy = Copy.shared
    @State private var tab: WorkspaceTab = .overview
    @State private var showHelp = false
    @State private var showApplyConfirm = false
    @State private var showNeedsQuit = false
    @State private var showRestoreConfirm = false
    @State private var showTestConfirm = false
    @State private var showRemoveConfirm = false
    @State private var showApplying = false
    @State private var showSuccess = false
    @State private var showDetails = false
    @State private var themeDraft: WorkspaceThemeDraft?
    @State private var deleteTheme: ThemeDocument?
    @State private var previewDark = false
    @State private var permissionGranted: Bool?
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openWindow) private var openWindow
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var navigationSelection
    @Namespace private var previewSelection

    private var ink: Color { WorkspaceDesign.ink(colorScheme) }
    private let accent = WorkspaceDesign.accent
    private var quiet: Color { WorkspaceDesign.canvas(colorScheme) }
    private var surface: Color { WorkspaceDesign.surface(colorScheme) }
    private var motion: Animation? { reduceMotion ? nil : .smooth(duration: 0.26) }
    private var lang: Lang { copy.effective }
    private func l(_ zh: String, _ en: String) -> String { lang == .zh ? zh : en }

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 6) {
                ForEach(WorkspaceTab.allCases) { item in
                    Button { withAnimation(motion) { tab = item } } label: {
                        Label(item.title(lang), systemImage: item.symbol)
                            .font(.system(size: 14, weight: tab == item ? .semibold : .medium))
                            .foregroundStyle(tab == item ? accent : ink.opacity(0.75))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16).frame(height: 44)
                            .background {
                                if tab == item {
                                    RoundedRectangle(cornerRadius: 14).fill(accent.opacity(0.11))
                                        .matchedGeometryEffect(id: "selected-tab", in: navigationSelection)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 14))
                    }.buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityAddTraits(tab == item ? .isSelected : [])
                }
                Spacer()
            }
            .padding(.horizontal, 10).padding(.top, 16)
            .animation(motion, value: tab)
            .navigationSplitViewColumnWidth(min: 180, ideal: 205)
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 9) {
                    Image(nsImage: NSApplication.shared.applicationIconImage)
                        .resizable().frame(width: 27, height: 27)
                    VStack(alignment: .leading, spacing: 0) {
                        Text("ClaudeFont").font(.system(size: 12, weight: .semibold))
                        Text("V\(Updater.version)")
                            .font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(14)
            }
        } detail: {
            GeometryReader { geometry in
                // Both rails use the same parent width and leading edge. Reserve a stable
                // scrollbar lane so AppKit's changing scroller style cannot shift either rail.
                let lane = NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
                let available = max(0, geometry.size.width - 72 - lane)
                let railWidth = min(880, available)
                let railLeading = 36 + max(0, (available - railWidth) / 2)
            ZStack(alignment: .bottomLeading) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    heading
                    switch tab {
                    case .overview: overview
                    case .fonts: fonts
                    case .code: code
                    case .background: background
                    case .themes: themes
                    case .logs: logs
                    }
                }
                .buttonStyle(WorkspaceActionStyle())
                .frame(width: railWidth, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, railLeading)
                .padding(.top, 30)
                .padding(.bottom, 132)
            }
            .id(tab)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 8)))
            .background(quiet)
                HStack(spacing: 0) {
                    applyBar.frame(width: railWidth)
                    Spacer(minLength: 0)
                }
                .padding(.leading, railLeading)
                .padding(.bottom, 16)
            }
            .background(quiet)
            .animation(motion, value: tab)
            }
        }
        .frame(minWidth: 1040, minHeight: 640)
        .tint(accent)
        .focusEffectDisabled()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack(spacing: 12) {
                    WorkspaceDropdown<WorkspaceCommand?>(title: l("更多操作", "More actions"),
                        selection: Binding(get: { nil }, set: { command in
                            switch command {
                            case .doctor: model.doctor(); tab = .logs
                            case .open: model.openTarget()
                            case .restore: showRestoreConfirm = true
                            case .help: showHelp = true
                            case .about: openWindow(id: "about")
                            case nil: break
                            }
                        }), options: [
                            WorkspaceOption(value: .doctor, title: t("action.doctor")),
                            WorkspaceOption(value: .open, title: t("action.open")),
                            WorkspaceOption(value: .restore, title: t("action.restore"),
                                enabled: !model.busy && model.exists(model.target), destructive: true),
                            WorkspaceOption(value: .help, title: t("help.title")),
                            WorkspaceOption(value: .about, title: t("about.title"))
                        ], symbol: "ellipsis").frame(width: 62).id("workspace-actions").accessibilityLabel(l("更多操作", "More actions"))

                    WorkspaceDropdown(title: l("界面语言", "Interface language"), selection: $copy.lang,
                        options: Lang.allCases.map { WorkspaceOption(value: $0, title: languageTitle($0)) },
                        symbol: "character.bubble").frame(width: 62).id("workspace-language").accessibilityLabel(l("界面语言", "Interface language"))
                }
                .frame(width: 136, height: 38)
                .accessibilityElement(children: .contain)
            }.sharedBackgroundVisibility(.hidden)
        }
        .onAppear {
            model.loadFonts()
            model.loadConfig()
            model.loadThemes()
            model.refreshAll()
            updates.checkIfDue()
        }
        .onChange(of: model.appMgmtDenied) { _, denied in
            if denied { tab = .overview }
        }
        .onChange(of: model.target) { _, _ in
            permissionGranted = nil
            model.appMgmtDenied = false
        }
        .alert(l("应用到正式 Claude？", "Apply to the main Claude?"), isPresented: $showApplyConfirm) {
            Button(t("sheet.cancel"), role: .cancel) {}
            Button(t("sheet.apply.go")) { runApply() }
        } message: {
            Text(l("将先备份，再修改并重新签名。失败时自动恢复。", "Claude is backed up before changes and restored automatically if the process fails."))
        }
        .alert(l("请先退出 Claude", "Quit Claude first"), isPresented: $showNeedsQuit) {
            Button(l("知道了", "OK"), role: .cancel) {}
        } message: {
            Text(l("从 Claude 菜单选择“退出 Claude”，再点击“应用设置”。只关闭窗口不会退出应用。", "Choose Quit Claude from the Claude menu, then apply settings again. Closing the window does not quit the app."))
        }
        .alert(t("sheet.restore.title"), isPresented: $showRestoreConfirm) {
            Button(t("sheet.cancel"), role: .cancel) {}
            Button(t("action.restore"), role: .destructive) { model.uninstall(); tab = .logs }
        } message: { Text(t("sheet.restore.body", ["{target}": model.target.label])) }
        .alert(t("sheet.create.title"), isPresented: $showTestConfirm) {
            Button(t("sheet.cancel"), role: .cancel) {}
            Button(model.exists(.testCopy) ? t("target.rebuild") : t("target.create")) {
                model.rebuildTestCopy(); tab = .logs
            }
        } message: { Text(t("sheet.create.body")) }
        .alert(t("sheet.delete.title"), isPresented: $showRemoveConfirm) {
            Button(t("sheet.cancel"), role: .cancel) {}
            Button(t("sheet.delete.ok"), role: .destructive) {
                model.target = .production
                model.removeTestCopy(); tab = .logs
            }
        } message: { Text(t("sheet.delete.body")) }
        .alert(t("sheet.restart.title"), isPresented: $showSuccess) {
            Button(t("sheet.ok")) {}
        } message: { Text(t("sheet.restart.body")) }
        .sheet(item: $themeDraft) { draft in WorkspaceThemeNameSheet(model: model, draft: draft, lang: lang) }
        .alert(l("删除主题？", "Delete theme?"), isPresented: Binding(get: { deleteTheme != nil }, set: { if !$0 { deleteTheme = nil } })) {
            Button(t("sheet.cancel"), role: .cancel) { deleteTheme = nil }
            Button(l("删除", "Delete"), role: .destructive) {
                if let theme = deleteTheme { model.deleteTheme(theme) }; deleteTheme = nil
            }
        } message: { Text(deleteTheme?.name ?? "") }
        .sheet(isPresented: $showApplying) { applyingSheet }
        .sheet(isPresented: $showHelp) { helpSheet }
    }

    private var heading: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(tab.title(lang))
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(ink)
                Text(subtitle)
                    .font(.system(size: 14)).foregroundStyle(.secondary)
            }
            Spacer()
            if tab != .overview {
                WorkspaceDropdown(title: l("目标", "Target"), selection: Binding(
                    get: { model.target },
                    set: { model.target = $0; model.refresh($0) }
                ), options: availableTargets.map { WorkspaceOption(value: $0, title: $0.label) })
                .frame(width: 180)
            }
        }
    }

    private var subtitle: String {
        switch tab {
        case .overview: l("先选目标，再调整显示效果。", "Choose an app, then shape how it looks.")
        case .fonts: l("正文、标题与界面字体，各自清楚可控。", "Tune text, titles and interface type.")
        case .code: l("代码使用自己的字形与比例。", "Give code its own type and scale.")
        case .background: l("浅色与深色，保持整套配色协调。", "Coordinate light and dark appearances.")
        case .themes: l("保存喜欢的组合，在不同工作场景间切换。", "Save your favorite styles and switch between workflows.")
        case .logs: l("查看当前状态与本次运行记录。", "Review status and the current session.")
        }
    }

    private var availableTargets: [Target] {
        model.customAppPath.isEmpty ? [.production, .testCopy] : [.production, .testCopy, .custom]
    }

    private func languageTitle(_ choice: Lang) -> String {
        switch choice {
        case .auto: t("about.lang.auto")
        case .zh: "简体中文"
        case .en: "English"
        }
    }

    private var applyBar: some View {
        HStack(spacing: 16) {
            Image(systemName: model.hasUnapplied ? "circle.dotted" :
                    model.current.patched ? "checkmark" : "square.dashed")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 42, height: 42)
                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.hasUnapplied ? l("有设置尚未应用", "Changes are ready to apply") :
                        l("当前目标", "Current target"))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(model.hasUnapplied ? accent : .secondary)
                Text(model.target.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(ink)
            }
            Spacer()
            Button { beginApply() } label: {
                Label(l("应用设置", "Apply changes"), systemImage: "arrow.down.to.line.compact")
                    .frame(minWidth: 130)
            }
            .buttonStyle(WorkspaceActionStyle(prominent: true))
            .help(t(model.current.patched ? "action.reapply" : "action.apply",
                    ["{target}": model.target.label]))
            .disabled(model.busy || !model.exists(model.target) || !model.appearanceValid || (!model.current.canApply && !model.hasUnsavedChanges))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(surface)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(ink.opacity(0.08), lineWidth: 1)
        }
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.24 : 0.10), radius: 20, y: 8)
        .animation(motion, value: model.hasUnapplied)
    }

    // MARK: Overview

    private var permissionCard: some View {
        HStack(alignment: .center, spacing: 14) {
            Image(systemName: model.appMgmtDenied ? "lock.shield" :
                    permissionGranted == true ? "checkmark.shield" : "shield")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(model.appMgmtDenied ? .red : accent)
                .frame(width: 24, height: 28, alignment: .center)
            VStack(alignment: .leading, spacing: 5) {
                Text(model.appMgmtDenied ? l("需要 App 管理权限", "App Management access required") :
                        l("App 管理权限", "App Management access"))
                    .font(.system(size: 14, weight: .semibold))
                Text(model.appMgmtDenied ? t("appmgmt.body") :
                        permissionGranted == true ? l("已获得权限，可以应用设置。", "Access is available. You can apply changes.") :
                        permissionGranted == false ? l("未能确认权限，请查看日志。", "Could not confirm access. Check the log.") :
                        l("权限由 macOS 保存。点击“检测权限”确认当前是否允许修改 Claude；首次检测可能需要授权。",
                          "macOS saves your permission. Choose Check access to verify it; the first check may ask for approval."))
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if model.appMgmtDenied {
                    Button(t("appmgmt.recheck")) {
                        model.doctor { permissionGranted = $0 }
                    }
                    .buttonStyle(.link)
                    .disabled(model.busy)
                }
            }
            Spacer(minLength: 12)
            if model.appMgmtDenied {
                Button(t("appmgmt.open")) { openAppManagementSettings() }
                    .buttonStyle(WorkspaceActionStyle(prominent: true))
            } else {
                Button(permissionGranted == true ? l("重新检测", "Check again") : l("检测权限", "Check access")) {
                    model.doctor { permissionGranted = $0 }
                }
                .buttonStyle(WorkspaceActionStyle())
                .disabled(model.busy || !model.exists(model.target) || !model.appearanceValid)
            }
        }
        .padding(18)
        .background(model.appMgmtDenied ? Color.red.opacity(0.09) : surface,
                    in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(ink.opacity(0.04)))
    }

    private func openAppManagementSettings() {
        guard let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AppBundles") else { return }
        NSWorkspace.shared.open(url)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 26) {
            permissionCard
            if model.current.state == "unsupported" && !model.current.reason.isEmpty {
                alertStrip("exclamationmark.triangle", l("当前目标无法应用", "Cannot apply to this target"), targetReason, color: accent)
                if model.current.reason.hasPrefix("Existing foreign font patch:") {
                    Button(l("接续已有修改", "Continue previous changes")) { model.migratePrevious() }
                        .disabled(model.busy)
                }
            } else if model.current.state == "previous" {
                alertStrip("arrow.triangle.branch", l("已接续旧版修改", "Previous changes connected"),
                           l("已导入字体、配色和主题，当前 Claude 保持原样。点击“应用设置”后转为本版管理。", "Fonts, colors and themes are imported. Claude retains its previous changes until you choose Apply changes."), color: accent)
            } else if model.current.stale {
                alertStrip("arrow.clockwise", t("stale.title"), t("stale.body"), color: accent)
            }
            if !model.current.helperOK {
                alertStrip("exclamationmark.triangle", t("helper.title"), t("helper.body"), color: .red)
            }
            if let release = updates.available {
                alertStrip("arrow.down.circle", t("update.title", ["{tag}": release.tag]),
                           t("update.body"), color: accent)
                HStack(spacing: 14) {
                    Button(t("update.download")) { NSWorkspace.shared.open(release.page) }
                    Button(t("update.later")) { updates.skip() }
                }
            }
            overviewHero
            compatibilityPanel
            VStack(alignment: .leading, spacing: 13) {
                sectionTitle(l("选择目标", "Choose an app"), symbol: "macwindow")
                HStack(spacing: 12) {
                    targetButton(.production)
                    targetButton(.testCopy)
                }
                HStack(spacing: 16) {
                    Button(model.exists(.testCopy) ? t("target.rebuild") : t("target.create")) {
                        showTestConfirm = true
                    }
                    if model.exists(.testCopy) {
                        Button(t("target.delete"), role: .destructive) { showRemoveConfirm = true }
                    }
                    Spacer()
                    Button(t("target.choose")) { chooseCustomApp() }
                }
                .buttonStyle(.link)
                .font(.system(size: 12))
                .disabled(model.busy)
                if !model.customAppPath.isEmpty {
                    targetButton(.custom)
                    Button(t("target.forget")) {
                        if model.target == .custom { model.target = .production }
                        model.customAppPath = ""
                    }
                    .buttonStyle(.link)
                    .font(.system(size: 12))
                }
            }
            HStack(spacing: 15) {
                launchCard(.fonts, number: "01", headline: l("设置字体", "Type"),
                           detail: l("中英文字体和字号", "Fonts and scale"))
                launchCard(.code, number: "02", headline: l("整理代码", "Code"),
                           detail: l("清晰的等宽字形", "Monospace type"))
                launchCard(.background, number: "03", headline: l("选择配色", "Colors"),
                           detail: l("轻浅的阅读底色", "Reading surfaces"))
            }
        }
    }

    private var overviewHero: some View {
        HStack(alignment: .center, spacing: 22) {
            Image(systemName: model.current.patched ? "checkmark.seal.fill" : "circle.dotted")
                .font(.system(size: 33, weight: .light))
                .foregroundStyle(model.current.patched ? accent : .secondary)
                .frame(width: 58, height: 58)
                .background(accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 24))
            VStack(alignment: .leading, spacing: 8) {
                Text(statusTitle)
                    .font(.system(size: 23, weight: .semibold))
                    .foregroundStyle(ink)
                Text(model.target.label + "  ·  " + model.current.version)
                    .font(.system(size: 13)).foregroundStyle(.secondary)
                Text(model.current.font.isEmpty ? l("尚无已应用字体", "No applied typeface") : model.current.font)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent)
            }
            Spacer()
        }
        .padding(27)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 32)
                .fill(surface)
        }
    }

    private var statusTitle: String {
        let s = model.current
        if s.missing { return t("status.missing") }
        if !s.loaded { return t("status.loading") }
        if s.state == "unsupported" { return l("目标暂不支持", "Target unsupported") }
        if s.state == "unavailable" { return l("状态无法读取", "Status unavailable") }
        if s.state == "previous" { return l("已接续旧版修改", "Previous changes connected") }
        if s.stale { return t("status.stale") }
        return t(s.patched ? "status.applied" : "status.none")
    }

    private func targetButton(_ target: Target) -> some View {
        let selected = model.target == target
        return Button { model.target = target; model.refresh(target) } label: {
            HStack(spacing: 12) {
                Image(systemName: target == .testCopy ? "square.on.square" : "macwindow")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(selected ? accent : ink)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 3) {
                    Text(target.label).font(.system(size: 14, weight: .semibold))
                    Text(model.exists(target) ? model.displayPath(target) : t("target.none"))
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 2)
                Image(systemName: "checkmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(accent).opacity(selected ? 1 : 0).frame(width: 18)
            }
            .padding(.horizontal, 17).frame(maxWidth: .infinity).frame(height: 74)
            .contentShape(RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .background(selected ? accent.opacity(0.10) : surface,
                    in: RoundedRectangle(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18)
                .strokeBorder(selected ? accent.opacity(0.45) : ink.opacity(0.08), lineWidth: 1)
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
        .animation(motion, value: selected)
        .disabled(model.busy)
    }

    private func launchCard(_ destination: WorkspaceTab, number: String,
                            headline: String, detail: String) -> some View {
        Button { tab = destination } label: {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: destination.symbol).font(.system(size: 18, weight: .medium))
                    .foregroundStyle(accent)
                Spacer()
                Text(headline).font(.system(size: 18, weight: .semibold)).foregroundStyle(ink)
                Text(detail).font(.system(size: 12)).foregroundStyle(.secondary)
                HStack { Spacer(); Image(systemName: "arrow.up.right").foregroundStyle(accent) }
            }
            .padding(20).frame(maxWidth: .infinity, minHeight: 136, alignment: .leading)
            .background(surface, in: RoundedRectangle(cornerRadius: 28))
        }
        .buttonStyle(.plain).focusEffectDisabled()
    }

    // MARK: Fonts

    private var fonts: some View {
        VStack(alignment: .leading, spacing: 24) {
            typeSpecimen
            readingPreview
            typographyPanel
            HStack {
                Text(l("需要一个起点？", "Need a starting point?"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Button(l("使用经典主题", "Use Classic theme")) { chooseClassicPreset() }
            .buttonStyle(WorkspaceActionStyle())
                Spacer()
            }
            sectionTitle(l("替换范围", "Replacement scope"), symbol: "textformat")
            panel {
                settingsRow(l("语言", "Languages"), subtitle: t("font.scope.desc")) {
                    WorkspaceDropdown(title: l("替换语言", "Replacement languages"), selection: $model.scope,
                        options: [WorkspaceOption(value: "cjk", title: t("font.scope.cjk")),
                                  WorkspaceOption(value: "latin", title: t("font.scope.latin")),
                                  WorkspaceOption(value: "both", title: t("font.scope.both"))]).frame(width: 220)
                }
                if model.replacesLatin {
                    Divider()
                    settingsRow(l("英文覆盖位置", "English coverage"), subtitle: t("font.latin.where.desc")) {
                        WorkspaceDropdown(title: l("英文覆盖位置", "English coverage"), selection: $model.latinScope,
                            options: [WorkspaceOption(value: "body", title: t("font.latin.body")),
                                      WorkspaceOption(value: "all", title: t("font.latin.all"))]).frame(width: 220)
                    }
                }
            }
            if model.replacesCJK {
                sectionTitle(l("中文字体设置", "Chinese font settings"), symbol: "character")
                panel {
                    settingsRow(t("font.cjk")) { fontPicker($model.fontFamily, model.fonts, title: t("font.cjk")) }
                    Divider()
                    sizeRow(t("font.cjk.size"), $model.fontScale)
                }
            }
            if model.replacesLatin {
                sectionTitle(l("英文字体设置", "English font settings"), symbol: "textformat.abc")
                panel {
                    settingsRow(t("font.latin")) { fontPicker($model.fontLatin, model.latinFonts, title: t("font.latin")) }
                    Divider()
                    sizeRow(t("font.latin.size"), $model.fontScaleLatin)
                }
            }
            if model.replacesCJK || model.uiScaleApplies {
                sectionTitle(l("界面字号", "Interface scale"), symbol: "sidebar.left")
                panel { sizeRow(t("font.ui.size"), $model.fontScaleUI) }
            }
            panel {
                settingsRow(t("font.mode"), subtitle: t("font.mode.desc")) {
                    WorkspaceDropdown(title: t("font.mode"), selection: $model.mode,
                        options: [WorkspaceOption(value: "auto", title: t("font.mode.std")),
                                  WorkspaceOption(value: "brute", title: t("font.mode.ext"))]).frame(width: 220)
                }
            }
        }
        .disabled(model.busy)
    }

    private var typeSpecimen: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 20) {
                Text(l("中文预览", "Chinese preview"))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Text(t("font.preview.cjk"))
                    .font(.custom(model.replacesCJK ? model.fontFamily : "PingFang SC",
                                  size: 32 * (model.replacesCJK ? model.fontScale : 100) / 100))
                    .foregroundStyle(ink).lineLimit(2).minimumScaleFactor(0.65)
                Text(model.replacesCJK ? model.fontFamily : l("默认字体", "Default font"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .padding(26).frame(maxWidth: .infinity, alignment: .leading).frame(height: 194)
            .background(surface, in: RoundedRectangle(cornerRadius: 32))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.035), radius: 12, y: 4)
            VStack(alignment: .leading, spacing: 18) {
                Text(l("英文预览", "English preview"))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
                Text("Aa Bb Cc\n0123456789")
                    .font(.custom(model.replacesLatin ? model.fontLatin : "Helvetica Neue",
                                  size: 23 * (model.replacesLatin ? model.fontScaleLatin : 100) / 100))
                    .foregroundStyle(ink).lineLimit(2).minimumScaleFactor(0.6)
            }
            .padding(26).frame(width: 240, alignment: .leading).frame(height: 194)
            .background(accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 32))
        }
        .animation(motion, value: model.fontScale)
        .animation(motion, value: model.fontScaleLatin)
    }

    // MARK: Code

    @State private var selectedCodeRegion: CodeRegion = .reply

    private func regionFont(_ region: CodeRegion) -> Binding<String> {
        Binding(get: { model.codeSettings[region]?.font ?? "" },
                set: { selectedCodeRegion = region; model.codeSettings[region, default: CodeRegionSetting()].font = $0 })
    }

    private func regionScale(_ region: CodeRegion) -> Binding<Double> {
        Binding(get: { model.codeSettings[region]?.scale ?? 100 },
                set: { selectedCodeRegion = region; model.codeSettings[region, default: CodeRegionSetting()].scale = $0 })
    }

    private var code: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(spacing: 4) {
                ForEach(CodeRegion.allCases) { region in
                    Button { withAnimation(motion) { selectedCodeRegion = region } } label: {
                        Text(region.title).font(.system(size: 13, weight: .medium))
                            .lineLimit(1).minimumScaleFactor(0.75)
                            .foregroundStyle(selectedCodeRegion == region ? accent : .secondary)
                            .padding(.horizontal, 12).frame(maxWidth: .infinity).frame(height: 38)
                            .background {
                                if selectedCodeRegion == region {
                                    RoundedRectangle(cornerRadius: 12).fill(surface)
                                        .matchedGeometryEffect(id: "region-selection", in: previewSelection)
                                }
                            }
                            .contentShape(RoundedRectangle(cornerRadius: 12))
                    }.buttonStyle(.plain).focusEffectDisabled()
                        .accessibilityAddTraits(selectedCodeRegion == region ? .isSelected : [])
                }
            }
            .padding(5).background(ink.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
            .animation(motion, value: selectedCodeRegion)
            codeRegionPreview
            sectionTitle(l("通用代码设置", "Shared code settings"), symbol: "curlybraces")
            panel {
                settingsRow(t("code.font"), subtitle: t("code.desc")) {
                    WorkspaceDropdown(title: t("code.font"), selection: $model.fontMono,
                        options: fontOptions(model.monoFonts, selected: model.fontMono, emptyTitle: t("code.keep")),
                        searchable: true).frame(width: 220)
                }
                if !model.fontMono.isEmpty {
                    Divider()
                    sizeRow(t("code.size"), $model.fontMonoScale)
                }
            }
            sectionTitle(l("代码排版", "Code typography"), symbol: "text.alignleft")
            panel {
                layoutRow(l("代码行距", "Code line height"), key: "code_line_height", range: 1.2...2.4, step: 0.1, unit: "×")
                Divider()
                settingsRow(l("代码连字", "Code ligatures"), subtitle: l("仅改变字体支持的组合字形，不改代码内容。", "Uses combined glyphs when the selected font supports them.")) {
                    WorkspaceDropdown(title: l("代码连字", "Code ligatures"), selection: appearanceString("code_ligatures"), options: [
                        WorkspaceOption(value: "default", title: l("跟随原样", "Keep original")),
                        WorkspaceOption(value: "on", title: l("开启", "On")), WorkspaceOption(value: "off", title: l("关闭", "Off"))]).frame(width: 220)
                }
            }
            sectionTitle(l("各区域独立设置", "Region overrides"), symbol: "slider.horizontal.3")
            Text(l("留空时跟随现有字体；100% 保持区域原来的字号。预览为示例内容。",
                   "Follow existing fonts or override each region. 100% keeps its original size. Previews use sample content."))
                .font(.callout).foregroundStyle(.secondary)
            ForEach(CodeRegion.allCases) { region in
                panel {
                    settingsRow(region.title) {
                        let choices = region == .reply ? model.fonts + model.latinFonts : model.monoFonts
                        WorkspaceDropdown(title: region.title, selection: regionFont(region),
                            options: fontOptions(choices, selected: regionFont(region).wrappedValue,
                                emptyTitle: l("跟随现有字体", "Follow existing font")),
                            searchable: true).frame(width: 220)
                    }
                    Divider()
                    sizeRow(l("字号", "Size"), regionScale(region))
                }
            }
            Text(l("预览为示例内容，各区域的实际效果需在所选 Claude 中核验。终端设置仅在资源结构匹配时适配；无法识别会中止应用。",
                   "These are sample previews. Verify each region in the selected Claude app. Terminal settings require a recognized resource structure; unsupported structures stop the apply operation."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .disabled(model.busy)
    }

    private var codeRegionPreview: some View {
        let region = selectedCodeRegion
        let setting = model.codeSettings[region] ?? CodeRegionSetting()
        let fallback = region == .reply ? model.fontFamily : (model.fontMono.isEmpty ? "Menlo" : model.fontMono)
        let font = setting.font.isEmpty ? fallback : setting.font
        let baseScale = setting.font.isEmpty ? (region == .reply ? model.fontScale : (model.fontMono.isEmpty ? 100 : model.fontMonoScale)) : 100
        let size = 16 * baseScale / 100 * setting.scale / 100
        return HStack(alignment: .center, spacing: 22) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: region == .terminal ? "terminal" : "curlybraces")
                    Text(previewFile(region)).lineLimit(1)
                    Spacer(minLength: 8)
                    Text(l("预览", "Preview")).foregroundStyle(Color(hex: 0x9D9992))
                }
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(hex: 0xCAC6BF))
                .padding(.horizontal, 16).frame(height: 36)
                .background(Color.white.opacity(0.035))
                Rectangle().fill(Color.white.opacity(0.08)).frame(height: 1)
                ScrollView(.horizontal) {
                    previewContent(region, font: font, size: size)
                        .padding(16).frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                }
                .scrollIndicators(.hidden)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(themeColor(StyleSchema.palette(model.appearance)?["code"] ?? "#252525"), in: RoundedRectangle(cornerRadius: 18))
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Color.white.opacity(0.07)))
            .id(region)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 5)))
            VStack(alignment: .center, spacing: 8) {
                Text(region.title).font(.system(size: 12, weight: .semibold))
                    .multilineTextAlignment(.center).lineLimit(2)
                    .frame(maxWidth: .infinity)
                Text("\(Int(setting.scale))%")
                    .font(.system(size: 25, weight: .medium, design: .rounded)).monospacedDigit()
            }
            .foregroundStyle(accent).padding(16).frame(width: 124, height: 104)
            .background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 20))
        }
        .padding(24)
        .background(surface, in: RoundedRectangle(cornerRadius: 32))
        .shadow(color: .black.opacity(colorScheme == .dark ? 0.1 : 0.035), radius: 12, y: 4)
        .animation(motion, value: selectedCodeRegion)
        .animation(motion, value: setting.scale)
        .animation(motion, value: appearanceNumber("code_line_height").wrappedValue)
    }

    private func previewFile(_ region: CodeRegion) -> String {
        switch region {
        case .reply: return "Claude · " + region.title
        case .block: return "swift"
        case .diff: return "greeting.swift · diff"
        case .editor: return "greeting.swift"
        case .terminal: return "zsh"
        }
    }

    private func previewContent(_ region: CodeRegion, font: String, size: Double) -> some View {
        let lines = region.sample.components(separatedBy: "\n")
        let factor = appearanceNumber("code_line_height").wrappedValue
        let spacing = region == .reply ? max(8, (appearanceNumber("body_line_height").wrappedValue - 1) * size) : factor == 0 ? 8 : max(0, (factor - 1.2) * size)
        return VStack(alignment: .leading, spacing: spacing) {
            ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                HStack(alignment: .firstTextBaseline, spacing: 14) {
                    if region == .editor {
                        Text(String(index + 1)).foregroundStyle(Color(hex: 0x77736D))
                            .font(.system(size: size, design: .monospaced)).frame(width: 22, alignment: .trailing)
                    }
                    Text(previewText(region == .editor ? String(line.dropFirst(4)) : line, region: region))
                        .font(.custom(font, size: size)).textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                }
                .padding(.horizontal, region == .diff ? 8 : 0)
                .padding(.vertical, region == .diff ? 5 : 0)
                .background(region == .diff ? (StyleSchema.palette(model.appearance).map { themeColor($0[line.hasPrefix("+") ? "added" : "removed"]!) } ?? (line.hasPrefix("+") ? Color.green.opacity(0.12) : Color.red.opacity(0.12))) : Color.clear,
                            in: RoundedRectangle(cornerRadius: 6))
            }
            if region == .block || region == .editor {
                WorkspaceLigatureSample(fontName: font, size: size, ligatures: appearanceString("code_ligatures").wrappedValue,
                    color: NSColor(themeColor(StyleSchema.palette(model.appearance)?["text"] ?? "#E6E2DA")))
                    .frame(height: size * (factor == 0 ? 1.6 : factor))
            }
        }
    }

    private func previewText(_ line: String, region: CodeRegion) -> AttributedString {
        var text = AttributedString(line)
        text.foregroundColor = themeColor(StyleSchema.palette(model.appearance)?["text"] ?? "#E6E2DA")
        if region == .diff {
            text.foregroundColor = StyleSchema.palette(model.appearance).map { themeColor($0["text"]!) } ?? Color(hex: line.hasPrefix("+") ? 0xB7D7A8 : 0xE0A7A0)
        } else if region == .terminal {
            text.foregroundColor = Color(hex: line.hasPrefix("$") ? 0xB7D7A8 : 0xB5B1A9)
        } else if region == .block || region == .editor {
            for keyword in ["let", "func", "print"] {
                if let range = text.range(of: keyword) { text[range].foregroundColor = Color(hex: 0xDCA6BA) }
            }
            if let range = text.range(of: "\"Hello, 字体\"") { text[range].foregroundColor = Color(hex: 0xD9C497) }
        }
        return text
    }

    // MARK: Background

    private var background: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                sectionTitle(l("配色预览", "Color preview"), symbol: "circle.lefthalf.filled")
                Spacer()
                WorkspaceDropdown(title: l("预览模式", "Preview appearance"), selection: $previewDark,
                    options: [WorkspaceOption(value: false, title: l("浅色", "Light")), WorkspaceOption(value: true, title: l("深色", "Dark"))]).frame(width: 140)
            }
            backgroundPreview
            if !model.appearanceValid {
                alertStrip("exclamationmark.triangle", l("配色对比度不足", "Color contrast too low"),
                    l("正文和链接需要足够清晰。请调整色块后再应用。", "Adjust the swatches so text and links are readable before applying."), color: .red)
            }
            if !model.bgColor.isEmpty && !bgReadable(model.bgColor) {
                alertStrip("exclamationmark.triangle", l("底色过深", "Background too dark"),
                           t("look.bg.toodark"), color: .red)
            }
            HStack {
                sectionTitle(l("选择浅色底色", "Light backgrounds"), symbol: "paintpalette")
                Spacer()
                Text(l("仅在浅色模式生效", "Light mode only"))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                backgroundChoice("", t("look.bg.off"), fallback: 0xF7F5F2)
                backgroundChoice("#F0EEE6", t("look.bg.classic"), fallback: 0xF0EEE6)
                backgroundChoice("#F7F4EC", t("look.bg.light"), fallback: 0xF7F4EC)
                backgroundChoice("#F2F1EC", t("look.bg.grey"), fallback: 0xF2F1EC)
                backgroundChoice("#E9F1F7", t("look.bg.blue"), fallback: 0xE9F1F7)
                customBackgroundChoice
            }
            if colorScheme == .dark {
                Text(t("look.bg.darknow"))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
            }
            Text(t("look.bg.desc"))
                .font(.system(size: 12)).foregroundStyle(.secondary)
            darkThemePanel
        }
        .disabled(model.busy)
    }

    private var backgroundPreview: some View {
        let palette = StyleSchema.palette(model.appearance) ?? StyleSchema.palette(["dark_theme": "graphite"])!
        let color = previewDark ? themeColor(palette["bg"]!) : Color(hex: UInt32(model.bgColor.dropFirst(), radix: 16) ?? 0xF7F5F2)
        let textColor = previewDark ? themeColor(palette["text"]!) : Color(hex: 0x252B32)
        return HStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "line.3.horizontal.decrease")
                Rectangle().fill(.primary.opacity(0.09)).frame(height: 7)
                Rectangle().fill(.primary.opacity(0.09)).frame(width: 75, height: 7)
                Spacer()
                Image(systemName: "plus")
            }
            .frame(width: 114, height: 225)
            .padding(19)
            .background(.black.opacity(0.035))
            VStack(alignment: .leading, spacing: 14) {
                Text(l("预览", "Preview"))
                    .font(.system(size: 11, weight: .semibold)).foregroundStyle(.secondary)
                Spacer()
                Text(l("在文字之间，留一点呼吸感。", "Give every word a little room to breathe."))
                    .font(.system(size: 21, weight: .medium, design: .serif))
                    .foregroundStyle(textColor)
                Text(l("预览跟随当前选择，点击“应用设置”后生效。", "Preview reflects your choices. Apply settings to use them in Claude."))
                    .font(.system(size: 12)).foregroundStyle(.secondary)
                Spacer()
                HStack(spacing: 12) {
                    Text("let readable = true").font(.system(size: 12, design: .monospaced))
                    Spacer()
                    Text("+ 1").padding(5).background(previewDark ? themeColor(palette["added"]!) : .green.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                    Text("− 1").padding(5).background(previewDark ? themeColor(palette["removed"]!) : .red.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                }
                .padding(10).foregroundStyle(textColor)
                .background(previewDark ? themeColor(palette["code"]!) : .white.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
                Text(l("链接示例", "Example link")).font(.system(size: 12))
                    .foregroundStyle(previewDark ? themeColor(palette["link"]!) : accent)
            }
            .padding(24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color, in: RoundedRectangle(cornerRadius: 32))
        .clipShape(RoundedRectangle(cornerRadius: 32))
        .foregroundStyle(textColor)
        .environment(\.colorScheme, previewDark ? .dark : .light)
        .animation(motion, value: model.bgColor)
        .animation(motion, value: previewDark)
        .animation(motion, value: appearanceString("dark_theme").wrappedValue)
    }

    private func backgroundChoice(_ value: String, _ label: String, fallback: UInt32) -> some View {
        let selected = model.bgColor.uppercased() == value.uppercased()
        return Button { model.bgColor = value } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10).fill(Color(hex: fallback))
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.08)))
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").foregroundStyle(accent) }
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 95)
            .background(selected ? accent.opacity(0.10) : surface,
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(selected ? accent.opacity(0.45) : ink.opacity(0.06), lineWidth: 1)
            }
        }
        .buttonStyle(.plain).focusEffectDisabled()
    }

    private var customBackgroundChoice: some View {
        let presetColors = ["", "#F0EEE6", "#F7F4EC", "#F2F1EC", "#E9F1F7"]
        let selected = !presetColors.contains(where: { $0.caseInsensitiveCompare(model.bgColor) == .orderedSame })
        let customColor = Color(hex: UInt32(model.bgColor.dropFirst(), radix: 16) ?? 0xF0EEE6)
        return Button {
            backgroundPicker.open(Binding(
                get: { Color(hex: UInt32(model.bgColor.dropFirst(), radix: 16) ?? 0xF0EEE6) },
                set: { model.bgColor = $0.hexString }
            ))
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(customColor)
                    .frame(width: 38, height: 38)
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(.black.opacity(0.08)))
                Text(t("look.bg.custom")).font(.system(size: 13, weight: .medium))
                Spacer(minLength: 0)
                if selected { Image(systemName: "checkmark").foregroundStyle(accent) }
            }
            .padding(14).frame(maxWidth: .infinity, minHeight: 95)
            .background(selected ? accent.opacity(0.10) : surface,
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay {
                RoundedRectangle(cornerRadius: 24)
                    .strokeBorder(selected ? accent.opacity(0.45) : ink.opacity(0.06), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain).focusEffectDisabled()
        .accessibilityAddTraits(selected ? .isSelected : [])
        .help(l("点击选择自定颜色", "Choose a custom background color"))
    }

    // MARK: Reading and appearance

    private func appearanceString(_ key: String) -> Binding<String> {
        Binding(get: { model.appearance[key] as? String ?? "" }, set: { model.appearance[key] = $0 })
    }
    private func appearanceNumber(_ key: String) -> Binding<Double> {
        Binding(get: { StyleSchema.number(model.appearance, key) }, set: { model.appearance[key] = $0 })
    }
    private func themeColor(_ hex: String) -> Color { Color(hex: UInt32(hex.dropFirst(), radix: 16) ?? 0) }

    private func layoutRow(_ title: String, key: String, range: ClosedRange<Double>, step: Double, unit: String) -> some View {
        let value = appearanceNumber(key)
        return settingsRow(title) {
            WorkspaceScaleSlider(value: value, range: range, step: step)
                .frame(width: 170, height: 28).accessibilityLabel(title)
            Text(value.wrappedValue == 0 ? l("原样", "Original") : StyleSchema.cssNumber(value.wrappedValue) + unit)
                .font(.system(size: 12, design: .monospaced)).monospacedDigit().frame(width: 70, alignment: .trailing)
            Button { value.wrappedValue = 0 } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.plain).focusEffectDisabled().disabled(value.wrappedValue == 0)
                .help(l("恢复原样", "Keep original")).accessibilityLabel(title + l("恢复原样", " reset"))
        }
    }
    private var typographyPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(l("阅读排版", "Reading typography"), symbol: "text.alignleft")
            panel {
                layoutRow(l("正文行距", "Body line height"), key: "body_line_height", range: 1.2...2.4, step: 0.1, unit: "×")
                Divider()
                layoutRow(l("段落间距", "Paragraph spacing"), key: "paragraph_spacing", range: 4...40, step: 2, unit: " px")
                Divider()
                layoutRow(l("阅读宽度", "Reading width"), key: "reading_width", range: 480...1100, step: 20, unit: " px")
            }
            Text(l("恢复原样时沿用 Claude 的排版。窄窗口会自动收窄阅读宽度。", "Original keeps Claude’s typography. Reading width adapts to narrower windows."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private var readingPreview: some View {
        let size = 16 * (model.replacesCJK ? model.fontScale : 100) / 100
        let line = appearanceNumber("body_line_height").wrappedValue
        let gap = appearanceNumber("paragraph_spacing").wrappedValue
        let width = appearanceNumber("reading_width").wrappedValue
        return VStack(alignment: .leading, spacing: 14) {
            Text(l("阅读预览", "Reading preview")).font(.system(size: 11, weight: .semibold)).foregroundStyle(accent)
            VStack(alignment: .leading, spacing: gap == 0 ? 12 : gap) {
                Text(l("先理解问题，再让每一步清晰可读。长篇解释需要舒适的行距，也需要适当的阅读宽度。", "Understand the problem, then make each step clear. Longer explanations benefit from comfortable line height and a considered reading width."))
                Text(l("这里可以预览段落之间的留白。代码保留自己的字形，正文也有自己的节奏。", "Preview the space between paragraphs. Code keeps its own type, while the body has its own rhythm."))
            }
            .font(.custom(model.replacesCJK ? model.fontFamily : "Helvetica Neue", size: size))
            .lineSpacing(line == 0 ? 4 : max(0, (line - 1.2) * size))
            .frame(maxWidth: width == 0 ? .infinity : width, alignment: .leading)
            .textSelection(.enabled)
        }
        .padding(26).frame(maxWidth: .infinity, alignment: .leading)
        .background(surface, in: RoundedRectangle(cornerRadius: 32))
        .animation(motion, value: model.settingsSnapshot)
    }
    private var darkThemePanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionTitle(l("深色主题", "Dark themes"), symbol: "moon")
            panel {
                settingsRow(l("深色配色", "Dark palette"), subtitle: l("仅在 Claude 深色模式生效。", "Applies when Claude uses dark appearance.")) {
                    WorkspaceDropdown(title: l("深色配色", "Dark palette"), selection: Binding(
                        get: { appearanceString("dark_theme").wrappedValue },
                        set: { value in withAnimation(motion) { model.appearance["dark_theme"] = value; previewDark = true } }), options: [
                            WorkspaceOption(value: "default", title: l("跟随原样", "Keep original")),
                            WorkspaceOption(value: "graphite", title: l("石墨灰", "Graphite")),
                            WorkspaceOption(value: "warm", title: l("暖黑", "Warm black")),
                            WorkspaceOption(value: "custom", title: l("自选配色", "Custom palette"))]).frame(width: 220)
                }
                if appearanceString("dark_theme").wrappedValue == "custom" {
                    ForEach(["bg","text","link","code","added","removed"], id: \.self) { key in
                        Divider()
                        settingsRow(darkColorTitle(key)) {
                            ColorPicker(darkColorTitle(key), selection: Binding(
                                get: { themeColor(appearanceString("dark_" + key).wrappedValue) },
                                set: { model.appearance["dark_" + key] = $0.hexString }), supportsOpacity: false).labelsHidden()
                            Text(appearanceString("dark_" + key).wrappedValue).font(.system(size: 12, design: .monospaced)).frame(width: 90)
                        }
                    }
                }
            }
            Text(l("正文、链接、代码和 diff 增删底色一起调整；终端保留自己的配色。", "Coordinates text, links, code and diff backgrounds. The terminal keeps its own palette."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    private func darkColorTitle(_ key: String) -> String {
        switch key {
        case "bg": return l("页面底色", "Page background")
        case "text": return l("正文", "Body text")
        case "link": return l("链接", "Links")
        case "code": return l("代码底色", "Code background")
        case "added": return l("Diff 新增", "Diff additions")
        default: return l("Diff 删除", "Diff deletions")
        }
    }

    // MARK: Themes

    private var themes: some View {
        VStack(alignment: .leading, spacing: 24) {
            readingPreview
            HStack(spacing: 12) {
                Button(l("保存当前主题", "Save current theme")) {
                    model.themeError = false; themeDraft = WorkspaceThemeDraft(name: model.uniqueThemeName(l("我的主题", "My theme")))
                }.buttonStyle(WorkspaceActionStyle(prominent: true))
                Button(l("导入", "Import")) { model.importTheme() }.buttonStyle(WorkspaceActionStyle())
                Button(l("导出当前设置", "Export current settings")) {
                    model.exportTheme(ThemeDocument(name: l("当前主题", "Current theme"), settings: model.settingsSnapshot))
                }.buttonStyle(WorkspaceActionStyle())
                Spacer()
            }
            Text(l("分享文件只包含字体、字号、排版和配色。载入主题后仍需点击“应用设置”。", "Shared files contain fonts, scale, typography and colors. Load a theme, then choose Apply settings."))
                .font(.callout).foregroundStyle(.secondary)
            if !model.themeMessage.isEmpty {
                alertStrip(model.themeError ? "exclamationmark.triangle" : "checkmark.circle", l("主题", "Themes"), model.themeMessage, color: model.themeError ? .red : accent)
            }
            if !model.missingStyleFonts.isEmpty {
                alertStrip("textformat", l("部分字体未安装", "Some fonts are missing"), model.missingStyleFonts.joined(separator: "、"), color: accent)
            }
            VStack(alignment: .leading, spacing: 14) {
                sectionTitle(l("推荐起点", "Starting points"), symbol: "sparkles")
                HStack(spacing: 12) {
                    ForEach(Array(model.recommendedThemes.enumerated()), id: \.element.id) { index, theme in
                        let selected = theme.settings == model.settingsSnapshot
                        Button { withAnimation(motion) { model.selectTheme(theme) } } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: ["text.book.closed", "curlybraces", "textformat.size"][index])
                                    .font(.system(size: 20, weight: .light)).foregroundStyle(accent).frame(width: 26)
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(theme.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(ink)
                                    Text([l("舒展行距 · 暖色底色", "Roomy text · Warm palette"),
                                          l("等宽字形 · 清晰 Diff", "Monospace · Clear diffs"),
                                          l("大字阅读 · 清晰界面", "Larger text · Clear UI")][index])
                                        .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(20).frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                            .background(selected ? accent.opacity(0.10) : surface, in: RoundedRectangle(cornerRadius: 24))
                            .overlay(RoundedRectangle(cornerRadius: 24).strokeBorder(selected ? accent.opacity(0.45) : ink.opacity(0.06)))
                            .contentShape(RoundedRectangle(cornerRadius: 24))
                        }.buttonStyle(.plain).focusEffectDisabled().accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            sectionTitle(l("已保存主题", "Saved themes"), symbol: "square.stack.3d.up")
            if model.themes.isEmpty {
                panel {
                    Text(l("把当前组合保存成第一个主题。", "Save your current settings as your first theme."))
                        .font(.system(size: 14)).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading).frame(minHeight: 96)
                }
            }
            ForEach(model.themes) { theme in
                panel {
                    HStack(spacing: 16) {
                        let selected = theme.settings == model.settingsSnapshot
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle.lefthalf.filled").foregroundStyle(accent)
                        VStack(alignment: .leading, spacing: 6) {
                            Text(theme.name).font(.system(size: 15, weight: .semibold))
                            Text(theme.settings["font"] ?? "").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(selected ? l("已载入", "Loaded") : l("载入", "Load")) { withAnimation(motion) { model.selectTheme(theme) } }
                            .buttonStyle(WorkspaceActionStyle()).disabled(selected)
                        WorkspaceDropdown<WorkspaceThemeAction?>(title: l("主题操作", "Theme actions"),
                            selection: Binding(get: { nil }, set: { action in
                                switch action {
                                case .rename: model.themeError = false; themeDraft = WorkspaceThemeDraft(name: theme.name, replacing: theme.name)
                                case .duplicate: model.duplicateTheme(theme)
                                case .export: model.exportTheme(theme)
                                case .delete: deleteTheme = theme
                                case nil: break
                                }
                            }), options: [
                                WorkspaceOption(value: .rename, title: l("重命名", "Rename")),
                                WorkspaceOption(value: .duplicate, title: l("复制", "Duplicate")),
                                WorkspaceOption(value: .export, title: l("导出", "Export")),
                                WorkspaceOption(value: .delete, title: l("删除", "Delete"), destructive: true)
                            ], symbol: "ellipsis").frame(width: 62).accessibilityLabel(theme.name + l("主题操作", " theme actions"))
                    }
                    .padding(.vertical, 20).frame(minHeight: 96)
                }
            }
        }
        .disabled(model.busy)
    }
    // MARK: Compatibility

    private var targetReason: String {
        let reason = model.current.reason
        if reason.hasPrefix("Existing foreign font patch:") {
            return l("检测到之前的字体修改。选择“接续已有修改”，导入同版本原版备份和设置后即可继续应用。", "Earlier font changes were detected. Choose Continue previous changes to import the same-version pristine backup and settings, then apply your changes.")
        }
        return reason
    }

    private var compatibilityPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                sectionTitle(l("更新兼容性", "Update compatibility"), symbol: "checkmark.shield")
                Spacer()
                Button(l("重新检查", "Check again")) { model.refresh(model.target) }
                    .buttonStyle(WorkspaceActionStyle()).disabled(model.busy || !model.exists(model.target))
            }
            panel {
                if let report = model.current.compatibility {
                    VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Claude " + report.version).font(.system(size: 14, weight: .semibold))
                        Spacer()
                        Text(report.versionEvidence == "region_adapter_tested" ? l("字体适配有隔离测试记录", "Font adapter has isolated test evidence") : l("此版本未验证", "Version unverified"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Divider()
                    ForEach(CodeRegion.allCases) { region in
                        HStack {
                            Text(region.title).font(.system(size: 13))
                            Spacer()
                            Text(report.regions[region.rawValue] == "matched" ? l("结构匹配", "Structure matched") : l("需核验适配", "Adapter unverified"))
                                .font(.system(size: 12)).foregroundStyle(.secondary)
                            Text(report.installedRegions[region.rawValue] == true ? l("已写入覆盖", "Override written") : l("未写入覆盖", "No override written"))
                                .font(.system(size: 12)).foregroundStyle(accent).frame(width: 120, alignment: .trailing)
                        }.padding(.vertical, 5)
                    }
                    Divider()
                    Text(model.current.state == "previous" ? l("旧版样式仍保留，应用设置后将使用已导入的设置重新写入。", "Previous styles are preserved. Apply changes to write the imported settings.") : report.injection ? ((report.settingsMatch && !model.hasUnapplied) ? l("当前设置与写入样式一致。", "Current settings match the written styles.") : l("已有样式注入，当前设置与写入内容不同。", "Styles are injected. Current settings differ from the written styles.")) : l("当前未检测到本工具的样式注入。", "No style injection from this tool was detected."))
                        .font(.caption).foregroundStyle(.secondary)
                    Text(report.canReapply ? l("基础应用结构匹配，可尝试在测试副本重新应用。各区域实际显示仍需在 Claude 中核验。", "Base app structure matches. Try reapplying to a test copy, then check each region in Claude.") : l("当前设置无法安全匹配，请检查目标或恢复终端默认设置后再试。", "Current settings cannot be matched safely. Check the target or restore default terminal settings."))
                        .font(.caption).foregroundStyle(.secondary)
                    }.padding(.vertical, 20)
                } else {
                    HStack(alignment: .top, spacing: 14) {
                        Image(systemName: model.current.missing ? "macwindow" : "arrow.triangle.2.circlepath")
                            .font(.system(size: 22, weight: .light)).foregroundStyle(accent)
                            .frame(width: 38, height: 38).background(accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 6) {
                            Text(model.current.missing ? l("选择 Claude 后即可检查", "Choose Claude to check compatibility") : model.current.loaded ? l("兼容性尚未确认", "Compatibility not confirmed") : l("正在读取目标状态", "Reading target status"))
                                .font(.system(size: 14, weight: .semibold))
                            Text(model.current.missing ? l("检查当前版本、区域适配和已写入的样式。若 Claude 安装在其他位置，请选择它的应用文件。", "Check the current version, region adapters and written styles. If Claude is installed elsewhere, choose its app file.") : model.current.loaded ? (model.current.reason.isEmpty ? l("请查看日志中的检查结果。", "See the check results in Logs.") : targetReason) : l("检查结果将在这里显示。", "Results will appear here."))
                                .font(.system(size: 12)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 22)
                }
            }
        }
    }

    // MARK: Logs

    private var logs: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 12) {
                metric(l("签名", "Signature"), value: !model.current.loaded || model.current.missing ? "—"
                       : model.current.signOK.map { $0 ? l("通过", "Valid") : l("失败", "Failed") } ?? l("未检查", "Not checked"))
                metric(l("完整性", "Integrity"), value: !model.current.loaded || model.current.missing ? "—"
                       : model.current.integrityOK.map { $0 ? l("通过", "Valid") : l("失败", "Failed") } ?? l("未检查", "Not checked"))
                metric(l("备份", "Backups"), value: model.current.loaded && !model.current.missing
                       ? "\(model.current.backups.count)" : "—")
            }
            HStack {
                sectionTitle(l("运行记录", "Session log"), symbol: "terminal")
                Spacer()
                Button(t("action.doctor")) { model.doctor() }.disabled(model.busy)
                Button(t("log.clear")) { model.log = "" }.disabled(model.log.isEmpty)
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        if model.logLines.isEmpty {
                            Text(l("暂无记录。执行自检后可在这里查看结果。",
                                   "No activity yet. Run a diagnosis to see results here."))
                                .foregroundStyle(.white.opacity(0.5))
                        }
                        ForEach(Array(model.logLines.enumerated()), id: \.offset) { i, line in
                            Text(line)
                                .foregroundStyle(line.hasPrefix("✗") ? Color(hex: 0xF29488) : .white.opacity(0.82))
                                .id(i)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(23)
                }
                .frame(minHeight: 260, maxHeight: 360)
                .onChange(of: model.logLines.count) { _, count in
                    if count > 0 { proxy.scrollTo(count - 1, anchor: .bottom) }
                }
            }
            .font(.system(size: 12, design: .monospaced))
            .textSelection(.enabled)
            .background(Color(hex: 0x1C2229), in: RoundedRectangle(cornerRadius: 28))
            panel {
                settingsRow(l("最近检查", "Last checked")) {
                    Text(model.current.checkedAt.isEmpty ? "—" : model.current.checkedAt)
                        .foregroundStyle(.secondary)
                }
                Divider()
                settingsRow(l("可用空间", "Free space")) { Text(model.diskFree).foregroundStyle(.secondary) }
                Divider()
                settingsRow(l("完整备份", "Full backups")) {
                    Button(l("查看详情", "Details")) {
                        showDetails.toggle()
                        if showDetails { model.loadBackups(model.target) }
                    }
                }
                if showDetails {
                    Divider()
                    settingsRow(model.backupInfo[model.target]?.summary ?? "—") {
                        if let count = model.backupInfo[model.target]?.prunable, count > 0 {
                            Button(t("detail.prune", ["{n}": String(count)])) {
                                model.pruneBackups(model.target)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Shared presentation and actions

    private func sectionTitle(_ text: String, symbol: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(ink)
    }

    private func panel<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) { content() }
            .padding(.horizontal, 21)
            .background(surface, in: RoundedRectangle(cornerRadius: 28))
            .overlay(RoundedRectangle(cornerRadius: 28).strokeBorder(ink.opacity(0.035)))
    }

    private func settingsRow<Control: View>(_ title: String, subtitle: String? = nil,
                                            @ViewBuilder control: () -> Control) -> some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .semibold)).foregroundStyle(ink)
                if let subtitle { Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 20)
            control()
        }
        .padding(.vertical, 15)
    }

    private func sizeRow(_ title: String, _ value: Binding<Double>) -> some View {
        settingsRow(title) {
            WorkspaceScaleSlider(value: value).frame(width: 170, height: 28).accessibilityLabel(title)
            Text("\(Int(value.wrappedValue))%")
                .font(.system(size: 12, design: .monospaced))
                .monospacedDigit().frame(width: 44, alignment: .trailing)
            Button { value.wrappedValue = 100 } label: { Image(systemName: "arrow.counterclockwise") }
                .buttonStyle(.plain).focusEffectDisabled().disabled(value.wrappedValue == 100)
                .help(t("font.reset")).accessibilityLabel(l("恢复 100%", "Reset to 100%"))
        }
    }

    private func fontOptions(_ choices: [FontChoice], selected: String,
                             emptyTitle: String? = nil) -> [WorkspaceOption<String>] {
        var seen = Set<String>()
        var options = choices.filter { seen.insert($0.family).inserted }
            .map { WorkspaceOption(value: $0.family, title: $0.localized ?? $0.family) }
        if !selected.isEmpty && !seen.contains(selected) {
            options.insert(WorkspaceOption(value: selected, title: selected + l("（未安装）", " (not installed)")), at: 0)
        }
        if let emptyTitle { options.insert(WorkspaceOption(value: "", title: emptyTitle), at: 0) }
        return options
    }

    private func fontPicker(_ value: Binding<String>, _ choices: [FontChoice], title: String) -> some View {
        WorkspaceDropdown(title: title, selection: value,
            options: fontOptions(choices, selected: value.wrappedValue), searchable: true).frame(width: 220)
    }

    private func metric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 11)).foregroundStyle(.secondary)
            Text(value).font(.system(size: 21, weight: .semibold, design: .rounded)).foregroundStyle(ink)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .background(quiet, in: RoundedRectangle(cornerRadius: 24))
    }

    private func alertStrip(_ symbol: String, _ title: String, _ body: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 13, weight: .semibold))
                Text(body).font(.system(size: 11.5)).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(color.opacity(0.09), in: RoundedRectangle(cornerRadius: WorkspaceDesign.radius))
    }

    private func chooseCustomApp() {
        let picker = NSOpenPanel()
        picker.canChooseDirectories = false
        picker.canChooseFiles = true
        picker.allowedContentTypes = [.applicationBundle]
        picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.message = t("target.choose.msg")
        guard picker.runModal() == .OK, let url = picker.url else { return }
        model.customAppPath = url.path
        model.target = .custom
        model.refresh(.custom)
    }

    private func beginApply() {
        guard !model.targetRunning else { showNeedsQuit = true; return }
        if model.target == .production { showApplyConfirm = true }
        else { runApply() }
    }

    private func chooseClassicPreset() {
        model.scope = "cjk"
        model.fontFamily = ClassicPreset.font
        model.fontScale = ClassicPreset.scale
        model.bgColor = ClassicPreset.bg
        model.fontMono = ""
        model.fontMonoScale = 100
        model.codeSettings = Dictionary(uniqueKeysWithValues:
            CodeRegion.allCases.map { ($0, CodeRegionSetting()) })
        model.fontScaleUI = 100
        model.latinScope = "all"
        model.mode = "auto"
        model.appearance = StyleSchema.extraDefaults
    }

    private func runApply() {
        guard !model.targetRunning else { showNeedsQuit = true; return }
        showApplying = true
        model.install { ok in
            showApplying = false
            tab = .logs
            if ok {
                model.openTarget()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { showSuccess = true }
            }
        }
    }

    private var applyingSheet: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                ProgressView()
                Text(t("sheet.applying.title")).font(.system(size: 18, weight: .semibold))
            }
            Text(model.busyLabel).font(.system(size: 12)).foregroundStyle(.secondary)
            ScrollView {
                Text(model.log.isEmpty ? "…" : model.log)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(15)
            }
            .font(.system(size: 11, design: .monospaced))
            .frame(height: 180)
            .background(Color(hex: 0x1C2229).opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            Text(t("sheet.applying.keychain"))
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
        }
        .padding(25).frame(width: 520)
        .interactiveDismissDisabled()
    }

    private var helpSheet: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(t("help.title"))
                        .font(.system(size: 24, weight: .semibold))
                    Text(l("按顺序完成设置，应用后在 Claude 中查看效果。",
                           "Set up your preferences, then check the result in Claude."))
                        .font(.system(size: 12)).foregroundStyle(.secondary)
                }
                Spacer()
                Button { showHelp = false } label: { Image(systemName: "xmark") }.buttonStyle(.plain).focusEffectDisabled()
            }
            .padding(.horizontal, 27).padding(.top, 25).padding(.bottom, 20)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    ForEach(helpSteps.indices, id: \.self) { step in
                        HStack(alignment: .top, spacing: 15) {
                            Text(String(format: "%02d", step + 1))
                                .font(.system(size: 13, weight: .bold, design: .monospaced))
                                .foregroundStyle(accent)
                                .frame(width: 28, alignment: .leading)
                            VStack(alignment: .leading, spacing: 7) {
                                Text(helpSteps[step].0)
                                    .font(.system(size: 14, weight: .semibold))
                                Text(helpSteps[step].1)
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }
                .padding(27)
            }
            .frame(height: 350)
            Divider()
            HStack {
                Text(l("测试副本使用独立的新配置，不复制正式 Claude 的登录或会话。",
                       "A test copy uses a fresh profile without copying sign-in or sessions from the main Claude."))
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button(t("sheet.ok")) { showHelp = false }
                    .buttonStyle(WorkspaceActionStyle(prominent: true))
            }
            .padding(.horizontal, 27).padding(.vertical, 16)
        }
        .frame(width: 620)
    }

    private var helpSteps: [(String, String)] {
        [
            (l("检测权限", "Check access"),
             l("在“概览”点击“检测权限”，首次检测可能弹出授权请求。授权由 macOS 保存。若访问被拒绝，按提示前往“App 管理”设置，再重新检测。",
               "Choose Check access in Overview. The first check may ask for approval, which macOS saves. If access is denied, open App Management settings and check again.")),
            (l("选择目标", "Choose a target"),
             l("先选正式 Claude，或创建测试 Claude 副本验证效果。测试副本使用独立应用和配置目录。",
               "Select the main Claude or create a test copy to check the result. The copy has a separate app and profile.")),
            (l("调整样式", "Tune the appearance"),
             l("在“字体”“代码”“背景”页面调整。预览仅供参考，修改需要点击底部“应用设置”才会写入所选应用。",
               "Use Fonts, Code, and Background. Previews are local; choose Apply changes at the bottom to update the selected app.")),
            (l("应用与还原", "Apply and restore"),
             l("应用前会备份并确认正式版目标；进度见“日志”。Claude 更新后可再次点击“应用设置”。“更多操作”中可还原。",
               "The app backs up before applying and confirms main-app changes. See Logs for progress, apply again after Claude updates, or restore from More actions."))
        ]
    }
}

struct WorkspaceAboutView: View {
    @ObservedObject private var copy = Copy.shared
    @AppStorage("autoCheckUpdates") private var autoCheck = true
    private var chinese: Bool { copy.effective == .zh }

    var body: some View {
        VStack(alignment: .leading, spacing: 21) {
            HStack(alignment: .center, spacing: 22) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable().frame(width: 76, height: 76)
                VStack(alignment: .leading, spacing: 6) {
                    Text("ClaudeFont").font(.system(size: 26, weight: .semibold))
                    Text(t("about.version", [
                        "{v}": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—",
                        "{b}": Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
                    ]))
                    .font(.system(size: 12, design: .monospaced)).foregroundStyle(.secondary)
                }
                Spacer()
            }
            Text(t("about.tagline"))
                .font(.system(size: 14)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack(spacing: 13) {
                aboutPillar("textformat", chinese ? "字体" : "Type")
                aboutPillar("curlybraces", chinese ? "代码" : "Code")
                aboutPillar("circle.lefthalf.filled", chinese ? "背景" : "Background")
            }
            Divider()
            HStack {
                Text(t("about.lang"))
                Spacer()
                WorkspaceDropdown(title: t("about.lang"), selection: $copy.lang, options: [
                    WorkspaceOption(value: Lang.auto, title: t("about.lang.auto")),
                    WorkspaceOption(value: Lang.zh, title: "简体中文"),
                    WorkspaceOption(value: Lang.en, title: "English")
                ]).frame(width: 180)
            }
            Toggle(t("update.auto"), isOn: $autoCheck).toggleStyle(.switch)
            UpdateCheckButton()
            Text(t("about.footer"))
                .font(.system(size: 11.5)).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(29)
        .frame(width: 490)
        .tint(WorkspaceDesign.accent)
        .focusEffectDisabled()
    }

    private func aboutPillar(_ symbol: String, _ title: String) -> some View {
        VStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 19))
            Text(title).font(.system(size: 12, weight: .medium))
        }
        .foregroundStyle(WorkspaceDesign.accent)
        .frame(maxWidth: .infinity).frame(height: 80)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 24))
    }
}

private enum WorkspaceThemeAction: Hashable { case rename, duplicate, export, delete }

private struct WorkspaceThemeDraft: Identifiable {
    let id = UUID()
    let name: String
    var replacing: String? = nil
}

private struct WorkspaceThemeNameSheet: View {
    @ObservedObject var model: Model
    let draft: WorkspaceThemeDraft
    let lang: Lang
    @State private var name: String
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var scheme
    init(model: Model, draft: WorkspaceThemeDraft, lang: Lang) {
        self.model = model; self.draft = draft; self.lang = lang; _name = State(initialValue: draft.name)
    }
    private func l(_ zh: String, _ en: String) -> String { lang == .zh ? zh : en }
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(draft.replacing == nil ? l("保存主题", "Save theme") : l("重命名主题", "Rename theme"))
                .font(.system(size: 22, weight: .semibold))
            TextField(l("主题名称", "Theme name"), text: $name).modifier(WorkspaceInputStyle())
            HStack {
                Spacer()
                Button(t("sheet.cancel")) { dismiss() }.buttonStyle(WorkspaceActionStyle())
                Button(l("保存", "Save")) { model.saveTheme(name: name, replacing: draft.replacing); if !model.themeError { dismiss() } }
                    .buttonStyle(WorkspaceActionStyle(prominent: true))
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 60)
            }
            if model.themeError { Text(model.themeMessage).font(.caption).foregroundStyle(.red) }
        }.padding(28).frame(width: 420).background(WorkspaceDesign.surface(scheme))
    }
}

private struct WorkspaceLigatureSample: NSViewRepresentable {
    let fontName: String
    let size: Double
    let ligatures: String
    let color: NSColor
    func makeNSView(context: Context) -> NSTextField {
        let label = NSTextField(labelWithString: "")
        label.isSelectable = true; label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }
    func updateNSView(_ label: NSTextField, context: Context) {
        var attrs: [NSAttributedString.Key:Any] = [.font:NSFont(name: fontName, size: size) ?? NSFont.monospacedSystemFont(ofSize:size,weight:.regular), .foregroundColor:color]
        if ligatures != "default" { attrs[.ligature] = ligatures == "on" ? 1 : 0 }
        label.attributedStringValue = NSAttributedString(string:"a != b   value == result   x => y",attributes:attrs)
        label.setAccessibilityLabel("a != b, value == result, x => y")
    }
}
