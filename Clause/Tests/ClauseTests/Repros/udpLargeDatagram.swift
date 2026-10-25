// repro: mokume#2325
//
import Foundation
import mokume

/// v0.22.1 では、9216 バイトを超える datagram を受けると、mokume は先頭 9216 バイトだけを 1 つの
/// メッセージとして渡していた (UDP では黙って短い別の文字列になり、OSC では捨てられた)。
///
/// mokume#2325 は案 B で閉じ、約束が改まった (v0.35.0 の `UDPPort`・`OSCPort` の DocC):
/// **1 つの datagram は 9215 バイトまで。9216 バイト以上は丸ごと捨てて数え、次のフレームで診断に出す**
/// (切れたものと見分けられないので、ちょうど 9216 バイトのものも捨てる)。OSC のパケットも同じ境目である。
/// ここではその新しい約束を、境目の両側で確かめる。同じ datagram を素の socket で受けると全長が届く
/// (送れていることの陰性対照)。
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
        // 境目の手前は全長で 1 つ届き、境目から先は何も届かない
        let said = capturingStandardError {
            for size in [9215, 9216, 9217, 20000, 65507] {
                lengths = []
                send(sender, [UInt8](repeating: 0x61, count: size), to: udpPort)
                send(sender, [UInt8](repeating: 0x61, count: size), to: rawPort)
                try? frames(5)
                var scratch = [UInt8](repeating: 0, count: 70000)
                let rawLength = recv(receiver, &scratch, scratch.count, 0)
                let expected = size < 9216 ? [size] : []
                if rawLength != size { report.append("control broke: raw socket got \(rawLength) of \(size) B") }
                if lengths != expected { report.append("\(size) B -> mokume messages \(lengths) (expected \(expected))") }
            }
            for blobSize in [9000, 12000] {
                blobs = []
                var packet: [UInt8] = Array("/b".utf8) + [0, 0] + Array(",b".utf8) + [0, 0]
                packet += (0..<4).map { UInt8(truncatingIfNeeded: blobSize >> (24 - 8 * $0)) }
                packet += [UInt8](repeating: 7, count: blobSize)
                send(sender, packet, to: oscPort)
                try? frames(5)
                let expected = packet.count < 9216 ? [blobSize] : []
                if blobs != expected { report.append("OSC blob of \(blobSize) B (\(packet.count) B datagram) -> blobs \(blobs) (expected \(expected))") }
            }
        }
        // 捨てたものは数えて知らせる (黙って捨てない)
        if !said.contains("udp ") || !said.contains("osc ") || !said.contains("discarded") {
            report.append("the dropped datagrams were not announced (stderr: \(said.debugDescription))")
        }
        return report.isEmpty ? nil : report.joined(separator: "; ")
    }

    /// 標準エラーへ出た文字を拾いながら `body` を走らせる。
    private static func capturingStandardError(_ body: () -> Void) -> String {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("stderr-\(UUID()).txt")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        fflush(stderr)
        let saved = dup(fileno(stderr))
        let fd = open(file.path, O_WRONLY)
        dup2(fd, fileno(stderr))
        body()
        fflush(stderr)
        dup2(saved, fileno(stderr))
        close(saved)
        close(fd)
        return (try? String(contentsOf: file, encoding: .utf8)) ?? ""
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
