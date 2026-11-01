import AppKit
import SwiftUI
import CryptoKit

final class HUDState: ObservableObject {
    @Published var title = "✅ 复制成功！ Copy × 1"
    @Published var subtitle = "今日已 Copy 1 次"
    @Published var key = "⌘ C"
}
struct HUDView: View {
    @ObservedObject var state: HUDState
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 10) {
                Text(state.key).font(.system(size: 15, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
                Text(state.title).font(.system(size: 19, weight: .semibold)).lineLimit(1)
            }
            Text(state.subtitle).font(.system(size: 12)).foregroundStyle(.secondary).lineLimit(1)
        }.padding(.horizontal, 20).frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
final class HUD {
    let state = HUDState()
    let panel: NSPanel
    private var hide: DispatchWorkItem?
    private var motion: Timer?
    init() {
        panel = NSPanel(contentRect: NSRect(x: 0,y: 0,width: 460,height: 72), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .statusBar; panel.isOpaque = false; panel.backgroundColor = .clear
        panel.hasShadow = true; panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        let material = NSVisualEffectView()
        material.material = .hudWindow; material.blendingMode = .behindWindow; material.state = .active
        material.wantsLayer = true; material.layer?.cornerRadius = 18; material.layer?.masksToBounds = true
        let host = NSHostingView(rootView: HUDView(state: state))
        host.translatesAutoresizingMaskIntoConstraints = false; material.addSubview(host)
        NSLayoutConstraint.activate([host.leadingAnchor.constraint(equalTo: material.leadingAnchor),host.trailingAnchor.constraint(equalTo: material.trailingAnchor),host.topAnchor.constraint(equalTo: material.topAnchor),host.bottomAnchor.constraint(equalTo: material.bottomAnchor)])
        panel.contentView = material
    }
    func show(title: String, total: Int, key: String, repeated: Bool, detail: String? = nil) {
        hide?.cancel(); motion?.invalidate(); panel.animator().alphaValue = 1
        state.title = title; state.subtitle = detail ?? "今日已 Copy \(total) 次"; state.key = key
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main!
        let textWidth = (title as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 19,weight: .semibold)]).width
        let width = min(screen.visibleFrame.width - 32, max(340, textWidth + 112))
        let origin = NSPoint(x: screen.visibleFrame.midX - width / 2, y: screen.visibleFrame.maxY - 84)
        panel.setFrame(NSRect(origin: origin, size: NSSize(width: width,height: 72)), display: true)
        panel.alphaValue = 1; panel.orderFrontRegardless()
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        if !reduced {
            let start = Date()
            motion = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
                guard let self else { timer.invalidate(); return }
                let t = Date().timeIntervalSince(start) / 0.3
                if t >= 1 { timer.invalidate(); self.panel.setFrameOrigin(origin); return }
                let x = repeated ? sin(t * .pi * 6) * 7 * (1-t) : 0
                let y = repeated ? 0 : -4 * (1-t)
                self.panel.setFrameOrigin(NSPoint(x: origin.x+x,y: origin.y+y))
            }
        }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2; self.panel.animator().alphaValue = 0
            }
        }
        hide = work; DispatchQueue.main.asyncAfter(deadline: .now()+1.8, execute: work)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    var counter = CopyCounter()
    let hud = HUD()
    var board = NSPasteboard.general
    let secret = SymmetricKey(size: .bits256)
    var lastChange = 0
    var observedAt = Date()
    var candidate: Int?
    var timer: Timer?
    var tap: CFMachPort?
    var source: CFRunLoopSource?
    var pending: [(Date, Int)] = []
    var status: NSStatusItem!
    var paused = false
    var demoCount = 0
    var appliedIconName = ""
    var appearanceObserver: NSKeyValueObservation?
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        appearanceObserver = NSApp.observe(\.effectiveAppearance, options: [.initial, .new]) { [weak self] app, _ in
            self?.updateAppIcon(app.effectiveAppearance)
        }
        lastChange = board.changeCount
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menuIcon = NSImage(size: NSSize(width: 34, height: 18), flipped: false) { _ in
            ("⌘ C" as NSString).draw(at: NSPoint(x: 0, y: 0), withAttributes: [.font: NSFont.systemFont(ofSize: 14, weight: .medium), .foregroundColor: NSColor.black])
            return true
        }
        menuIcon.isTemplate = true
        menuIcon.accessibilityDescription = "CopyPop"
        status.button?.image = menuIcon
        if let index = CommandLine.arguments.firstIndex(of: "--verify-ui"), CommandLine.arguments.count > index + 1 {
            verifyUI(directory: CommandLine.arguments[index + 1]); return
        }
        installTap(); updateMenu()
        timer = Timer.scheduledTimer(withTimeInterval: 0.08, repeats: true) { [weak self] _ in self?.poll() }
        if CommandLine.arguments.contains("--preview") { preview() }
    }
    func updateAppIcon(_ appearance: NSAppearance) {
        let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let name = dark ? "AppIcon-dark" : "AppIcon"
        if let url = Bundle.main.url(forResource: name, withExtension: "png"), let icon = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = icon
            appliedIconName = name
        }
    }
    func verifyUI(directory: String) {
        let suite = "CopyPopVerification.\(UUID())"
        let testDefaults = UserDefaults(suiteName: suite)!
        counter = CopyCounter(defaults: testDefaults)
        board = NSPasteboard(name: NSPasteboard.Name(suite))
        lastChange = board.changeCount
        var results: [String: Any] = [:]
        func simulate(_ text: String) {
            board.clearContents(); board.setString(text, forType: .string)
            poll(); observedAt = Date(timeIntervalSinceNow: -0.2); poll()
        }
        simulate("Test A")
        simulate("Test B")
        simulate("Test A")
        results["interleavedClipboardCount"] = counter.total
        results["interleavedRepeatRecognized"] = hud.state.title.contains("× 2")
        let before = counter.total
        pending.append((Date(timeIntervalSinceNow: -2), board.changeCount))
        poll()
        results["unconfirmedDoesNotCount"] = counter.total == before && hud.state.title.contains("未确认")
        board.clearContents(); poll(); observedAt = Date(timeIntervalSinceNow: -0.2); poll()
        results["emptyClipboardDoesNotCount"] = counter.total == before
        let previewTotal = counter.total
        for (index, appearance) in [NSAppearance.Name.aqua, .darkAqua].enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.6) {
                self.hud.panel.appearance = NSAppearance(named: appearance)
                NSApp.appearance = NSAppearance(named: appearance)
                let iconName = index == 0 ? "AppIcon" : "AppIcon-dark"
                let iconURL = Bundle.main.url(forResource: iconName, withExtension: "png")
                let expectedIcon = iconURL.flatMap { NSImage(contentsOf: $0) }
                self.hud.show(title: self.message(index + 1), total: 28, key: "⌘ C", repeated: index > 0)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    results[index == 0 ? "lightIconLoaded" : "darkIconLoaded"] = expectedIcon != nil && self.appliedIconName == iconName
                    let view = self.hud.panel.contentView!
                    view.layoutSubtreeIfNeeded()
                    if let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                        view.cacheDisplay(in: view.bounds, to: rep)
                        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: directory).appendingPathComponent(index == 0 ? "HUD-light.png" : "HUD-dark.png"))
                    }
                    results[index == 0 ? "lightHeight" : "darkHeight"] = self.hud.panel.frame.height
                    results["windowCount"] = NSApp.windows.filter { $0 is NSPanel && $0.isVisible }.count
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            results["alphaAfterFade"] = self.hud.panel.alphaValue
            results["previewDidNotCount"] = self.counter.total == previewTotal
            if let data = try? JSONSerialization.data(withJSONObject: results, options: [.prettyPrinted, .sortedKeys]) {
                try? data.write(to: URL(fileURLWithPath: directory).appendingPathComponent("ui-verification.json"))
            }
            self.board.releaseGlobally()
            testDefaults.removePersistentDomain(forName: suite)
            NSApp.terminate(nil)
        }
    }
    func installTap() {
        guard tap == nil, CGPreflightListenEventAccess() else { return }
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let app = Unmanaged<AppDelegate>.fromOpaque(info).takeUnretainedValue()
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = app.tap { CGEvent.tapEnable(tap: tap, enable: true) }
            } else if type == .keyDown, event.getIntegerValueField(.keyboardEventKeycode) == 8,
                event.flags.contains(.maskCommand), !event.flags.contains(.maskAlternate), !event.flags.contains(.maskControl), !event.flags.contains(.maskShift),
                event.getIntegerValueField(.keyboardEventAutorepeat) == 0, !app.paused {
                app.pending.append((Date(), app.board.changeCount))
            }
            return Unmanaged.passUnretained(event)
        }
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly, eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue), callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque())
        if let tap { source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault,tap,0); CFRunLoopAddSource(CFRunLoopGetMain(),source,.commonModes); CGEvent.tapEnable(tap: tap,enable: true) }
    }
    func poll() {
        let oldTotal = counter.total; counter.refresh()
        if oldTotal != counter.total { updateMenu() }
        if paused { lastChange = board.changeCount; candidate = nil; pending.removeAll(); return }
        let current = board.changeCount
        if current != lastChange {
            if candidate != current { candidate = current; observedAt = Date() }
            else if Date().timeIntervalSince(observedAt) >= 0.08 {
                lastChange = current; candidate = nil
                // A revision is a confirmed clipboard update, not proof of the originating app's intent.
                let isKey = !pending.isEmpty
                if isKey { pending.removeFirst() }
                if !(board.pasteboardItems ?? []).isEmpty {
                    let n = counter.record(fingerprint())
                    hud.show(title: message(n), total: counter.total, key: isKey ? "⌘ C" : "Copy", repeated: n > 1)
                    updateMenu()
                }
            }
        }
        if let first = pending.first, Date().timeIntervalSince(first.0) > 1.0, candidate == nil {
            pending.removeFirst()
            hud.show(title: "🤔 未确认复制", total: counter.total, key: "⌘ C", repeated: false, detail: "今日已 Copy \(counter.total) 次 · 本次未计数")
        }
        if tap == nil && CGPreflightListenEventAccess() { installTap(); updateMenu() }
    }
    func fingerprint() -> String? {
        guard let items = board.pasteboardItems, !items.isEmpty else { return nil }
        let sensitive = ["org.nspasteboard.ConcealedType", "org.nspasteboard.TransientType", "org.nspasteboard.AutoGeneratedType"]
        if items.contains(where: { item in item.types.contains(where: { sensitive.contains($0.rawValue) }) }) { return nil }
        var hmac = HMAC<SHA256>(key: secret)
        var size = 0
        for item in items {
            let types: [NSPasteboard.PasteboardType] = [.string, .fileURL, .png, .tiff, .rtf, .pdf]
            guard let type = types.first(where: { item.types.contains($0) }), let data = item.data(forType: type) else { return nil }
            size += data.count
            guard size <= 8 * 1024 * 1024 else { return nil }
            hmac.update(data: Data("\(type.rawValue):\(data.count):".utf8)); hmac.update(data: data)
        }
        return Data(hmac.finalize()).base64EncodedString()
    }
    func message(_ n: Int) -> String {
        let text: String
        switch n {
        case 1: text = "✅ 复制成功！"
        case 2: text = "👀 哎哟，又是它！"
        case 3: text = "😂 怎么又来一遍！"
        case 4: text = "🧐 怕它跑了吗？"
        case 5...9: text = "🤣 我都背下来了！"
        case 10...19: text = "😵‍💫 复制键冒烟啦！"
        default: text = "🏆 复制狂魔上线！"
        }
        return "\(text) Copy × \(n)"
    }
    func updateMenu() {
        let menu = NSMenu()
        func add(_ title: String, _ action: Selector? = nil) { let item = NSMenuItem(title: title,action: action,keyEquivalent: ""); item.target = self; menu.addItem(item) }
        add("CopyPop · 今日已 Copy \(counter.total) 次")
        add(tap == nil ? "模式：仅检测剪贴板更新" : "模式：剪贴板 + ⌘C 检测")
        menu.addItem(.separator())
        add("预览 HUD（不计数）", #selector(preview))
        add(paused ? "继续检测" : "暂停检测", #selector(togglePause))
        add("启用 ⌘C 检测…", #selector(permission))
        add("使用与隐私说明", #selector(about))
        menu.addItem(.separator()); add("退出 CopyPop", #selector(quit))
        status.menu = menu
    }
    @objc func preview() { demoCount = demoCount % 4 + 1; hud.show(title: message(demoCount),total: counter.total,key: "⌘ C",repeated: demoCount > 1) }
    @objc func togglePause() { paused.toggle(); pending.removeAll(); lastChange = board.changeCount; updateMenu() }
    @objc func permission() {
        _ = CGRequestListenEventAccess(); installTap(); updateMenu()
        if tap == nil { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")!) }
    }
    @objc func about() {
        let alert = NSAlert(); alert.messageText = "CopyPop · 复制一下，开心一下"
        alert.informativeText = "无需授权即可检测剪贴板更新。要识别未更新剪贴板的 ⌘C，请在系统设置中启用输入监控，必要时退出后重开。\n\n统计的是观察到的非空剪贴板更新，可能包括其他应用的自动写入；无法确认时不计数。快速连续操作可能合并。\n\n只持久保存日期和今日总数。不保存剪贴板原文；带随机密钥的摘要仅留在内存，当天或退出后清空。同一内容跨不同复制操作累计，重启后重新累计。敏感标记、未知格式及超过 8 MB 的内容只计总数。\n\n无联网、无声音、不自动开机启动。菜单预览不计数。"
        alert.runModal()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
