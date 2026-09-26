import Testing
import mokume

@testable import Lattice

/// **約束どおりだった関係。** 陰性対照として残す — 関係の組み方 (軸・写像) が正しいことを
/// 押さえ、版上げで壊れたら赤くなる。
@MainActor
@Suite struct RelationTests {
    /// 同じ絵とみなす差。同じ機械・同じフレーム番号ならバイト単位で同じ絵が出る
    /// (mokume ADR-0001 原則 2) ので、表示の 1 段 (1/255) より小さく置く。
    static let exact: Float = 0.004

    /// 三角形の経路は縁に AA が無く (ADR-0039 決定 3)、縁の画素が浮動小数の丸めで 1 つ
    /// 入れ替わりうる。入れ替わってよい画素の数。
    static let triangleEdgeSlack = 4

    @Test("鏡映・90° 回転・整数の平行移動で、絵が画素ごと写り合う", arguments: Figures.all.map(\.key))
    func equivariance(key: String) throws {
        let figure = Figures.named(key)
        let base = try run(Cases.figure(figure), name: "\(key)-base")
        #expect(base.lit > 100, "そのままの絵が描けていない")
        for relation in Relation.allCases {
            let got = try run(Cases.figure(figure, relation), name: "\(key)-\(relation)")
            let want = relation.expected(from: base, center: Figures.side / 2, stroke: figure.stroke)
            let d = difference(got, want, threshold: Self.exact)
            let slack = figure.stroke && figure.triangles ? Self.triangleEdgeSlack : 0
            #expect(d.over <= slack, "\(relation): \(d)")
        }
    }

    @Test(
        "面の大きさを変えても、左上の 160² は同じ絵",
        arguments: [(161, 161), (160, 997), (997, 160), (16384, 200), (200, 16384)])
    func cropInvariance(width: Int, height: Int) throws {
        let square = Region(x: 0, y: 0, width: Figures.side, height: Figures.side)
        for figure in Figures.all {
            let base = try run(Cases.figure(figure), name: "\(figure.key)-base")
            let got = try run(
                Cases.figure(figure, width: width, height: height), name: "\(figure.key)-\(width)x\(height)",
                region: square)
            let d = difference(got, base, threshold: Self.exact)
            // 200×16384 では、三角形の経路の塗りの縁が 1 画素だけ入れ替わる。面の座標を
            // 投影で -1…1 へ縮める丸めが、AA の無い縁 (ADR-0039 決定 3) の同点を動かす
            #expect(d.over <= (figure.triangles ? Self.triangleEdgeSlack : 0), "\(figure.key): \(d)")
        }
    }

    @Test("遠くへ平行移動しても、同じ絵が平行移動して出る (16384 の面の右端まで)")
    func farTranslation() throws {
        for (width, height, x, y) in [(4096, 4096, 3900, 3900), (16384, 200, 16200, 20)] {
            let region = Region(x: x, y: y, width: Figures.side, height: min(Figures.side, height - y))
            for figure in Figures.all {
                let base = try run(Cases.figure(figure), name: "\(figure.key)-base")
                    .crop(Region(x: 0, y: 0, width: region.width, height: region.height))
                let got = try run(
                    Cases.figure(figure, width: width, height: height, offset: (x, y)),
                    name: "\(figure.key)-far\(x)", region: region)
                let d = difference(got, base, threshold: Self.exact)
                #expect(d.over == 0, "\(figure.key) を (\(x), \(y)) へ: \(d)")
            }
        }
    }

    @Test("細かさ 0.5 の描く面は、半分の面に scale(0.5) で描いた絵と同じ (塗り)", arguments: Figures.fills.map(\.key))
    func densityIsScale(key: String) throws {
        let figure = Figures.named(key)
        let settings = SketchSettings(width: Figures.side, height: Figures.side, pixelDensity: 0.5)
        let drawn = try runDrawn(settings, name: "\(key)-drawn") { s in s.background(0); figure.draw(s) }
        let halved = try run(Cases.halved(figure), name: "\(key)-halved")
        #expect(halved.lit > 20)
        let d = difference(drawn, halved, threshold: Self.exact)
        #expect(d.over == 0, "\(d)")
    }

    @Test("奥行き 0 の plane は、縦横比を変えた面でも rect と同じ形・同じ場所", arguments: [
        (160, 160), (161, 97), (97, 161), (1001, 31), (31, 1001),
    ])
    func planeMatchesRect(width: Int, height: Int) throws {
        let settings = SketchSettings(width: width, height: height)
        let place: (Scene) -> Void = { s in
            s.background(0); s.noStroke(); s.fill(255)
            s.translate(Float(width) * 0.3 + 11, Float(height) * 0.4 + 7)
            s.rotate(0.4)
        }
        let plane = try run(Scene(settings) { s in place(s); s.plane(22.6, 14.2) }, name: "plane-\(width)x\(height)")
        let rect = try run(
            Scene(settings) { s in place(s); s.rect(-11.3, -7.1, 22.6, 14.2) }, name: "rect-\(width)x\(height)")
        // 幾何の一致 (ADR-0039 決定 1): 縁を 50% で白黒にした形と、重心
        let mismatch = zip(plane.values, rect.values).count { ($0.x > 0.5) != ($1.x > 0.5) }
        #expect(rect.lit > 200)
        #expect(mismatch == 0)
        let shift = plane.centroid - rect.centroid
        #expect(abs(shift.x) < 0.1 && abs(shift.y) < 0.1, "重心が \(shift) ずれた")
    }

