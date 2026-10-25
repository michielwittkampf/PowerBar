import AppKit
import PowerBarCore

/// Wires the pieces together: SMC reading → smoothing → menu bar title and dropdown.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let reader = SMCReader()
    private let menu = MenuController()
    private var statusItem: StatusItemController!
    private var settings = Settings()
    private var smoother = Smoother(settings: Settings())
    private var last: Double?  // last plausible reading in W
    private var retry: DispatchWorkItem?

    func applicationDidFinishLaunching(_ note: Notification) {
        statusItem = StatusItemController(menu: menu.menu)
        menu.onReload = { [weak self] in self?.restart() }
        reader.onSample = { [weak self] in self?.handle($0) }
        // Start fresh on wake: the smoothing should not average across sleep.
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(restart), name: NSWorkspace.didWakeNotification, object: nil)
        restart()
    }

    @objc private func restart() {
        reader.stop()
        retry?.cancel()  // one pending retry at most; a successful reload needs none
        settings = Settings.load()
        smoother = Smoother(settings: settings)
        last = nil
        statusItem.fixWidth(digits: settings.width)
        statusItem.show(nil)  // before start(): its first reading arrives synchronously
        menu.showError(nil)
        do {
            try reader.start(intervalMs: settings.intervalMs)
        } catch {
            statusItem.show(nil, ok: false)
            menu.showError(error.localizedDescription)
            let work = DispatchWorkItem { [weak self] in self?.restart() }
            retry = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 60, execute: work)
        }
        menu.update(smoother: smoother, last: last, settings: settings)
    }

    private func handle(_ watts: Double) {
        guard settings.isPlausible(watts) else { return }
        last = watts
        if smoother.add(watts) {
            statusItem.show(smoother.shown)
        }
        menu.update(smoother: smoother, last: last, settings: settings)
    }
}
