// repro: mokume#1623
//
// `force()` に数でない値の力を 1 度かけても、生きている粒は消えないはず (mokume ADR-0020
// 決定 5: フレームごとに呼ばれる口は、受け口で値を検証し、警告を出して安全な既定へ倒す)。
// 2 枚目に `.gravity(.nan, 0)` をかけたものと `.gravity(0, 0)` をかけたものを別の
// `SketchRuntime` で回し、明るい画素 (どれかの成分が 0.2 を越える) を数えて比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum NaNGravity {
    static let frames = [2, 3, 10, 40]

    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let nan = try lit(force: .gravity(.nan, 0))
        let zero = try lit(force: .gravity(0, 0))
        guard nan != zero else { return nil }
        let rows = frames.indices.map { "\(frames[$0]) 枚目 \(nan[$0]) / \(zero[$0])" }
        return "明るい画素の数 (NaN の力 / 0 の力): " + rows.joined(separator: "・")
    }

    /// 窓を出さずに回し、`frames` の各枚で明るい画素を数える。
    static func lit(force: Force) throws -> [Int] {
        let runtime = try SketchRuntime(sketch: Scene(force), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        var counts: [Int] = []
        for frame in 1...frames.max()! {
            try runtime.advance()
            guard frames.contains(frame) else { continue }
            let pixels = try runtime.target.readPixels()
            var count = 0
            for y in 0..<pixels.height {
                for x in 0..<pixels.width {
                    let c = pixels[x, y]
                    if max(c.red, c.green, c.blue) > 0.2 { count += 1 }
                }
            }
            counts.append(count)
        }
        return counts
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        let once: Force
        var dust: Particles!
        init(_ once: Force) { self.once = once }
        convenience init() { self.init(.gravity(0, 0)) }

        func setup() { dust = try! makeParticles(count: 512) }

        func draw() {
            background(12)
            let up = -Float.pi / 2
            emit(
                dust, from: .point(80, 150), rate: 60, speed: 40...60, angle: (up - 0.4)...(up + 0.4),
                life: 2...2, size: 5...5, color: .display(red: 0.94, green: 0.55, blue: 0.16))
            force(dust, .gravity(0, 20))
            if frameCount == 2 { force(dust, once) }
            particles(dust)
        }
    }
}