    @Test("立体を画面の中心で rotateZ(90°) すると、絵が 90° 回る", arguments: [160, 161])
    func solidRotation(size: Int) throws {
        let scene: (Bool) -> Scene = { rotated in
            Scene(SketchSettings(width: size, height: size)) { s in
                s.background(0); s.noStroke(); s.fill(200, 180, 90)
                // 視線に沿った光なので、視線の軸まわりの回転で陰影は変わらない
                s.directionalLight(255, 255, 255, 0, 0, -1)
                s.translate(Float(size) / 2, Float(size) / 2, 0)
                if rotated { s.rotateZ(Float.pi / 2) }
                s.translate(-7.3, 4.1, 0)
                s.push(); s.rotateX(0.5); s.rotateY(0.7); s.box(50); s.pop()
                s.translate(20.3, 10.7, 0); s.sphere(20)
            }
        }
        let base = try run(scene(false), name: "solid-\(size)")
        let rotated = try run(scene(true), name: "solid-\(size)-rotated")
        #expect(base.lit > 1000)
        // 塗りなので画素の角 (面の中心) が軸。奇数の面では中心が画素の中心に来るので、
        // 画素の置き換えで写るのは偶数の面だけ — 奇数は半画素ずれた軸で写す
        let want = Relation.rotate90.expected(from: base, center: size / 2, stroke: size % 2 == 1)
        let d = difference(rotated, want, threshold: 0.01)
        #expect(d.over == 0, "\(d)")
    }

    @Test("可換な混ぜ方は、重ねる順を入れ替えても同じ絵", arguments: [
        BlendMode.add, .multiply, .screen, .exclusion, .darkest,
    ])
    func blendCommutes(mode: BlendMode) throws {
        let a: (Scene) -> Void = { s in s.fill(230, 120, 40, 180); s.circle(60.3, 70.7, 70) }
        let b: (Scene) -> Void = { s in s.fill(40, 160, 230, 140); s.rect(55.2, 40.9, 60, 70) }
        for background: Float in [0, 128] {
            let settings = SketchSettings(width: 160, height: 160)
            let ab = try run(
                Scene(settings) { s in s.background(background); s.noStroke(); s.blendMode(mode); a(s); b(s) },
                name: "blend-\(mode)-\(background)-ab")
            let ba = try run(
                Scene(settings) { s in s.background(background); s.noStroke(); s.blendMode(mode); b(s); a(s) },
                name: "blend-\(mode)-\(background)-ba")
            let d = difference(ab, ba, threshold: Self.exact)
            #expect(d.over == 0, "下地 \(background): \(d)")
        }
    }

    @Test("効果は鏡映と入れ替えられる (奇数・細長い面・細かさ 0.5)", arguments: [
        (160, 160), (161, 97), (100, 3),
    ])
    func effectsMirror(width: Int, height: Int) throws {
        let chains: [(String, [Effect])] = [
            ("blur3", [.blur(radius: 3)]), ("blur20", [.blur(radius: 20)]),
            ("bloom", [.bloom(amount: 1, threshold: 0.3, radius: 12)]), ("vignette", [.vignette(amount: 1)]),
            ("fringe", [.fringe(amount: 1)]), ("adjust", [.adjust(brightness: 0.2, contrast: 0.3, saturation: 0.5)]),
        ]
        let (w, h) = (Float(width), Float(height))
        let scenery: (Scene) -> Void = { s in
            s.background(0); s.noStroke()
            s.fill(255, 200, 50); s.circle(w * 0.3, h * 0.4, min(w, h) * 0.3)
            s.fill(40, 90, 255); s.rect(w * 0.55, h * 0.2, w * 0.3, h * 0.5)
        }
        for density: Float in [1, 0.5] {
            let settings = SketchSettings(width: width, height: height, pixelDensity: density)
            for (name, chain) in chains {
                let plain = try run(
                    Scene(settings) { s in scenery(s); s.effects(chain) }, name: "fx-\(name)-\(width)x\(height)-\(density)")
                let mirrored = try run(
                    Scene(settings) { s in s.translate(w, 0); s.scale(-1, 1); scenery(s); s.effects(chain) },
                    name: "fx-\(name)-\(width)x\(height)-\(density)-mirrored")
                let want = plain.mapped { (width - 1 - $0, $1) }
                let d = difference(mirrored, want, threshold: Self.exact)
                #expect(d.over == 0, "\(name) 細かさ \(density): \(d)")
            }
        }
    }
}
