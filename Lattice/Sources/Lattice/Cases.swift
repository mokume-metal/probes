import mokume

/// 条件を振った絵。**窓もテストも、ここの同じ定義を描く。**
///
/// どれも「条件を変えても成り立つはずの関係」の片側で、窓では左右に並べ、`swift test` では
/// 画素で関係を確かめる。
enum Cases {
    /// 図形をそのまま、または関係の変換を掛けて描く。
    static func figure(_ f: Figure, _ relation: Relation? = nil, size: Int = Figures.side, density: Float = 1) -> Scene {
        Scene(SketchSettings(width: size, height: size, title: "lattice", pixelDensity: density)) { s in
            s.background(0)
            relation?.apply(s, center: Float(Figures.side) / 2)
            f.draw(s)
        }
    }

    /// 同じ図形を、別の大きさの面に描く (左上の 160² は同じ絵のはず)。
    static func figure(_ f: Figure, width: Int, height: Int, offset: (x: Int, y: Int) = (0, 0)) -> Scene {
        Scene(SketchSettings(width: width, height: height, title: "lattice")) { s in
            s.background(0)
            s.translate(Float(offset.x), Float(offset.y))
            f.draw(s)
        }
    }

    /// 同じ図形を、半分の面に `scale(0.5)` で描く。細かさ 0.5 の**描く面**と同じ絵のはず。
    static func halved(_ f: Figure) -> Scene {
        Scene(SketchSettings(width: Figures.side / 2, height: Figures.side / 2, title: "lattice")) { s in
            s.background(0)
            s.scale(0.5, 0.5)
            f.draw(s)
        }
    }

    // MARK: - 細かさ

    /// 太さ 1 の輪郭を、上辺を `y` に置いて描く。**三角形の経路** (`triangle`・`quad`・
    /// `beginShape`) と、距離関数の経路 (`rect`・`line`) を `path` で選ぶ。
    static func thinOutline(_ path: OutlinePath, y: Float, density: Float) -> Scene {
        Scene(SketchSettings(width: 100, height: 100, title: "lattice", pixelDensity: density)) { s in
            s.background(0)
            s.noFill()
            s.stroke(255)
            s.strokeWeight(1)
            switch path {
            case .triangle: s.triangle(10, y, 90, y, 50, y + 60)
            case .quad: s.quad(10, y, 90, y, 90, y + 60, 10, y + 60)
            case .shape:
                s.beginShape(); s.vertex(10, y); s.vertex(90, y); s.vertex(50, y + 60); s.endShape(.close)
            case .rect: s.rect(10, y, 80, 60)
            case .line: s.line(10, y, 90, y)
            }
        }
    }

    nonisolated enum OutlinePath: String, CaseIterable, Sendable {
        case triangle, quad, shape, rect, line
        var triangles: Bool { self == .triangle || self == .quad || self == .shape }
    }

    /// 白い円・赤と黒の四角。`clear` なら下地を塗らない (透明のまま)。
    static func edges(density: Float, clear: Bool) -> Scene {
        Scene(SketchSettings(width: 100, height: 100, title: "lattice", pixelDensity: density)) { s in
            if !clear { s.background(0) }
            s.noStroke()
            s.fill(255); s.circle(50, 60, 40)
            s.fill(255, 0, 0); s.rect(10, 10, 20, 20)
            s.fill(0); s.rect(30, 10, 20, 20)
        }
    }

    /// 利用者の効果で、`in.position` を 8 画素の升目に割って市松に塗る。
    static func mosaic(density: Float) -> Scene {
        final class Holder { var effect: EffectShader? }
        let holder = Holder()
        return Scene(
            SketchSettings(width: 64, height: 64, title: "lattice", pixelDensity: density),
            setup: { s in
                holder.effect = try? s.makeEffect(
                    """
                    float4 effect(Pixel in, Values values) {
                        float2 cell = floor(in.position / 8.0);
                        return fmod(cell.x + cell.y, 2.0) < 0.5 ? float4(1, 1, 1, 1) : float4(0, 0, 0, 1);
                    }
                    """)
            }
        ) { s in
            s.background(0)
            if let effect = holder.effect { s.effects([.custom(effect)]) }
        }
    }

    // MARK: - 切り抜き

    /// 面いっぱいの白を、`clip(x, 0, w, 40)` で切り抜く。
    static func clipped(x: Float, width w: Float, density: Float) -> Scene {
        Scene(SketchSettings(width: 100, height: 40, title: "lattice", pixelDensity: density)) { s in
            s.background(0)
            s.clip(x, 0, w, 40)
            s.noStroke(); s.fill(255); s.rect(0, 0, 100, 40)
        }
    }

    /// 同じ矩形を塗る (切り抜きと同じ場所を覆うはずのもの)。
    static func filled(x: Float, width w: Float, density: Float) -> Scene {
        Scene(SketchSettings(width: 100, height: 40, title: "lattice", pixelDensity: density)) { s in
            s.background(0)
            s.noStroke(); s.fill(255); s.rect(x, 0, w, 40)
        }
    }

    // MARK: - fps

    /// **毎秒 `fps` 個** (1 枚に 1 個のはず) の粒を、毎秒 1200 画素で右へ飛ばす。粒は
    /// 1200 / fps 画素ずつ離れて並ぶので、`fps` 枚回した後の数を行の上で数えられる。
    static func emitRow(fps: Int) -> Scene {
        final class Holder { var particles: Particles? }
        let holder = Holder()
        return Scene(
            SketchSettings(width: 1300, height: 20, frameRate: fps, title: "lattice"),
            setup: { s in holder.particles = try? s.makeParticles(count: 1000) }
        ) { s in
            s.background(0)
            guard let particles = holder.particles else { return }
            s.emit(
                particles, from: .point(5, 10), rate: Float(fps), speed: 1200...1200, angle: 0...0,
                life: 100...100, size: 2...2, color: LinearRGBA(straightRed: 1, green: 1, blue: 1, alpha: 1))
            s.particles(particles)
        }
    }
}
