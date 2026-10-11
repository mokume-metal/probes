// repro: mokume#2335
//
import Foundation
import mokume

/// 面が 1 つの、形の整った文字の STL でも、ファイルが 128 バイトに満たないと
/// `loadModel` が `.unreadable` を投げる (Model I/O が "File is too small to be valid STL" で断る)。
@MainActor
enum StlSmallAscii {
    @MainActor final class Probe: Sketch {
        nonisolated(unsafe) static var paths: [String] = []
        nonisolated(unsafe) static var results: [String: Result<Int, ModelFailure>] = [:]
        required init() {}
        var settings: SketchSettings { SketchSettings(width: 64, height: 64, windowScale: 1) }
        func setup() {
            for p in Self.paths {
                do { Self.results[p] = .success(try loadModel(p).triangleCount) } catch { Self.results[p] = .failure(error) }
            }
        }
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let dir = NSTemporaryDirectory()
        func stl(_ trailing: Int) -> String {
            "solid t\nfacet normal 0 0 1\nouter loop\nvertex 0 0 0\nvertex 1 0 0\nvertex 0 1 0\nendloop\nendfacet\nendsolid t"
                + String(repeating: " ", count: trailing) + "\n"
        }
        // 127 バイト (破れる) と 128 バイト (陰性対照: 末尾の空白を 1 つ足しただけ)
        let small = dir + "small-ascii-127.stl", ok = dir + "small-ascii-128.stl"
        try stl(22).write(toFile: small, atomically: true, encoding: .utf8)
        try stl(23).write(toFile: ok, atomically: true, encoding: .utf8)
        let sizes = [small, ok].map { (try? FileManager.default.attributesOfItem(atPath: $0)[.size] as? Int) ?? -1 }
        Probe.paths = [small, ok]
        Probe.results = [:]
        try MainActor.assumeIsolated {
            let runtime = try SketchRuntime(sketch: Probe(), gpu: RenderDevice())
            try runtime.advance()
        }
        guard case .success(1) = Probe.results[ok] else {
            return "陰性対照 (\(sizes[1]) バイト) が読めない: \(String(describing: Probe.results[ok]))"
        }
        if case .failure(let failure) = Probe.results[small] {
            return "同じ 1 面の文字の STL が \(sizes[1]) バイトなら三角形 1 枚で読めるのに、末尾の空白が 1 つ少ない \(sizes[0]) バイトでは投げる: \(failure)"
        }
        return nil
    }
}
