// repro: mokume#2337
//
import Foundation
import mokume

/// OBJ で `vn` を持つ面と持たない面が混ざると、持たない面の向きが形から求められず
/// 既定の (0, 0, 1) になる。同じ面に正しい `vn` を書いた絵とも、全面 `vn` 無しの絵とも食い違う。
@MainActor
enum ObjMixedNormals {
    @MainActor final class Probe: Sketch {
        nonisolated(unsafe) static var path = ""
        nonisolated(unsafe) static var model: Model?
        required init() {}
        var settings: SketchSettings { SketchSettings(width: 200, height: 200, windowScale: 1) }
        func setup() { Self.model = try? loadModel(Self.path, normalize: false) }
        func draw() {
            background(0)
            noStroke()
            fill(255)
            // 光は (-1, 0, -1) へ進む。向き (1, 0, 1)/√2 の面に真正面から当たる
            directionalLight(255, 255, 255, -1, 0, -1)
            translate(100, 100, 0)
            scale(60, 60, 60)
            if let loaded = Self.model { model(loaded) }
        }
    }

    /// 三角形 B (平面 x + z = 0・向き (1,0,1)/√2) の内側の明るさ。
    static func brightness(_ obj: String, _ name: String) throws -> Float {
        let path = NSTemporaryDirectory() + name
        try obj.write(toFile: path, atomically: true, encoding: .utf8)
        Probe.path = path
        Probe.model = nil
        return try MainActor.assumeIsolated {
            let runtime = try SketchRuntime(sketch: Probe(), gpu: RenderDevice())
            try runtime.advance()
            let pixels = try runtime.target.readPixels()
            var sum: Float = 0
            var count = 0
            for y in 106..<125 { for x in 106..<118 {
                let c = pixels[x, y]; sum += (c.red + c.green + c.blue) / 3; count += 1
            } }
            return sum / Float(count)
        }
    }

    static func reproduce() throws -> String? {
        // B: 1..3、A (離れた所の正面向きの三角形): 4..6
        let v = "v 0 0 0\nv 1 0 -1\nv 0 1 0\nv -2 0 0\nv -1 0 0\nv -2 1 0\nvn 0 0 1\nvn 0.70710678 0 0.70710678\n"
        let mixed = try brightness(v + "f 4//1 5//1 6//1\nf 1 2 3\n", "mixed-vn.obj")
        let written = try brightness(v + "f 4//1 5//1 6//1\nf 1//2 2//2 3//2\n", "all-vn.obj")
        let none = try brightness(v + "f 4 5 6\nf 1 2 3\n", "no-vn.obj")
        if abs(mixed - written) > 0.05 || abs(mixed - none) > 0.05 {
            return "vn の無い面 B の明るさ: 混ざったファイル \(mixed)・B に正しい vn を書いた \(written)・どの面にも vn が無い \(none)。混ざると B は (0,0,1) を向いた明るさ (cos45°≈0.707) になる"
        }
        return nil
    }
}
