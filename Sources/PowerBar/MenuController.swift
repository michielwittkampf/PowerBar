import AppKit
import PowerBarCore

/// The dropdown: live values, an info row, and the actions.
final class MenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()
    var onReload: () -> Void = {}

    // Rows that change; created once, their titles are updated.
    private let smoothedItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let peakItem = NSMenuItem()
    private let infoItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    override init() {
        super.init()
        menu.delegate = self
        for item in [smoothedItem, lastItem, peakItem, infoItem] {
            item.isEnabled = false
            menu.addItem(item)
            if item === peakItem { menu.addItem(.separator()) }
        }
        menu.addItem(.separator())
        add("Settings…", #selector(openSettings), key: ",")
        add("Reload Settings", #selector(reload), key: "r")
        loginItem.target = self
        menu.addItem(loginItem)
        menu.addItem(.separator())
        add("Documentation", #selector(openDocs))
        add("About PowerBar", #selector(showAbout))
        menu.addItem(withTitle: "Quit PowerBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        update(smoother: nil, last: nil, settings: Settings())
    }

    private func add(_ title: String, _ action: Selector, key: String = "") {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }

    func update(smoother: Smoother?, last: Sample?, settings: Settings) {
        smoothedItem.title = "Smoothed: \(formatWatts(smoother?.ema))"
        lastItem.title = "Last reading: \(formatWatts(last?.power))"
        peakItem.title = "Peak since start: \(formatWatts(last == nil ? nil : smoother?.peak))"
        if let last {
            showInfo(formatSourceLine(source: last.source, settings: settings))
        }
    }

    /// The small grey row: the source and settings, or an error.
    func showInfo(_ text: String) {
        infoItem.attributedTitle = NSAttributedString(
            string: text, attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)])
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func reload() { onReload() }

    @objc private func openSettings() { ConfigFile.openInEditor() }

    @objc private func toggleLogin() { LoginItem.toggle() }

    @objc private func openDocs() { NSWorkspace.shared.open(Project.docs) }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)  // a menu bar app is never frontmost by itself
        let credits = NSMutableAttributedString(string: "Documentation on GitHub")
        credits.addAttribute(.link, value: Project.docs, range: NSRange(location: 0, length: credits.length))
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits])
    }
}
