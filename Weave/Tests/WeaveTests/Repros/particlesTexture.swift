// repro: mokume#1649
//
// `texture()` を貼ったままでも、`particles()` の粒は記録した四角の塗り (白い板) で出るはず
// (CPU で置き場所を埋める経路は、`beginSolids()` の後で記録した面を張り直す)。貼らないで
// 描いた絵と、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ParticlesTexture {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let textured = try render(Scene(textured: true))
        let plain = try render(Scene(textured: false))
        let differing = count(textured, plain)
        guard differing > 0 else { return nil }
        // (80, 80) は粒を放った点で、白い粒の板の中
        return "texture を貼ったままの粒が \(differing) 画素違う"
            + " ((80, 80) の緑: 貼ったまま \(textured[80, 80].green) / 貼らない \(plain[80, 80].green))"
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
        /// 赤く塗った描き場所を `texture()` で貼ったまま粒を描くか。
        let textured: Bool
        var cloud: Particles!
        var red: Canvas!
        init(textured: Bool) { self.textured = textured }
        convenience init() { self.init(textured: false) }

        func setup() {
            cloud = try! makeParticles(count: 512)
            red = try! createGraphics(8, 8)
            red.beginDraw()
            red.background(255, 0, 0)
            red.endDraw()
        }

        func draw() {
            background(0)
            if textured { texture(red) }
            emit(cloud, from: .point(80, 80), rate: 3000, speed: 0...0, life: 5...5, size: 20...20,
                 color: color(255, 255, 255))
            particles(cloud)
            noTexture()
        }
    }
}
