import Foundation

/// Runs `macmon pipe` and hands every output line to `onLine` on the main queue.
final class MacmonReader {
    // An app started from Finder has no Homebrew on its PATH, so look in the usual places.
    static let candidates = [
        "~/.homebrew/bin/macmon",
        "/opt/homebrew/bin/macmon",
        "/usr/local/bin/macmon",
    ].map { NSString(string: $0).expandingTildeInPath }

    static func find() -> String? {
        let fm = FileManager.default
        if let p = candidates.first(where: { fm.isExecutableFile(atPath: $0) }) { return p }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        return path.split(separator: ":")
            .map { "\($0)/macmon" }
            .first { fm.isExecutableFile(atPath: $0) }
    }

    var onLine: (Data) -> Void = { _ in }
    var onExit: () -> Void = {}
    private var process: Process?
    private var buffer = Data()

    func start(executable: String, intervalMs: Int) throws {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: executable)
        p.arguments = ["pipe", "-i", String(intervalMs)]
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        out.fileHandleForReading.readabilityHandler = { [weak self] h in
            let chunk = h.availableData
            DispatchQueue.main.async { self?.receive(chunk) }
        }
        p.terminationHandler = { [weak self] _ in
            out.fileHandleForReading.readabilityHandler = nil
            DispatchQueue.main.async {
                guard let self, self.process === p else { return }  // not after stop()
                self.process = nil
                self.onExit()
            }
        }
        buffer.removeAll()
        try p.run()
        process = p
    }

    func stop() {
        guard let p = process else { return }
        process = nil
        p.terminate()
    }

    private func receive(_ chunk: Data) {
        buffer.append(chunk)
        while let nl = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let line = buffer[buffer.startIndex..<nl]
            buffer.removeSubrange(buffer.startIndex...nl)
            if !line.isEmpty { onLine(Data(line)) }
        }
    }
}
