import AppKit
import PowerBarCore

/// The settings file `~/.config/powerbar/config`, shared with the SwiftBar plugin.
enum ConfigFile {
    /// Opens the file in TextEdit, first creating it from the bundled
    /// `config.example` if it doesn't exist yet. An existing file is never touched.
    static func openInEditor() {
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
}
