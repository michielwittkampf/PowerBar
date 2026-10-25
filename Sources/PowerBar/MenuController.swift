import AppKit
import PowerBarCore

/// The dropdown: the live readings on top, an error row when reading fails,
/// then the Settings and Help submenus and Quit.
final class MenuController: NSObject, NSMenuDelegate {
    let menu = NSMenu()

    // Rows that change; created once, their titles are updated.
    private let smoothedItem = NSMenuItem()
    private let lastItem = NSMenuItem()
    private let peakItem = NSMenuItem()
    private let errorItem = NSMenuItem()
    private let infoItem = NSMenuItem()
    private let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")

    override init() {
        super.init()
        menu.delegate = self
        for item in [smoothedItem, lastItem, peakItem, errorItem, infoItem] {
            item.isEnabled = false
        }
        errorItem.isHidden = true
        [smoothedItem, lastItem, peakItem, errorItem].forEach(menu.addItem)
        menu.addItem(.separator())

        let settings = submenu("Settings")
        add("Edit Settings…", #selector(openSettings), key: ",", to: settings)
        settings.addItem(.separator())
        loginItem.target = self
        settings.addItem(loginItem)
        settings.addItem(.separator())
        settings.addItem(infoItem)

        let help = submenu("Help")
        add("Documentation (README on GitHub)", #selector(openDocs), to: help)
        add("About PowerBar", #selector(showAbout), to: help)

        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit PowerBar", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        update(smoother: nil, last: nil, settings: Settings())
    }

    private func submenu(_ title: String) -> NSMenu {
        let sub = NSMenu(title: title)
        menu.addItem(withTitle: title, action: nil, keyEquivalent: "").submenu = sub
        return sub
    }

    private func add(_ title: String, _ action: Selector, key: String = "", to menu: NSMenu) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: key).target = self
    }

    func update(smoother: Smoother?, last: Double?, settings: Settings) {
        smoothedItem.title = "Smoothed: \(formatWatts(smoother?.ema))"
        lastItem.title = "Last reading: \(formatWatts(last))"
        peakItem.title = "Peak since start: \(formatWatts(last == nil ? nil : smoother?.peak))"
        infoItem.attributedTitle = small(formatInfoLine(settings: settings))
    }

    /// An error stays in the main menu, not in a submenu; nil hides the row.
    func showError(_ text: String?) {
        errorItem.isHidden = text == nil
        errorItem.attributedTitle = small(text.map { "Error: \($0)" } ?? "")
    }

    private func small(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [.font: NSFont.menuFont(ofSize: NSFont.smallSystemFontSize)])
    }

    func menuWillOpen(_ menu: NSMenu) {
        loginItem.state = LoginItem.isEnabled ? .on : .off
    }

    // MARK: - Actions

    @objc private func openSettings() { ConfigFile.openInEditor() }

    @objc private func toggleLogin() { LoginItem.toggle() }

    @objc private func openDocs() { NSWorkspace.shared.open(Project.docs) }

    @objc private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)  // a menu bar app is never frontmost by itself
        let credits = NSMutableAttributedString(string: "Documentation on GitHub")
        credits.addAttribute(.link, value: Project.docs, range: NSRange(location: 0, length: credits.length))
        // "Version 0.5.0 (e972f45)": the commit the app was built from, set by build.sh.
        let commit = Bundle.main.object(forInfoDictionaryKey: "PowerBarCommit") as? String ?? ""
        NSApp.orderFrontStandardAboutPanel(options: [.credits: credits, .version: commit])
    }
}
