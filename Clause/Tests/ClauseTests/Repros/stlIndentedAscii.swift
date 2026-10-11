// repro: mokume#未起票
//
import Foundation
import mokume

/// 前に空白のある文字の STL は「読めない」と投げる約束 (DocC) だが、83 バイト目が改行・タブ
/// などの制御文字だと、バイナリとして読まれ、でたらめな三角形 (座標 1e34 級) が返る。
@MainActor enum StlIndentedAscii {
    @MainActor final class Probe: Sketch {
        nonisolated(unsafe) static var paths: [String] = []
        nonisolated(unsafe) static var results: [String: Result<Model, ModelFailure>] = [:]
        required init() {}
        var settings: SketchSettings { SketchSettings(width: 64, height: 64, windowScale: 1) }
        func setup() {
            for p in Self.paths {
                do { Self.results[p] = .success(try loadModel(p, normalize: false)) } catch { Self.results[p] = .failure(error) }
            }
        }
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let facets = [["0 0 0", "1 0 0", "0 1 0"], ["1 0 0", "1 1 0", "0 1 0"], ["0 0 1", "1 0 1", "0 1 1"]]
            .map { vs in
                "  facet normal 0 0 1\n    outer loop\n" + vs.map { "      vertex \($0)\n" }.joined()
                    + "    endloop\n  endfacet\n"
            }.joined()
        let dir = NSTemporaryDirectory()
        // 前に空白 2 つ (83 バイト目が "\n") と、陰性対照の空白 1 つ (83 バイト目が " ")
        let bad = dir + "indented-2.stl", control = dir + "indented-1.stl"
        let badText = "  solid t\n" + facets + "endsolid t\n"
        let controlText = " solid t\n" + facets + "endsolid t\n"
        try badText.write(toFile: bad, atomically: true, encoding: .utf8)
        try controlText.write(toFile: control, atomically: true, encoding: .utf8)
        Probe.paths = [bad, control]
        Probe.results = [:]
        try MainActor.assumeIsolated {
            let runtime = try SketchRuntime(sketch: Probe(), gpu: RenderDevice())
            try runtime.advance()
        }
        guard case .failure = Probe.results[control] else {
            return "陰性対照 (前に空白 1 つ) が投げない: \(String(describing: Probe.results[control]))"
        }
        if case .success(let model) = Probe.results[bad] {
            let byte83 = Array(badText.utf8)[83]
            return "前に空白 2 つの文字の STL (面 3 つ・\(badText.utf8.count) バイト・83 バイト目 0x\(String(byte83, radix: 16))) が投げずに読め、三角形 \(model.triangleCount) 枚・大きさ \(model.size) のでたらめな形が返る (前に空白 1 つなら投げる)"
        }
        return nil
    }
}
