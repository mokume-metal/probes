import Testing
import mokume

@testable import Probe

/// 候補ごとの検査。**期待値は「正しい振る舞い」のほうに置く。**
///
/// mokume `v0.11.0` で実際に破れていたものは `withKnownIssue` で包み、起票した Issue を
/// 名指しする。mokume 側で直って版を上げると「既知の問題が起きなかった」で赤くなるので、
/// そのときは包みを外して README の表を書き換える。
@MainActor
@Suite struct ProbeTests {
    func pair(_ key: ProbeKey) throws -> (suspect: Picture, reference: Picture) {
        let probe = Probes.named(key)
        return (try Stage.render(probe, .suspect), try Stage.render(probe, .reference))
    }

    // MARK: - 破れていたもの

    @Test("鏡映した不透明の箱は、逆に回した箱と同じ明るさで写る")
    func mirroredSolid() throws {
        let (a, b) = try pair(.mirroredSolid)
        withKnownIssue("mokume#1446: 鏡映すると裏面を捨てる向きが逆になり、奥の面だけが残る") {
            #expect(abs(a.totalLuminance - b.totalLuminance) < b.totalLuminance * 0.05)
            #expect(a.differing(from: b) < 200)
        }
    }

    @Test("透明な下地の上では、どの混ぜ方でも blend と同じ色が載る", arguments: BlendMode.allCases)
    func blendOnTransparent(mode: BlendMode) throws {
        func draw(_ mode: BlendMode) throws -> LinearRGBA {
            try sketch { s in
                s.background(LinearRGBA.transparent)
                s.noStroke()
                s.fill(230, 40, 40, 128)
                s.blendMode(mode)
                s.rect(20, 20, 120, 120)
            }[80, 80]
        }
        let (got, expected) = (try draw(mode), try draw(.blend))
        let broken: Set<BlendMode> = [.add, .subtract, .lightest, .darkest, .difference, .exclusion, .multiply, .screen]
        withKnownIssue("mokume#1447: 下地を読む混ぜ方が下地の α を見ない") {
            #expect(abs(got.red - expected.red) < 0.01, "\(mode) の赤 \(got.red)、blend は \(expected.red)")
            #expect(abs(got.alpha - expected.alpha) < 0.01)
        } when: {
            broken.contains(mode)
        }
    }

    @Test("楕円の arc の塗りは、媒介変数の角で切った扇と同じところで切れる")
    func ellipticArc() throws {
        let (a, b) = try pair(.ellipticArc)
        // 媒介変数の角 20° の内側 — どちらの読み方でも塗られる
        #expect(a[81, 67].red > 0.3)
        #expect(b[81, 67].red > 0.3)
        // 媒介変数の角 60° (扇の外)、極角では 28° (扇の内) に当たる点
        #expect(b[52, 77].red < 0.05)
        withKnownIssue("mokume#1448: 塗りの内外を極角で決め、切り口は媒介変数の角で引いている") {
            #expect(a[52, 77].red < 0.05)
        }
    }

    @Test("curveVertex の穴は、外周の点を引き継がない")
    func curveContour() throws {
        let (a, b) = try pair(.curveContour)
        withKnownIssue("mokume#1449: curveVertex の履歴が beginContour をまたいで残る") {
            #expect(a.differing(from: b) < 16)
        }
    }

    @Test("範囲の外の不透明度は 0…255 へ締まる", arguments: [(-100, 0), (400, 255)] as [(Float, Float)])
    func fillAlpha(given: Float, clamped: Float) throws {
        func draw(_ alpha: Float) throws -> LinearRGBA {
            try sketch { s in
                s.background(128)
                s.noStroke()
                s.fill(255, alpha)
                s.rect(20, 20, 120, 120)
            }[80, 80]
        }
        let (got, expected) = (try draw(given), try draw(clamped))
        withKnownIssue("mokume#1450: fill の α が 0…255 に締まらず、下地が負や 1 超えになる") {
            #expect(abs(got.red - expected.red) < 0.01, "α \(given) の赤 \(got.red)、α \(clamped) は \(expected.red)")
        }
    }

