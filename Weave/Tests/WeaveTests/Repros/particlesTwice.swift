// repro: mokume#1651
//
// 1 フレームで同じ粒の群を別の変換の下で 2 回 `particles()` しても、呼ぶたびにその時点の
// 変換で描かれるはず。同じ放出をした別の群を 2 つ目に使った絵と、表示の 1 段 (1/255) より
// 小さい差で比べる。寿命 5 秒・速さ 0 の粒なので、2 回進んでも両方の雲が残る。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ParticlesTwice {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let same = try render(Scene(twoClouds: false))
        let separate = try render(Scene(twoClouds: true))
        let differing = count(same, separate)
        guard differing > 0 else { return nil }
        // (40, 80) は 1 回目に置いた雲の中心
        return "同じ群を 2 回置くと、別の群を 1 回ずつ置いた絵と \(differing) 画素違う"
            + " ((40, 80) の赤: 同じ群 \(same[40, 80].red) / 別の群 \(separate[40, 80].red))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(_ scene: Scene) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: scene, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    /// 成分の差が表示の 1 段 (1/255) を越える画素の数。
    static func count(_ a: PixelBuffer, _ b: PixelBuffer) -> Int {
        var n = 0
        for y in 0..<a.height {
            for x in 0..<a.width {
                let (p, q) = (a[x, y], b[x, y])
                let gap = max(abs(p.red - q.red), abs(p.green - q.green), abs(p.blue - q.blue), abs(p.alpha - q.alpha))
                if gap > 0.004 { n += 1 }
            }
        }
        return n
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 160, height: 160, frameRate: 30, title: "repro")
        /// 2 つ目に、同じ放出をした別の群を使うか。
        let twoClouds: Bool
        var cloud: Particles!
        var cloud2: Particles!
        init(twoClouds: Bool) { self.twoClouds = twoClouds }
        convenience init() { self.init(twoClouds: false) }

        func setup() {
            cloud = try! makeParticles(count: 512)
            cloud2 = try! makeParticles(count: 512)
        }

        func draw() {
            background(0)
            emitWhite(cloud)
            if twoClouds { emitWhite(cloud2) }
            push()
            translate(40, 0)
            particles(cloud)
            pop()
            push()
            translate(120, 0)
            particles(twoClouds ? cloud2 : cloud)
            pop()
        }

        /// 動かない白い粒を (0, 80) に 100 個出す (寿命 5 秒・大きさ 20)。
        func emitWhite(_ group: Particles) {
            emit(group, from: .point(0, 80), rate: 3000, speed: 0...0, life: 5...5, size: 20...20,
                 color: color(255, 255, 255))
        }
    }
}
