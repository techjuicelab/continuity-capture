// ContinuityCapture — trigger Continuity Camera (Take Photo / Scan Documents)
// from an iPhone/iPad and save the result directly into a folder. Runs only
// while invoked; exits as soon as the capture is saved, cancelled, or timed out.
//
// Mechanism (per Apple "Supporting Continuity Camera in your Mac app"):
// NSTextView gets Continuity Camera support automatically — AppKit appends the
// "Import from iPhone or iPad" items to its contextual menu when a responder
// in the chain validates image pasteboard data. The captured photo/scan lands
// in the text view as an NSTextAttachment, whose file wrapper we save to disk.
//
// Usage: ContinuityCapture [photo|scan] [--out DIR] [--device HINT] [--dry-run] [--no-auto]

import AppKit

// MARK: - Config

struct Config {
    var action = "photo"                 // photo | scan
    var outDir = NSString(string: "~/Pictures/from_iphone").expandingTildeInPath
    var deviceHint = "iPhone"
    var dryRun = false
    var dryRunHold: TimeInterval = 1.6
    var autoTrigger = true
    var contextMenuMode = false
    var selfTest = false
    var accessory = true
    var captureTimeout: TimeInterval = 300

    static func parse() -> Config {
        var c = Config()
        var args = Array(CommandLine.arguments.dropFirst())
        while !args.isEmpty {
            let a = args.removeFirst()
            switch a {
            case "photo", "scan": c.action = a
            case "--out": if !args.isEmpty { c.outDir = NSString(string: args.removeFirst()).expandingTildeInPath }
            case "--device": if !args.isEmpty { c.deviceHint = args.removeFirst() }
            case "--dry-run": c.dryRun = true
            case "--hold": if !args.isEmpty { c.dryRunHold = Double(args.removeFirst()) ?? 1.6 }
            case "--context-menu": c.contextMenuMode = true
            case "--self-test": c.selfTest = true
            case "--accessory": c.accessory = true
            case "--regular": c.accessory = false
            case "--no-auto": c.autoTrigger = false
            case "--timeout": if !args.isEmpty { c.captureTimeout = Double(args.removeFirst()) ?? 300 }
            default: break
            }
        }
        return c
    }

    // Localized titles to match (English + Korean UI)
    var actionTitles: [String] {
        action == "photo" ? ["Take Photo", "사진 찍기"] : ["Scan Documents", "문서 스캔"]
    }
}

// Mirror output to a log file so runs launched via `open` (detached from any
// terminal) can still be inspected.
let logPath = "/tmp/continuitycapture.log"
let logQueue: FileHandle? = {
    FileManager.default.createFile(atPath: logPath, contents: nil)
    return FileHandle(forWritingAtPath: logPath)
}()
func emit(_ s: String, to h: FileHandle) {
    let d = (s + "\n").data(using: .utf8)!
    h.write(d)
    logQueue?.write(d)
}
func log(_ s: String) { emit(s, to: FileHandle.standardOutput) }
func warn(_ s: String) { emit(s, to: FileHandle.standardError) }

// MARK: - Receiver text view

final class CaptureTextView: NSTextView {
    var logCount = 0
    var onMenuBuilt: ((NSMenu) -> Void)?

    // AppKit calls this on right-click before presenting the context menu;
    // capture the menu object so we can inspect what the system appends.
    override func menu(for event: NSEvent) -> NSMenu? {
        let m = super.menu(for: event)
        warn("menu(for:) built: \(m?.items.count ?? -1) items")
        if let m { onMenuBuilt?(m) }
        return m
    }

    override func validRequestor(forSendType sendType: NSPasteboard.PasteboardType?,
                                 returnType: NSPasteboard.PasteboardType?) -> Any? {
        if logCount < 12 {
            logCount += 1
            warn("validRequestor: send=\(sendType?.rawValue ?? "-") return=\(returnType?.rawValue ?? "-")")
        }
        if let rt = returnType,
           NSImage.imageTypes.contains(rt.rawValue) || rt.rawValue == "com.adobe.pdf" {
            return self
        }
        return super.validRequestor(forSendType: sendType, returnType: returnType)
    }
}

// Borderless windows refuse key status by default; the services/Continuity
// machinery only consults the responder chain of the key window.
final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

