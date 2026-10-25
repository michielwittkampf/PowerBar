import AppKit
import PowerBarCore
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let reader = MacmonReader()
    private var settings = Settings()
    private var smoother = Smoother(settings: Settings())
    private var last: Sample?

    // Menu rows that change; created once, their titles are updated.
    private let smoothedItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let peakItem = NSMenuItem()
    private let cpuItem = NSMenuItem()
    private let gpuItem = NSMenuItem()
    private let aneItem = NSMenuItem()
    private let ramItem = NSMenuItem()
    private let sourceItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    // The default menu bar font, but with tabular (equally wide) digits.
    private let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.imagePosition = .imageTrailing  // bolt to the right of the number
        statusItem.menu = buildMenu()

        reader.onLine = { [weak self] in self?.handle($0) }
        reader.onExit = { [weak self] in self?.scheduleRestart() }
        // macmon may stall or exit across sleep; start it fresh on wake.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(restart), name: NSWorkspace.didWakeNotification, object: nil)
        restart()
    }

    // MARK: - Data

    @objc private func restart() {
        reader.stop()
        settings = Settings.load()
        smoother = Smoother(settings: settings)
        last = nil
        fixWidth()
        guard let macmon = MacmonReader.find() else {
            setTitle(nil, symbol: "bolt.slash")
            sourceItem.title = "macmon not found. Install with: brew install macmon"
            scheduleRestart(after: 60)
            return
        }
        do {
            try reader.start(executable: macmon, intervalMs: settings.intervalMs)
            setTitle(nil, symbol: "bolt.fill")
        } catch {
            setTitle(nil, symbol: "bolt.slash")
            sourceItem.title = "Error: \(error.localizedDescription)"
            scheduleRestart()
        }
    }

    private func scheduleRestart(after seconds: Double = 3) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.restart() }
    }

    private func handle(_ line: Data) {
        guard let sample = Sample(json: line), settings.isPlausible(sample.power) else { return }
        last = sample
        if smoother.add(sample.power) {
            setTitle(smoother.shown, symbol: "bolt.fill")
        }
        updateMenu()
    }

    // MARK: - Menu bar title

    private func setTitle(_ watts: Double?, symbol: String) {
        guard let button = statusItem.button else { return }
        button.attributedTitle = NSAttributedString(
            string: formatTitle(watts, width: settings.width), attributes: [.font: font])
        let image = NSImage(systemSymbolName: symbol, accessibilityDescription: "power")
        image?.isTemplate = true
        button.image = image
    }

    /// A fixed length, measured on the widest possible title, so the icons to the
    /// left never shift.
    private func fixWidth() {
        statusItem.length = NSStatusItem.variableLength
        setTitle(pow(10, Double(settings.width)) - 1, symbol: "bolt.fill")
        if let button = statusItem.button {
            statusItem.length = ceil(button.fittingSize.width)
        }
    }

    // MARK: - Dropdown

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        for item in [smoothedItem, lastItem, peakItem, cpuItem, gpuItem, aneItem, ramItem, sourceItem] {
            item.isEnabled = false
        }
        [smoothedItem, lastItem, peakItem].forEach(menu.addItem)
        menu.addItem(.separator())
        [cpuItem, gpuItem, aneItem, ramItem].forEach(menu.addItem)
        menu.addItem(.separator())
        menu.addItem(sourceItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Settings…", action: #selector(openSettings), keyEquivalent: ",").target = self
        menu.addItem(withTitle: "Reload Settings", action: #selector(restart), keyEquivalent: "r").target = self
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PowerBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        updateMenu()
        return menu
    }

    private func updateMenu() {
        func w(_ x: Double?) -> String { x.map { String(format: "%.1f W", $0) } ?? "–" }
        smoothedItem.title = "Smoothed: \(w(smoother.ema))"
        lastItem.title = "Last reading: \(w(last?.power))"
        peakItem.title = "Peak since start: \(w(last == nil ? nil : smoother.peak))"
        cpuItem.title = "CPU: \(w(last?.cpu))"
        gpuItem.title = "GPU: \(w(last?.gpu))"
        aneItem.title = "ANE: \(w(last?.ane))"
        ramItem.title = "RAM: \(w(last?.ram))"
        if let last {
            let s = settings
            let text = "Source: \(last.source) · smoothing \(fmt(s.tau))s · threshold ±\(fmt(s.stepAbs))W/\(Int((s.stepRel * 100).rounded()))%"
            sourceItem.attributedTitle = NSAttributedString(
                string: text, attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)])
        }
    }

    private func fmt(_ x: Double) -> String { String(format: "%g", x) }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func openSettings() {
        let url = Settings.path
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let example = Bundle.main.url(forResource: "config", withExtension: "example")
            let text = example.flatMap { try? String(contentsOf: $0, encoding: .utf8) } ?? ""
            try? text.write(to: url, atomically: true, encoding: .utf8)
        }
        let textEdit = URL(fileURLWithPath: "/System/Applications/TextEdit.app")
        NSWorkspace.shared.open([url], withApplicationAt: textEdit, configuration: NSWorkspace.OpenConfiguration())
    }

    @objc private func toggleLogin() {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
            } else {
                try service.register()
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.messageText = "Could not change Open at Login"
            alert.runModal()
        }
    }
}
