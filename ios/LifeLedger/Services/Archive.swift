import Foundation

// Standard ZIP (stored when writing, stored or raw DEFLATE when reading).
// Reads the central directory so Java ZIP archives with data descriptors work.
enum ZipArchive {
    static let maxEntry = 512 * 1024 * 1024
    static let maxTotal = 1024 * 1024 * 1024
    static func checksum(_ data: Data) -> UInt32 {
        data.withUnsafeBytes { UInt32(crc32(0, $0.bindMemory(to: Bytef.self).baseAddress, uInt(data.count))) }
    }
    static func safePath(_ path: String) -> Bool {
        !path.isEmpty && !path.hasPrefix("/") && !path.contains("\\") && !path.contains("\0") &&
        !path.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
    }
    static func pack(_ files: [String: Data]) throws -> Data {
        guard files.count < 65535 else { throw LedgerError.invalidBackup }
        var output = Data(), central = Data()
        for (path, bytes) in files.sorted(by: { $0.key < $1.key }) {
            guard safePath(path), bytes.count <= maxEntry else { throw LedgerError.invalidBackup }
            let name = Data(path.utf8), offset = UInt32(output.count), crc = checksum(bytes)
            guard name.count <= 65535 else { throw LedgerError.invalidBackup }
            output.le(UInt32(0x04034b50)); output.le(UInt16(20)); output.le(UInt16(0x800))
            output.le(UInt16(0)); output.le(UInt16(0)); output.le(UInt16(0)); output.le(crc)
            output.le(UInt32(bytes.count)); output.le(UInt32(bytes.count)); output.le(UInt16(name.count)); output.le(UInt16(0))
            output.append(name); output.append(bytes)
            central.le(UInt32(0x02014b50)); central.le(UInt16(20)); central.le(UInt16(20)); central.le(UInt16(0x800))
            central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(crc)
            central.le(UInt32(bytes.count)); central.le(UInt32(bytes.count)); central.le(UInt16(name.count))
            central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt16(0)); central.le(UInt32(0)); central.le(offset)
            central.append(name)
        }
        guard output.count + central.count <= maxTotal else { throw LedgerError.invalidBackup }
        let offset = UInt32(output.count)
        output.append(central)
        output.le(UInt32(0x06054b50)); output.le(UInt16(0)); output.le(UInt16(0))
        output.le(UInt16(files.count)); output.le(UInt16(files.count)); output.le(UInt32(central.count)); output.le(offset); output.le(UInt16(0))
        return output
    }
    static func unpack(_ data: Data) throws -> [String: Data] {
        guard data.count >= 22, data.count <= maxTotal else { throw LedgerError.invalidBackup }
        var end: Int?
        for index in stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1) {
            if try data.u32(index) == 0x06054b50, index + 22 + Int(try data.u16(index + 20)) == data.count { end = index; break }
        }
        guard let end, try data.u16(end + 4) == 0, try data.u16(end + 6) == 0 else { throw LedgerError.invalidBackup }
        let count = Int(try data.u16(end + 10))
        guard count == Int(try data.u16(end + 8)) else { throw LedgerError.invalidBackup }
        var cursor = Int(try data.u32(end + 16)), result: [String: Data] = [:], total = 0
        for _ in 0..<count {
            guard try data.u32(cursor) == 0x02014b50 else { throw LedgerError.invalidBackup }
            let flags = try data.u16(cursor + 8), method = try data.u16(cursor + 10), crc = try data.u32(cursor + 16)
            let compressed = Int(try data.u32(cursor + 20)), size = Int(try data.u32(cursor + 24))
            let nameCount = Int(try data.u16(cursor + 28)), extra = Int(try data.u16(cursor + 30)), comment = Int(try data.u16(cursor + 32))
            let local = Int(try data.u32(cursor + 42))
            guard flags & 1 == 0, size <= maxEntry, compressed <= maxEntry,
                  let name = String(data: try data.slice(cursor + 46, nameCount), encoding: .utf8) else { throw LedgerError.invalidBackup }
            cursor += 46 + nameCount + extra + comment
            if name.hasSuffix("/") { continue }
            guard safePath(name), result[name] == nil, try data.u32(local) == 0x04034b50 else { throw LedgerError.invalidBackup }
            let start = local + 30 + Int(try data.u16(local + 26)) + Int(try data.u16(local + 28))
            let payload = try data.slice(start, compressed)
            total += size
            guard total <= maxTotal else { throw LedgerError.invalidBackup }
            let bytes: Data
            if method == 0 { bytes = payload }
            else if method == 8 { bytes = try inflateRaw(payload, size: size) }
            else { throw LedgerError.invalidBackup }
            guard bytes.count == size, checksum(bytes) == crc else { throw LedgerError.invalidBackup }
            result[name] = bytes
        }
        return result
    }
    static func inflateRaw(_ input: Data, size: Int) throws -> Data {
        var stream = z_stream()
        guard inflateInit2_(&stream, -MAX_WBITS, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw LedgerError.invalidBackup }
        defer { inflateEnd(&stream) }
        var output = Data(count: max(1, size))
        let outputCount = output.count
        let result = output.withUnsafeMutableBytes { out in
            input.withUnsafeBytes { source in
                stream.next_in = UnsafeMutablePointer(mutating: source.bindMemory(to: Bytef.self).baseAddress)
                stream.avail_in = uInt(input.count)
                stream.next_out = out.bindMemory(to: Bytef.self).baseAddress
                stream.avail_out = uInt(outputCount)
                return inflate(&stream, Z_FINISH)
            }
        }
        guard result == Z_STREAM_END, stream.total_out == size else { throw LedgerError.invalidBackup }
        return output.prefix(size)
    }
}

private extension Data {
    mutating func le<T: FixedWidthInteger>(_ value: T) { var value = value.littleEndian; Swift.withUnsafeBytes(of: &value) { append(contentsOf: $0) } }
    func slice(_ offset: Int, _ length: Int) throws -> Data {
        guard offset >= 0, length >= 0, offset <= count, length <= count - offset else { throw LedgerError.invalidBackup }
        return subdata(in: offset..<(offset + length))
    }
    func u16(_ offset: Int) throws -> UInt16 { let bytes = try slice(offset, 2); return UInt16(bytes[0]) | UInt16(bytes[1]) << 8 }
    func u32(_ offset: Int) throws -> UInt32 { let bytes = try slice(offset, 4); return bytes.enumerated().reduce(0) { $0 | UInt32($1.element) << ($1.offset * 8) } }
}