// MARK: - App delegate

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTextViewDelegate {
    let config = Config.parse()
    var window: NSWindow!
    var textView: CaptureTextView!
    var menu: NSMenu!
    var invoked = false      // we fired an import action
    var received = false     // a capture arrived and was saved

    func applicationWillFinishLaunching(_ note: Notification) {
        // Menu-bar route (the path Preview itself uses): a File menu item with
        // the Continuity Camera identifier; the system expands it into the
        // device list when the menu opens.
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        appItem.submenu = NSMenu(title: "ContinuityCapture")
        appItem.submenu!.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        mainMenu.addItem(appItem)
        let fileItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        let magic = NSMenuItem(title: "Import from Device", action: nil, keyEquivalent: "")
        magic.identifier = NSMenuItem.importFromDeviceIdentifier
        fileMenu.addItem(magic)
        fileItem.submenu = fileMenu
        mainMenu.addItem(fileItem)
        NSApp.mainMenu = mainMenu
    }

    func applicationDidFinishLaunching(_ note: Notification) {
        NSApp.setActivationPolicy(config.accessory ? .accessory : .regular)
        NSApp.activate(ignoringOtherApps: true)

        let returnTypes = NSImage.imageTypes.map { NSPasteboard.PasteboardType($0) }
            + [NSPasteboard.PasteboardType("com.adobe.pdf")]
        NSApp.registerServicesMenuSendTypes([], returnTypes: returnTypes)

        // Near-invisible key window hosting the auto-supported text view.
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let rect = NSRect(x: screen.midX - 150, y: screen.midY - 60, width: 300, height: 120)
        window = KeyableWindow(contentRect: rect, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.alphaValue = 0.02
        window.level = .floating

        textView = CaptureTextView(frame: NSRect(x: 0, y: 0, width: 300, height: 120))
        textView.isRichText = true
        textView.isEditable = true
        textView.importsGraphics = true      // required to accept image data
        textView.allowsImageEditing = false
        textView.delegate = self
        window.contentView = textView
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(textView)

        // Watch for the capture arriving as a text attachment.
        NotificationCenter.default.addObserver(self, selector: #selector(textStorageDidChange(_:)),
                                               name: NSTextStorage.didProcessEditingNotification,
                                               object: textView.textStorage)

        // The system capture panel ("Waiting for iPhone…") belongs to this app;
        // if it closes without delivering data, the user cancelled — exit.
        NotificationCenter.default.addObserver(self, selector: #selector(someWindowClosed(_:)),
                                               name: NSWindow.willCloseNotification, object: nil)

        // Hard exit so we never linger in the background.
        DispatchQueue.main.asyncAfter(deadline: .now() + config.captureTimeout) { [weak self] in
            if self?.received != true {
                warn("timeout: no capture received in \(Int(self?.config.captureTimeout ?? 0))s")
                NSApp.terminate(nil)
            }
        }

        if config.contextMenuMode {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { self.popImportMenu() }
        } else if config.selfTest {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { self.selfTest() }
        } else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { self.triggerFromMainMenu(attempt: 1) }
        }
    }

    /// Headless trigger: the system attaches the device submenu to the magic
    /// menu item at launch; update() populates it without any menu display.
    /// The submenu appears asynchronously, so poll from 0.2s up to ~3s and
    /// fire the moment it is ready instead of waiting a fixed delay.
    func triggerFromMainMenu(attempt: Int) {
        func retryOrFail(_ reason: String) {
            if attempt < 15 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self.triggerFromMainMenu(attempt: attempt + 1)
                }
            } else {
                warn("\(reason) — device not nearby/unlocked?")
                NSSound(named: "Basso")?.play()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { NSApp.terminate(nil) }
            }
        }

        guard let fileMenu = NSApp.mainMenu?.item(at: 1)?.submenu,
              let magic = fileMenu.items.first(where: { $0.submenu != nil }),
              let sub = magic.submenu else {
            retryOrFail("import submenu never attached")
            return
        }
        sub.update()

        var best: Int?
        outer: for pass in 0..<2 {
            for (i, item) in sub.items.enumerated() {
                guard !item.isSeparatorItem, item.isEnabled,
                      config.actionTitles.contains(item.title) else { continue }
                if pass == 0 && !sectionMatchesDevice(owner: sub, idx: i) { continue }
                best = i; break outer
            }
        }
        guard let idx = best else {
            retryOrFail("no available '\(config.actionTitles[0])' item")
            return
        }
        log("ready after \(attempt) attempt(s) (~\(Double(attempt) * 0.2)s)")
        let item = sub.items[idx]
        log("firing '\(item.title)' (index \(idx)) action=\(item.action.map(String.init(describing:)) ?? "nil") target=\(item.target.map { String(describing: type(of: $0)) } ?? "nil")")
        invoked = true
        sub.performActionForItem(at: idx)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { self.dumpWindows() }
    }

    func dumpNamed(_ m: NSMenu) {
        log("submenu contents: " + describe(m))
    }

    /// Probe whether the Continuity Camera item can be expanded and fired
    /// without displaying the menu at all.
    func selfTest() {
        guard let fileMenu = NSApp.mainMenu?.item(at: 1)?.submenu else { return }
        log("before update(): \(describe(fileMenu))")
        fileMenu.update()
        log("after update(): \(describe(fileMenu))")
        for item in fileMenu.items where item.submenu != nil {
            item.submenu!.update()
            log("submenu '\(item.title)' after update(): \(describe(item.submenu!))")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            log("after 1.5s: \(self.describe(fileMenu))")
            for item in fileMenu.items where item.submenu != nil {
                log("  submenu '\(item.title)': \(self.describe(item.submenu!))")
            }
            NSApp.terminate(nil)
        }
    }

    func describe(_ m: NSMenu) -> String {
        m.items.map { "'\($0.title)'\($0.submenu != nil ? "+sub" : "")\($0.isEnabled ? "" : "(off)")" }.joined(separator: ", ")
    }

    // MARK: menu popup

    func popImportMenu() {
        textView.onMenuBuilt = { [weak self] m in
            guard let self else { return }
            self.menu = m
            m.delegate = self
            m.allowsContextMenuPlugIns = true
        }

        let t = Timer(timeInterval: 0.4, target: self, selector: #selector(menuTick(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(t, forMode: .common)
        RunLoop.main.add(t, forMode: .eventTracking)

        // Route a right-click through the normal event path so AppKit itself
        // builds and presents the context menu (plugins are appended only on
        // this path on modern macOS).
        let pt = NSPoint(x: 150, y: 60)
        func mouse(_ type: NSEvent.EventType) -> NSEvent {
            NSEvent.mouseEvent(with: type, location: pt,
                               modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                               windowNumber: window.windowNumber, context: nil,
                               eventNumber: Int.random(in: 1000...9999), clickCount: 1, pressure: 1)!
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.window.sendEvent(mouse(.rightMouseUp))
        }
        window.sendEvent(mouse(.rightMouseDown))
    }

    var ticks = 0
    @objc func menuTick(_ t: Timer) {
        ticks += 1
        if invoked || received { t.invalidate(); return }
        guard menu != nil else {
            log("tick \(ticks): context menu not built yet")
            if ticks >= 8 { t.invalidate(); if config.dryRun { NSApp.terminate(nil) } }
            return
        }

        if config.dryRun {
            if ticks == 1 { dumpMenu() }
            if ticks >= Int(config.dryRunHold / 0.4) {
                dumpMenu()
                t.invalidate()
                menu.cancelTracking()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { NSApp.terminate(nil) }
            }
            return
        }

        if config.autoTrigger {
            if tryTrigger() {
                t.invalidate()
            } else if ticks > 25 { // ~10s: give up on auto, leave menu for manual click
                warn("auto-trigger: target item not found; leaving menu open for manual selection")
                t.invalidate()
            }
        }
    }

    func dumpWindows() {
        guard let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] else {
            log("windows: <unavailable>"); return
        }
        let mine = list.filter { ($0["kCGWindowOwnerPID"] as? Int32) == getpid() }
        for w in mine {
            let layer = w["kCGWindowLayer"] as? Int ?? -1
            let b = w["kCGWindowBounds"] as? [String: Any] ?? [:]
            log("window: layer=\(layer) bounds=\(b["Width"] ?? "?")x\(b["Height"] ?? "?") at (\(b["X"] ?? "?"),\(b["Y"] ?? "?"))")
        }
    }

    func dumpMenu() {
        log("--- tick \(ticks) ---")
        dumpWindows()
        for (i, item) in menu.items.enumerated() {
            log("[\(i)] '\(item.title)' id=\(item.identifier?.rawValue ?? "-") enabled=\(item.isEnabled) sep=\(item.isSeparatorItem) hasSub=\(item.submenu != nil)")
            if let sub = item.submenu {
                for (j, si) in sub.items.enumerated() {
                    log("    [\(i).\(j)] '\(si.title)' enabled=\(si.isEnabled) sep=\(si.isSeparatorItem) action=\(si.action.map(String.init(describing:)) ?? "-") target=\(si.target.map { String(describing: type(of: $0)) } ?? "-")")
                }
            }
        }
    }

    /// Find the device action item and invoke it. Returns true once fired.
    func tryTrigger() -> Bool {
        var candidates: [(NSMenu, Int)] = []
        for (i, item) in menu.items.enumerated() {
            if let sub = item.submenu {
                for j in sub.items.indices { candidates.append((sub, j)) }
            }
            candidates.append((menu, i))
        }
        // Pass 1: preferred device section; pass 2: anywhere.
        for pass in 0..<2 {
            for (owner, idx) in candidates {
                let item = owner.items[idx]
                guard !item.isSeparatorItem, item.isEnabled,
                      config.actionTitles.contains(item.title) else { continue }
                if pass == 0 && !sectionMatchesDevice(owner: owner, idx: idx) { continue }
                invoked = true
                menu.cancelTracking()
                log("invoking '\(item.title)' (pass \(pass))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    owner.performActionForItem(at: idx)
                }
                return true
            }
        }
        return false
    }

    /// Device sections are (header, actions...) separated by separator items.
    /// Walk upward from idx until a separator; the section matches when any
    /// item above (the device-name header) contains the hint.
    func sectionMatchesDevice(owner: NSMenu, idx: Int) -> Bool {
        var i = idx - 1
        while i >= 0 {
            let it = owner.items[i]
            if it.isSeparatorItem { return false }
            if it.title.localizedCaseInsensitiveContains(config.deviceHint) { return true }
            i -= 1
        }
        return false
    }

    @objc func someWindowClosed(_ note: Notification) {
        guard invoked, !received, let w = note.object as? NSWindow, w !== window else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !self.received {
                warn("capture panel closed without data (cancelled)")
                NSApp.terminate(nil)
            }
        }
    }

    func menuDidClose(_ menu: NSMenu) {
        // Menu dismissed without our action (user pressed Esc / clicked away).
        if !invoked && !config.dryRun {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if !self.invoked && !self.received { NSApp.terminate(nil) }
            }
        }
    }

    // MARK: capture arrival & saving

    @objc func textStorageDidChange(_ note: Notification) {
        guard !received, let storage = textView.textStorage, storage.length > 0 else { return }
        // Defer out of the editing pass before mutating/reading further.
        DispatchQueue.main.async { self.extractAttachments() }
    }

    func extractAttachments() {
        guard !received, let storage = textView.textStorage else { return }
        storage.enumerateAttribute(.attachment, in: NSRange(location: 0, length: storage.length)) { value, _, stop in
            guard let att = value as? NSTextAttachment else { return }
            if saveAttachment(att) { stop.pointee = true }
        }
    }

    func saveAttachment(_ att: NSTextAttachment) -> Bool {
        var data: Data?
        var suggestedName: String?
        if let fw = att.fileWrapper, fw.isRegularFile {
            data = fw.regularFileContents
            suggestedName = fw.preferredFilename
        } else if let contents = att.contents {
            data = contents
        }
        guard let d = data, !d.isEmpty else { return false }
        return saveData(d, suggestedName: suggestedName)
    }

    func saveData(_ d: Data, suggestedName: String?) -> Bool {
        let fm = FileManager.default
        try? fm.createDirectory(atPath: config.outDir, withIntermediateDirectories: true)

        let stamp: String = {
            let f = DateFormatter()
            f.dateFormat = "yyyyMMdd_HHmmss"
            return f.string(from: Date())
        }()

        // Sniff format from magic bytes; fall back to the wrapper's filename.
        var ext = "bin"
        var base = config.action == "scan" ? "Scan_\(stamp)" : "IMG_\(stamp)"
        if d.starts(with: [0xFF, 0xD8, 0xFF]) { ext = "jpg" }
        else if d.starts(with: [0x89, 0x50, 0x4E, 0x47]) { ext = "png" }
        else if d.starts(with: [0x25, 0x50, 0x44, 0x46]) { ext = "pdf"; base = "Scan_\(stamp)" }
        else if let name = suggestedName, let e = name.split(separator: ".").last { ext = String(e).lowercased() }

        // HEIC and other exotic formats: convert to JPEG for the photo flow.
        if ext == "bin" || ext == "heic" {
            if let rep = NSBitmapImageRep(data: d),
               let jpg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) {
                return write(jpg, to: "IMG_\(stamp)", ext: "jpg")
            }
        }
        return write(d, to: base, ext: ext)
    }

    func write(_ d: Data, to base: String, ext: String) -> Bool {
        let fm = FileManager.default
        var p = "\(config.outDir)/\(base).\(ext)"
        var n = 1
        while fm.fileExists(atPath: p) { p = "\(config.outDir)/\(base)-\(n).\(ext)"; n += 1 }
        do {
            try d.write(to: URL(fileURLWithPath: p), options: .atomic)
        } catch {
            warn("write failed: \(error.localizedDescription)")
            return false
        }
        received = true
        log("saved: \(p)")
        NSSound(named: "Glass")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { NSApp.terminate(nil) }
        return true
    }
}

// MARK: - main

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.run()