    @Test("1 画素より細い線の濃さは、置く位置によらず太さに比例する", arguments: [0.1, 0.5] as [Float])
    func hairline(weight: Float) throws {
        var energies: [Float] = []
        for x: Float in [80, 80.25, 80.5] {
            let p = try sketch { s in
                s.background(0)
                s.stroke(255)
                s.strokeWeight(weight)
                s.line(x, 10, x, 150)
            }
            energies.append(p.redSum(row: 80, columns: 70..<90))
        }
        withKnownIssue("mokume#1451: 縁の被覆が両側で同じ画素に入る場合を扱わない") {
            for energy in energies {
                #expect(abs(energy - weight) < weight * 0.25, "太さ \(weight) の線の濃さ \(energies)")
            }
        }
    }

    @Test("右揃えの行の末尾の空白は、行の幅に数えない")
    func trailingSpace() throws {
        let (a, b) = try pair(.trailingSpace)
        withKnownIssue("mokume#1452: 語の後ろの空白が行の幅に残り、右揃えが左へずれる") {
            #expect(abs(a.rightmostInk() - b.rightmostInk()) <= 1, "右端 \(a.rightmostInk()) と \(b.rightmostInk())")
        }
    }

    @Test("lerp は amount が 1 なら stop を返し、有限の端からは有限の値を返す")
    func lerpEnds() {
        withKnownIssue("mokume#1453: start + (stop - start) * amount の丸めと桁あふれ") {
            #expect(lerp(1e8, 1, 1) == 1)
            #expect(lerp(-3e38, 3e38, 0.5).isFinite)
        }
        // 説明どおりの振る舞いは通る
        #expect(lerp(0, 10, 2) == 20)
        #expect(constrain(5, 10, 0) == 5)
    }

    // MARK: - 既知の保留

    @Test("太線の bevel は、rect と同じ 4 隅の quad で同じ形になる")
    func bevelJoin() throws {
        let (a, b) = try pair(.bevelJoin)
        withKnownIssue("mokume#931 材料 1: 任意多角形の折れ目は bevel を正方形で近似する (保留を宣言済み)") {
            #expect(a.differing(from: b) < 50)
        }
    }

    // MARK: - 振る舞いを押さえるもの (約束が無いか、手本と同じ)

    @Test("スプライトのコマの拡大は、隣のコマを最後の半コマぶんだけ読む")
    func spriteBleed() throws {
        let (a, b) = try pair(.spriteBleed)
        // **にじみは起きる。** HTML の canvas も、元の矩形の外で原本の画素を読むと
        // 決めている。起票はせず、にじむ幅が拡大した 1 画素ぶん (160 / 8 = 20 列) の
        // 半分を越えないことだけを押さえる
        #expect(a.differing(from: b) > 0)
        #expect(a.differing(from: b) <= 10 * Probes.side)
    }

    @Test("clip() は描く位置の変換を受けず、面の座標で読まれる")
    func clipTranslate() throws {
        let (a, b) = try pair(.clipTranslate)
        // 面の座標の (0…60) が残り、動かした先 (60…120) は切られる。**説明はこれを
        // 名乗っていない** (mokume#1445) — 変換を効かせる側へ変わったら、ここが赤くなる
        #expect(a[30, 30].blue > 0.3)
        #expect(a[90, 90].blue < 0.05)
        #expect(b[90, 90].blue > 0.3)
    }

    // MARK: - v0.11.0 の変更の見張り

    @Test("ellipsoid(a, b, c) は scale(a, b, c) した単位球と同じ絵")
    func ellipsoidScale() throws {
        let (a, b) = try pair(.ellipsoidScale)
        #expect(a.totalLuminance > 500)
        #expect(a.differing(from: b) < 16)
    }

    @Test("ortho() の後の camera() は写し方を平行投影のまま残す")
    func cameraKeepsOrtho() throws {
        let (a, b) = try pair(.cameraKeepsOrtho)
        #expect(a.totalLuminance > 500)
        #expect(a.differing(from: b) == 0)
        // 検査が効いていること: 透視へ戻した絵は違って写る
        let perspective = try sketch { s in
            Probes.cameraKeepsOrtho.draw(s, .reference)
        }
        let restored = try sketch { s in
            s.ortho()
            s.perspective()
            s.background(20)
            s.noStroke()
            s.lights()
            s.fill(240, 200, 80)
            s.translate(Float(Probes.side) / 2, Float(Probes.side) / 2)
            s.rotateX(0.6)
            s.rotateY(0.7)
            s.box(70)
        }
        #expect(perspective.differing(from: restored) > 100)
    }
}
