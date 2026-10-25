import AppKit
import PowerBarCore

/// The number and the bolt in the menu bar, at a fixed width.
final class StatusItemController {
    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private var width = Settings().width

    // The default menu bar font, but with tabular (equally wide) digits.
    private let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .regular)

    init(menu: NSMenu) {
        item.button?.imagePosition = .imageTrailing  // bolt to the right of the number
        item.menu = menu
    }

    /// Shows `watts` (nil = "?"); `ok == false` swaps the bolt for a crossed-out one.
    func show(_ watts: Double?, ok: Bool = true) {
        guard let button = item.button else { return }
        button.attributedTitle = NSAttributedString(
            string: formatTitle(watts, width: width), attributes: [.font: font])
        let image = NSImage(systemSymbolName: ok ? "bolt.fill" : "bolt.slash",
                            accessibilityDescription: ok ? "power draw" : "power draw unavailable")
        image?.isTemplate = true
        button.image = image
    }

    /// A fixed length, measured on the widest possible title, so the icons to the
    /// left never shift.
    func fixWidth(digits: Int) {
        width = digits
        item.length = NSStatusItem.variableLength
        show(pow(10, Double(digits)) - 1)
        if let button = item.button {
            item.length = ceil(button.fittingSize.width)
        }
    }
}
