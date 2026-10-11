// repro: mokume#2324
//
import Foundation
import mokume

/// 空の datagram (0 バイト) が 1 つ届くと、mokume の受け口はその送り元の繋ぎを閉じる。
/// 空の datagram 自身も、その直後に同じ送り元から続けて届いた datagram も、数えられずに消える。
/// UDP (createUDP) と OSC (createOSC) の両方で起きる。
@MainActor
enum UdpEmptyDatagram {
    final class Host: Sketch {
        nonisolated(unsafe) static var onSetup: (Host) -> Void = { _ in }
        nonisolated(unsafe) static var onDraw: (Host) -> Void = { _ in }
        required init() {}
        func setup() { Host.onSetup(self) }
        func draw() { Host.onDraw(self) }
    }

    static func reproduce() throws -> String? {
        let udpPort = freePort(), oscPort = freePort()
        var udp: UDPPort?, osc: OSCPort?
        var texts: [String] = [], addresses: [String] = []
        Host.onSetup = { sketch in
            udp = try? sketch.createUDP(listen: udpPort)
            osc = try? sketch.createOSC(listen: oscPort)
        }
        Host.onDraw = { _ in
            texts += udp?.messages ?? []
            addresses += (osc?.messages ?? []).map(\.address)
        }
        let runtime = try SketchRuntime(sketch: Host(), gpu: RenderDevice())
        func frames(_ n: Int) throws { for _ in 0..<n { try runtime.advance(); Thread.sleep(forTimeInterval: 0.02) } }
        try frames(10)
        guard udp?.state == .running, osc?.state == .running else { return "ports did not start" }

        // 同じ送り元 (1 つの socket) から、間を空けずに送る
        let sender = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(sender) }
        for payload in ["a", "", "b", "c"] { send(sender, Array(payload.utf8), to: udpPort) }
        let message: [UInt8] = Array("/m".utf8) + [0, 0]  // 引数の無い OSC メッセージ
        send(sender, message, to: oscPort)
        send(sender, [], to: oscPort)
        for _ in 0..<5 { send(sender, message, to: oscPort) }
        try frames(20)

        let expectedTexts = ["a", "", "b", "c"]
        let expectedOSC = 6  // 空の datagram は読めないもの。前の 1 つと後ろの 5 つは届くはず
        if texts == expectedTexts && addresses.count == expectedOSC { return nil }
        return "UDP: sent \(expectedTexts) back to back, messages got \(texts) "
            + "(\(expectedTexts.count - texts.count) lost, none counted as unreadable); "
            + "OSC: sent /m, <empty>, /m x5, messages got \(addresses.count) of \(expectedOSC)"
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
