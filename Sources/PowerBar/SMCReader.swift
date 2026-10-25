import Foundation
import IOKit
import PowerBarCore

/// Reads the SMC key `PSTR` (total system power) straight from the AppleSMC
/// user client, without root, and hands the value in watts to `onSample` every interval.
final class SMCReader {
    static let key = "PSTR"

    enum Failure: LocalizedError {
        case noService, open(kern_return_t), call(kern_return_t), smc(key: String, result: UInt8), type(String)
        var errorDescription: String? {
            switch self {
            case .noService: return "AppleSMC not found"
            case .open(let kr): return "Cannot open AppleSMC (0x\(String(kr, radix: 16)))"
            case .call(let kr): return "SMC call failed (0x\(String(kr, radix: 16)))"
            case .smc(let key, let r): return "SMC key \(key) unavailable (0x\(String(r, radix: 16)))"
            case .type(let t): return "SMC key \(SMCReader.key) has unexpected type '\(t)'"
            }
        }
    }

    var onSample: (Double) -> Void = { _ in }
    private var connection: io_connect_t = 0
    private var size: UInt32 = 0
    private var type = ""
    private var timer: Timer?

    deinit { stop() }

    /// Opens the SMC, checks the key once and starts the timer.
    func start(intervalMs: Int) throws {
        stop()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard service != 0 else { throw Failure.noService }
        defer { IOObjectRelease(service) }
        let kr = IOServiceOpen(service, mach_task_self_, 0, &connection)
        guard kr == KERN_SUCCESS else { throw Failure.open(kr) }

        do {
            (size, type) = SMC.keyInfo(try call(SMC.request(key: Self.key, command: SMC.cmdReadKeyInfo)))
            guard SMC.decode(type: type, bytes: [UInt8](repeating: 0, count: Int(size))) != nil else {
                throw Failure.type(type)
            }
        } catch {
            stop()
            throw error
        }

        let t = Timer(timeInterval: Double(intervalMs) / 1000, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)  // keep ticking while the menu is open
        timer = t
        tick()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        if connection != 0 {
            IOServiceClose(connection)
            connection = 0
        }
    }

    private func tick() {
        guard let out = try? call(SMC.request(key: Self.key, command: SMC.cmdReadBytes, dataSize: size)),
              let watts = SMC.decode(type: type, bytes: SMC.bytes(out, size: size)) else { return }
        onSample(watts)
    }

    private func call(_ input: [UInt8]) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: SMC.structSize)
        var outputSize = output.count
        let kr = input.withUnsafeBytes { inp in
            output.withUnsafeMutableBytes { out in
                IOConnectCallStructMethod(connection, SMC.selector, inp.baseAddress, inp.count,
                                          out.baseAddress, &outputSize)
            }
        }
        guard kr == KERN_SUCCESS else { throw Failure.call(kr) }
        guard SMC.result(output) == 0 else { throw Failure.smc(key: Self.key, result: SMC.result(output)) }
        return output
    }
}
