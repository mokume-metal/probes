// repro: mokume#2326
//
import Foundation
import mokume

/// 送り先で誰も受けていないとき、OSCPort.send / UDPPort.send は「1 度だけ診断に出す」はずが、
/// 1 つも届かないまま送るたびに 2 回に 1 回ほど同じ警告を出し続ける。
@MainActor
enum SendRefusedWarns {
    final class Host: Sketch {
        nonisolated(unsafe) static var onSetup: (Host) -> Void = { _ in }
        nonisolated(unsafe) static var onDraw: (Host) -> Void = { _ in }
        required init() {}
        func setup() { Host.onSetup(self) }
        func draw() { Host.onDraw(self) }
    }

    static func reproduce() throws -> String? {
        let nobody = freePort()  // 誰も受けていない宛先
        var osc: OSCPort?, udp: UDPPort?
        Host.onSetup = { sketch in
            osc = try? sketch.createOSC(listen: freePort(), send: ("127.0.0.1", nobody))
            udp = try? sketch.createUDP(listen: freePort(), send: ("127.0.0.1", nobody))
        }
        Host.onDraw = { _ in }
        let runtime = try SketchRuntime(sketch: Host(), gpu: RenderDevice())
        func frames(_ n: Int) throws { for _ in 0..<n { try runtime.advance(); Thread.sleep(forTimeInterval: 0.02) } }
        try frames(5)

        let sends = 10
        let oscWarnings = try captureWarnings {
            for i in 0..<sends { osc?.send("/hit", i); try frames(3) }
        }
        let udpWarnings = try captureWarnings {
            for i in 0..<sends { udp?.send("hit \(i)"); try frames(3) }
        }
        let refusedOSC = oscWarnings.filter { $0.contains("Could not send") }.count
        let refusedUDP = udpWarnings.filter { $0.contains("Could not send") }.count
        if refusedOSC <= 1 && refusedUDP <= 1 { return nil }
        return "\(sends) sends to a port nobody listens on, none delivered: "
            + "OSCPort warned \(refusedOSC) times, UDPPort warned \(refusedUDP) times (expected 1 each)"
    }

    /// 診断 (標準エラー) を一時ファイルへ向けて、行を集める。
    private static func captureWarnings(_ body: () throws -> Void) throws -> [String] {
        let path = NSTemporaryDirectory() + "osc-warn-\(getpid())-\(UUID().uuidString).log"
        let file = open(path, O_CREAT | O_TRUNC | O_WRONLY, 0o600)
        let saved = dup(2)
        dup2(file, 2)
        defer {
            dup2(saved, 2)
            close(saved)
            close(file)
            unlink(path)
        }
        try body()
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        return text.split(separator: "\n").map(String.init)
    }

    private static func freePort() -> Int {
        let fd = socket(AF_INET, SOCK_DGRAM, 0)
        defer { close(fd) }
        var a = sockaddr_in()
        a.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        a.sin_family = sa_family_t(AF_INET)
        a.sin_addr.s_addr = inet_addr("127.0.0.1")
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
