import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite struct ReprosTests {
    // MARK: - 混ぜ方・線の形

    @Test("再現: blendMode(.add) で塗りと輪郭を持つ図形 = 塗りだけと輪郭だけを重ねたもの")
    func addFillStroke() throws {
        let broken = try AddFillStroke.reproduce()
        #expect(broken == nil, "mokume#1643 で直った: \(broken ?? "")")
    }

    @Test("再現: 一直線に並べた 3 点の太い折れ線 = 同じ 2 点を結ぶ line")
    func polylineJoin() throws {
        let broken = try PolylineJoin.reproduce()
        #expect(broken == nil, "mokume#1644 で直った: \(broken ?? "")")
    }

    @Test("再現: scale(20) した折れ線の丸い端 = 同じ拡大の line の丸い端")
    func roundCapScale() throws {
        let broken = try RoundCapScale.reproduce()
        withKnownIssue("mokume#1645: 円板の分割数を形自身の座標の半径で決め、拡大すると端が三角形になる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    // MARK: - 状態の保存と切り抜き

    @Test("再現: createShape の中で変えた curveDetail は、外の曲線に効かない")
    func shapeCurveDetail() throws {
        let broken = try ShapeCurveDetail.reproduce()
        #expect(broken == nil, "mokume#1646 で直った: \(broken ?? "")")
    }

    @Test("再現: 切り抜きの中の background = 切り抜きの中を同じ色で塗る (Processing・p5)")
    func clipBackground() throws {
        let broken = try ClipBackground.reproduce()
        #expect(broken == nil, "mokume#1648 で直った: \(broken ?? "")")
    }

    // MARK: - 粒

    @Test("再現: texture を貼ったままでも、粒は白い板で出る")
    func particlesTexture() throws {
        let broken = try ParticlesTexture.reproduce()
        #expect(broken == nil, "mokume#1649 で直った: \(broken ?? "")")
    }

    @Test("再現: shader を当てたままでも、粒は記録した塗りで出る")
    func particlesShader() throws {
        let broken = try ParticlesShader.reproduce()
        #expect(broken == nil, "mokume#1650 で直った: \(broken ?? "")")
    }

    @Test("再現: 1 フレームに同じ群を 2 か所へ置く = 同じ放出の別の群を 1 か所ずつ置く")
    func particlesTwice() throws {
        let broken = try ParticlesTwice.reproduce()
        #expect(broken == nil, "mokume#1651 で直った: \(broken ?? "")")
    }

    // MARK: - 断片と描き場所

    @Test("再現: 本体で作った断片でも、描き場所で set を挟めば描き分けられる")
    func shaderSetGraphics() throws {
        let broken = try ShaderSetGraphics.reproduce()
        #expect(broken == nil, "mokume#1652 で直った: \(broken ?? "")")
    }

    @Test("再現: 断片の面の描き場所を置いた後で描き換えても、先に置いた形は置いた時点の絵で塗られる")
    func shaderSurfaceRedraw() throws {
        let broken = try ShaderSurfaceRedraw.reproduce()
        #expect(broken == nil, "mokume#1653 で直った: \(broken ?? "")")
    }

    @Test("再現: beginDraw の外で描き場所へ書いた画素は断られ、get も image も書いていない絵を見る")
    func graphicsSetOutside() throws {
        let broken = try GraphicsSetOutside.reproduce()
        #expect(broken == nil, "mokume#1654 で約束が決まった (mokume#1681 が断るほうに決めた): \(broken ?? "")")
    }

    @Test("再現: 効果を掛けた描き場所にフレームの外で書き戻しても、次のフレームの効果は 1 回ぶん")
    func effectsOffFrameSet() throws {
        let broken = try EffectsOffFrameSet.reproduce()
        #expect(broken == nil, "mokume#1655 で直った: \(broken ?? "")")
    }

    // MARK: - フレームの途中の描き切り・周囲の背景

    @Test("再現: フレームの途中で get を読んでも、影は同じ")
    func midFrameShadow() throws {
        let broken = try MidFrameShadow.reproduce()
        #expect(broken == nil, "mokume#1656 で直った: \(broken ?? "")")
    }

    @Test("再現: 立体の後の background(.sky) は、loadPixels を挟んでも立体を消す")
    func loadPixelsSky() throws {
        let broken = try LoadPixelsSky.reproduce()
        #expect(broken == nil, "mokume#1657 で直った: \(broken ?? "")")
    }

    @Test("再現: blendMode(.add) のままでも、background(.sky) は下地を置き換える")
    func addSky() throws {
        let broken = try AddSky.reproduce()
        #expect(broken == nil, "mokume#1658 で直った: \(broken ?? "")")
    }
}
