import AppKit
import ServiceManagement

/// Open at Login through `SMAppService.mainApp`. Only works from the .app bundle.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func toggle() {
        let service = SMAppService.mainApp
        do {
            if isEnabled {
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
