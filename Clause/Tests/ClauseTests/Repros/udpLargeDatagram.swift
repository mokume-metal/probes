// repro: mokume#2325
//
import Foundation
import mokume

/// 9216 バイトを超える datagram を受けると、mokume は先頭 9216 バイトだけを 1 つのメッセージとして
/// 渡す。UDP (createUDP) では、黙って短い別の文字列になる。OSC では読めないものとして捨てられる。
/// 同じ datagram を素の socket で受けると、全長が届く (陰性対照)。
@MainActor
enum UdpLargeDatagram {
    final class Host: Sketch {
        nonisolated(unsafe) static var onSetup: (Host) -> Void = { _ in }
        nonisolated(unsafe) static var onDraw: (Host) -> Void = { _ in }
        required init() {}
        func setup() { Host.onSetup(self) }
        func draw() { Host.onDraw(self) }
    }

    static func reproduce() throws -> String? {
        let udpPort = freePort(), oscPort = freePort(), rawPort = freePort()
        var udp: UDPPort?, osc: OSCPort?
        var lengths: [Int] = [], blobs: [Int] = []
        Host.onSetup = { sketch in
            udp = try? sketch.createUDP(listen: udpPort)
            osc = try? sketch.createOSC(listen: oscPort)
        }
        Host.onDraw = { _ in
            lengths += (udp?.messages ?? []).map(\.utf8.count)
            for message in osc?.messages ?? [] {
                if case .blob(let bytes) = message.arguments.first { blobs.append(bytes.count) }
            }
        }
        let runtime = try SketchRuntime(sketch: Host(), gpu: RenderDevice())
        func frames(_ n: Int) throws { for _ in 0..<n { try runtime.advance(); Thread.sleep(forTimeInterval: 0.02) } }
        try frames(10)
        guard udp?.state == .running, osc?.state == .running else { return "ports did not start" }

        // 素の受け手 (陰性対照)
        let receiver = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(receiver) }
        var raw = address(rawPort)
        _ = withUnsafePointer(to: &raw) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(receiver, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) }
        }
        var timeout = timeval(tv_sec: 0, tv_usec: 300_000)
        setsockopt(receiver, SOL_SOCKET, SO_RCVTIMEO, &timeout, socklen_t(MemoryLayout<timeval>.size))

        let sender = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(sender) }
        var buffer: Int32 = 1 << 20  // macOS の既定の送る上限 (9216) を超えて送れるようにする
        setsockopt(sender, SOL_SOCKET, SO_SNDBUF, &buffer, 4)

        var report: [String] = []
        for size in [9216, 9217, 20000, 65507] {
            lengths = []
            send(sender, [UInt8](repeating: 0x61, count: size), to: udpPort)
            send(sender, [UInt8](repeating: 0x61, count: size), to: rawPort)
            try frames(5)
            var scratch = [UInt8](repeating: 0, count: 70000)
            let rawLength = recv(receiver, &scratch, scratch.count, 0)
            if lengths != [size] { report.append("\(size) B -> mokume messages \(lengths) (raw socket got \(rawLength))") }
        }
        let blobSize = 12000
        var packet: [UInt8] = Array("/b".utf8) + [0, 0] + Array(",b".utf8) + [0, 0]
        packet += (0..<4).map { UInt8(truncatingIfNeeded: blobSize >> (24 - 8 * $0)) }
        packet += [UInt8](repeating: 7, count: blobSize)
        send(sender, packet, to: oscPort)
        try frames(5)
        if blobs != [blobSize] { report.append("OSC blob of \(blobSize) B (\(packet.count) B datagram) -> blobs \(blobs)") }
        return report.isEmpty ? nil : report.joined(separator: "; ")
    }

    private static func address(_ port: Int) -> sockaddr_in {
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_port = in_port_t(UInt16(port).bigEndian)
        a.sin_addr.s_addr = inet_addr("127.0.0.1")
        return a
    }

    private static func send(_ fd: Int32, _ bytes: [UInt8], to port: Int) {
        var a = address(port)
        _ = bytes.withUnsafeBytes { buffer in
            withUnsafePointer(to: &a) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    sendto(fd, buffer.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }
        }
    }

    private static func freePort() -> Int {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(fd) }
        var a = address(0)
        var length = socklen_t(MemoryLayout<sockaddr_in>.size)
        withUnsafeMutablePointer(to: &a) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                _ = bind(fd, $0, length)
                _ = getsockname(fd, $0, &length)
            }
        }
        return Int(UInt16(bigEndian: a.sin_port))
    }
}
