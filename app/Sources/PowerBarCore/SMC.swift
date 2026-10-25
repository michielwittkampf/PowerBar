import Foundation

/// The byte layout of the AppleSMC user client's `SMCParamStruct` (80 bytes, C layout)
/// and the decoding of key values. The IOKit call itself lives in the app (`SMCReader`).
public enum SMC {
    public static let structSize = 80
    public static let selector: UInt32 = 2      // kSMCHandleYPCEvent
    public static let cmdReadBytes: UInt8 = 5
    public static let cmdReadKeyInfo: UInt8 = 9

    // Offsets into SMCParamStruct.
    static let keyOffset = 0
    static let dataSizeOffset = 28   // keyInfo.dataSize
    static let dataTypeOffset = 32   // keyInfo.dataType
    static let resultOffset = 40
    static let commandOffset = 42    // data8
    static let bytesOffset = 48      // 32 bytes of value

    /// "PSTR" -> 0x50535452
    public static func fourCC(_ s: String) -> UInt32 {
        s.utf8.prefix(4).reduce(0) { $0 << 8 | UInt32($1) }
    }

    public static func string(fourCC v: UInt32) -> String {
        String(decoding: [24, 16, 8, 0].map { UInt8(truncatingIfNeeded: v >> $0) }, as: UTF8.self)
    }

    /// Input struct for a key-info request (`command` 9) or a read (`command` 5, with the size from key info).
    public static func request(key: String, command: UInt8, dataSize: UInt32 = 0) -> [UInt8] {
        var b = [UInt8](repeating: 0, count: structSize)
        put(&b, keyOffset, fourCC(key))
        put(&b, dataSizeOffset, dataSize)
        b[commandOffset] = command
        return b
    }

    /// The SMC's own result code; 0 means success (e.g. 0x84 = key not found).
    public static func result(_ out: [UInt8]) -> UInt8 { out[resultOffset] }

    /// From a key-info reply: the value's size and type (e.g. "flt ").
    public static func keyInfo(_ out: [UInt8]) -> (size: UInt32, type: String) {
        (get(out, dataSizeOffset), string(fourCC: get(out, dataTypeOffset)))
    }

    /// From a read reply: the value's bytes.
    public static func bytes(_ out: [UInt8], size: UInt32) -> [UInt8] {
        Array(out[bytesOffset..<bytesOffset + min(Int(size), 32)])
    }

    /// Value bytes -> number. Only the type we need: PSTR is a little-endian
    /// float32 (`flt `) on Apple Silicon. Other types give nil.
    public static func decode(type: String, bytes: [UInt8]) -> Double? {
        guard type == "flt ", bytes.count == 4 else { return nil }
        let bits = bytes.withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) }
        let value = Double(Float(bitPattern: UInt32(littleEndian: bits)))
        return value.isFinite ? value : nil
    }

    private static func put(_ b: inout [UInt8], _ offset: Int, _ v: UInt32) {
        withUnsafeBytes(of: v.littleEndian) { b.replaceSubrange(offset..<offset + 4, with: $0) }
    }

    private static func get(_ b: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(littleEndian: b[offset..<offset + 4].withUnsafeBytes { $0.loadUnaligned(as: UInt32.self) })
    }
}
