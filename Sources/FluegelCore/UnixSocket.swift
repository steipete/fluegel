import Darwin
import Foundation

public enum UnixSocket {
    /// `SO_NOSIGPIPE` makes a later `write` return `EPIPE` after the peer closes.
    /// Set it while the socket is still connected. Once the peer is gone,
    /// `setsockopt` returns `EINVAL` and `write` can still raise `SIGPIPE`.
    public static func disableSIGPIPE(_ descriptor: Int32) throws {
        var enabled: Int32 = 1
        guard setsockopt(
            descriptor,
            SOL_SOCKET,
            SO_NOSIGPIPE,
            &enabled,
            socklen_t(MemoryLayout<Int32>.size)
        ) == 0 else {
            throw POSIXError(.init(rawValue: errno) ?? .EIO)
        }
    }

    /// The descriptor must already have `SO_NOSIGPIPE`. Otherwise a closed peer
    /// raises `SIGPIPE` and this function never throws.
    public static func writeAll(_ data: Data, to descriptor: Int32) throws {
        try data.withUnsafeBytes { pointer in
            guard let baseAddress = pointer.bindMemory(to: UInt8.self).baseAddress else {
                return
            }
            var sent = 0
            while sent < data.count {
                let count = write(descriptor, baseAddress.advanced(by: sent), data.count - sent)
                guard count > 0 else {
                    throw POSIXError(.init(rawValue: errno) ?? .EIO)
                }
                sent += count
            }
        }
    }
}
