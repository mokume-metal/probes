// repro: mokume#2338
//
import Foundation
import mokume

/// STL で `facet normal 0 0 0` の面は「巻き方から求め、両面として扱う」約束だが、
/// 同じファイルに向きを書いた面が 1 つでもあると片面になり、巻き方が見る側と逆の面が真っ黒になる。
@MainActor
enum StlZeroNormalMixed {
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
            directionalLight(255, 255, 255, -1, 0, -1)
            translate(100, 100, 0)
            scale(60, 60, 60)
            if let loaded = Self.model { model(loaded) }
        }
    }

    typealias Facet = (normal: SIMD3<Float>, a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>)

    static func binarySTL(_ facets: [Facet]) -> Data {
        var data = Data(count: 80)
        var count = UInt32(facets.count)
        withUnsafeBytes(of: &count) { data.append(contentsOf: $0) }
        for f in facets {
            for v in [f.normal, f.a, f.b, f.c] {
                for var x in [v.x, v.y, v.z] { withUnsafeBytes(of: &x) { data.append(contentsOf: $0) } }
            }
            data.append(contentsOf: [0, 0])
        }
        return data
    }

    /// 三角形 B の内側の明るさ。
    static func brightness(_ facets: [Facet], _ name: String) throws -> Float {
        let path = NSTemporaryDirectory() + name
        try binarySTL(facets).write(to: URL(fileURLWithPath: path))
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
        // B は平面 x + z = 0 の三角形を、見る側と逆に巻いたもの (a, c, b)。A は離れた正面向きの三角形
        let a = SIMD3<Float>(0, 0, 0), b = SIMD3<Float>(1, 0, -1), c = SIMD3<Float>(0, 1, 0)
        let a2 = SIMD3<Float>(-2, 0, 0), b2 = SIMD3<Float>(-1, 0, 0), c2 = SIMD3<Float>(-2, 1, 0)
        let mixed = try brightness([(.zero, a, c, b), (SIMD3(0, 0, 1), a2, b2, c2)], "zero-beside-written.stl")
        let allZero = try brightness([(.zero, a, c, b), (.zero, a2, b2, c2)], "zero-all.stl")
        if abs(mixed - allZero) > 0.05 {
            return "向き 0 0 0 の面 B の明るさ: 他の面が向きを書いている \(mixed)・どの面も 0 0 0 \(allZero)。隣に向きを書いた面があるだけで B が両面でなくなる"
        }
        return nil
    }
}
