// repro: mokume#2339
//
import Foundation
import mokume

/// OBJ の面の角に読めない番号 (範囲外・0・数でない) が混ざると、その角だけを黙って落として
/// 残りで面を作る。行は読み飛ばしに数えられず (`skippedLines == 0`)、四角が三角になったことが分からない。
@MainActor
enum ObjBadCorners {
    @MainActor final class Probe: Sketch {
        nonisolated(unsafe) static var paths: [String] = []
        nonisolated(unsafe) static var models: [String: Model] = [:]
        required init() {}
        var settings: SketchSettings { SketchSettings(width: 64, height: 64, windowScale: 1) }
        func setup() { for p in Self.paths { Self.models[p] = try? loadModel(p, normalize: false) } }
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let v = "v 0 0 0\nv 1 0 0\nv 1 1 0\nv 0 1 0\n"
        let cases: [(String, String)] = [
            ("range", v + "f 1 2 3 4 99\n"),     // 5 角のうち 1 つが範囲外
            ("zero", v + "f 1 2 0 3 4\n"),        // 0 は OBJ に無い番号
            ("text", v + "f 1 2 x 3 4\n"),        // 数でない
            ("control", v + "f 1 2 3 4\n"),       // 陰性対照
            ("two-bad", v + "f 1 2 99\n"),        // 境界: 残りが 2 角なら行ごと読み飛ばして数える
        ]
        let dir = NSTemporaryDirectory()
        var paths: [String: String] = [:]
        for (name, text) in cases {
            let path = dir + "bad-corner-\(name).obj"
            try text.write(toFile: path, atomically: true, encoding: .utf8)
            paths[name] = path
        }
        Probe.paths = Array(paths.values)
        Probe.models = [:]
        try MainActor.assumeIsolated {
            let runtime = try SketchRuntime(sketch: Probe(), gpu: RenderDevice())
            try runtime.advance()
        }
        func show(_ name: String) -> String {
            guard let m = Probe.models[paths[name]!] else { return "\(name): 読めない" }
            return "\(name): 三角形 \(m.triangleCount)・読み飛ばし \(m.skippedLines)"
        }
        let silent = ["range", "zero", "text"].filter { (Probe.models[paths[$0]!]?.skippedLines ?? -1) == 0 }
        if !silent.isEmpty {
            return "読めない角を含む面が、読み飛ばしに数えられずに読まれる — " + cases.map { show($0.0) }.joined(separator: " / ")
        }
        return nil
    }
}
