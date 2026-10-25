import Foundation
import PowerBarCore

/// Calls `onChange` on the main queue shortly after the settings file changes.
///
/// It watches the folder as well as the file: most editors save by writing a new
/// file and renaming it over the old one, which only the folder sees, while an
/// in-place write (`echo >> config`) only shows up on the file. The file watch is
/// re-armed after every change, because a save may have replaced the file.
final class ConfigWatcher {
    var onChange: () -> Void = {}
    private var folderSource: DispatchSourceFileSystemObject?
    private var fileSource: DispatchSourceFileSystemObject?
    private var pending: DispatchWorkItem?

    deinit {
        folderSource?.cancel()
        fileSource?.cancel()
    }

    /// Creates `~/.config/powerbar` if needed (a folder can only be watched once
    /// it exists) and starts watching.
    func start() {
        let folder = Settings.path.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        folderSource = watch(folder.path)
        fileSource = watch(Settings.path.path)
    }

    private func watch(_ path: String) -> DispatchSourceFileSystemObject? {
        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else { return nil }  // e.g. no config file yet; the folder watch covers that
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd, eventMask: [.write, .extend, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.changed() }
        source.setCancelHandler { close(fd) }
        source.resume()
        return source
    }

    /// One save often fires several events; act once, half a second after the last.
    private func changed() {
        pending?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.fileSource?.cancel()
            self.fileSource = self.watch(Settings.path.path)
            self.onChange()
        }
        pending = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }
}
