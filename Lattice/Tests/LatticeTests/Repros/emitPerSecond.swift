// repro: mokume#1640
//
// `emit` の `rate` は毎秒の数で、端数は捨てずに繰り越すので、1 秒ぶん回せば `rate` 個出ている
// はず (`emit` の説明:「低いレートでも、長い目で見て頼んだ数が出る」)。fps 50 で毎秒 50 個
// (1 枚に 1 個) の粒を毎秒 1200 画素で右へ飛ばし、50 枚回した後に行の上で粒を数える。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum EmitPerSecond {
    static let fps = 50

    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let first = try count(frames: 1)
        let second = try count(frames: fps)
        guard first != 1 || second != fps else { return nil }
        return "fps \(fps) で毎秒 \(fps) 個: 1 枚目に \(first) 個・\(fps) 枚目に \(second) 個"
    }

    /// `frames` 枚回した後、行の上で粒を数える。粒は 1200 / fps = 24 画素おきに並ぶ。
    static func count(frames: Int) throws -> Int {
        let runtime = try SketchRuntime(sketch: Scene(), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        for _ in 0..<frames { try runtime.advance() }
        let pixels = try runtime.target.readPixels()
        var (count, inside) = (0, false)
        for x in 0..<pixels.width {
            let on = pixels[x, pixels.height / 2].red > 0.3
            if on && !inside { count += 1 }
            inside = on
        }
        return count
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 1300, height: 20, frameRate: EmitPerSecond.fps)
        var dots: Particles?

        func setup() { dots = try? makeParticles(count: 1000) }

        func draw() {
            background(0)
            guard let dots else { return }
            emit(
                dots, from: .point(5, 10), rate: Float(EmitPerSecond.fps), speed: 1200...1200, angle: 0...0,
                life: 100...100, size: 2...2, color: LinearRGBA(straightRed: 1, green: 1, blue: 1, alpha: 1))
            particles(dots)
        }
    }
}
