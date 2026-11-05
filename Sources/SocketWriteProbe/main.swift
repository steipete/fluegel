import Darwin
import Foundation
import FluegelCore

let mode = CommandLine.arguments.dropFirst().first ?? "product"
var descriptors = [Int32](repeating: -1, count: 2)
guard socketpair(AF_UNIX, SOCK_STREAM, 0, &descriptors) == 0 else {
    fputs("socketpair failed\n", stderr)
    exit(2)
}

let writer = descriptors[0]
let peer = descriptors[1]
do {
    if mode == "product" {
        try UnixSocket.disableSIGPIPE(writer)
    } else if mode != "raw" {
        fputs("usage: SocketWriteProbe product|raw\n", stderr)
        exit(2)
    }
    guard close(peer) == 0 else {
        fputs("close failed\n", stderr)
        exit(2)
    }
    try UnixSocket.writeAll(Data([0x78]), to: writer)
    fputs("wrote\n", stdout)
    exit(0)
} catch let error as POSIXError where error.code == .EPIPE {
    fputs("EPIPE\n", stdout)
    exit(0)
} catch {
    fputs("\(error)\n", stderr)
    exit(4)
}
