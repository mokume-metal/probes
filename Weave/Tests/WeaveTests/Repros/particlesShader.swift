// repro: mokume#1650
//
// `shader()` を当てたままでも、`particles()` の粒は記録した四角の塗り (白い板) で出るはず
// (保持した形は記録したときの塗りで描く。CPU で置き場所を埋める経路は、記録した塗りを
// 当て直す)。当てないで描いた絵と、表示の 1 段 (1/255) より小さい差で比べる。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ParticlesShader {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let shaded = try render(Scene(shaded: true))
        let plain = try render(Scene(shaded: false))
        let differing = count(shaded, plain)
        guard differing > 0 else { return nil }
        // (80, 80) は粒を放った点で、白い粒の板の中
        return "shader を当てたままの粒が \(differing) 画素違う"
            + " ((80, 80) の赤: 当てたまま \(shaded[80, 80].red) / 当てない \(plain[80, 80].red))"
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
        /// 緑に塗る断片を `shader()` で当てたまま粒を描くか。
        let shaded: Bool
        var cloud: Particles!
        var green: Shader!
        init(shaded: Bool) { self.shaded = shaded }
        convenience init() { self.init(shaded: false) }

        func setup() {
            cloud = try! makeParticles(count: 512)
            green = try! makeShader("float4 paint(Fragment in, Values values) { return float4(0, 1, 0, 1); }")
        }

        func draw() {
            background(0)
            if shaded { shader(green) }
            emit(cloud, from: .point(80, 80), rate: 3000, speed: 0...0, life: 5...5, size: 20...20,
                 color: color(255, 255, 255))
            particles(cloud)
            resetShader()
        }
    }
}
