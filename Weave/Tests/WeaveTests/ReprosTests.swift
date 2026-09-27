import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
@MainActor
@Suite struct ReprosTests {
    // MARK: - 混ぜ方・線の形

    @Test("再現: blendMode(.add) で塗りと輪郭を持つ図形 = 塗りだけと輪郭だけを重ねたもの")
    func addFillStroke() throws {
        let broken = try AddFillStroke.reproduce()
        withKnownIssue("mokume#1643: 塗りの被覆を「輪郭 over 塗り」の前提で割り戻し、不透明な輪郭の内側で塗りが消える") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 一直線に並べた 3 点の太い折れ線 = 同じ 2 点を結ぶ line")
    func polylineJoin() throws {
        let broken = try PolylineJoin.reproduce()
        withKnownIssue("mokume#1644: 任意多角形の折れ目を、形自身の座標軸に沿った正方形で埋める") {
            #expect(broken == nil, "\(broken ?? "")")
        }
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
        withKnownIssue("mokume#1646: curveDetail / curveTightness が createShape の写し取って戻す一式の外にある") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 切り抜きの中の background = 切り抜きの中を同じ色で塗る (Processing・p5)")
    func clipBackground() throws {
        let broken = try ClipBackground.reproduce()
        withKnownIssue("mokume#1648: background が切り抜きを見ず、溜めた図形を捨てて面全体を塗る") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    // MARK: - 粒

    @Test("再現: texture を貼ったままでも、粒は白い板で出る")
    func particlesTexture() throws {
        let broken = try ParticlesTexture.reproduce()
        withKnownIssue("mokume#1649: GPU の経路の粒が記録した面を張り直さず、利用者の texture を読む") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: shader を当てたままでも、粒は記録した塗りで出る")
    func particlesShader() throws {
        let broken = try ParticlesShader.reproduce()
        withKnownIssue("mokume#1650: GPU の経路の粒が記録した塗りを当て直さず、利用者の断片で塗る") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 1 フレームに同じ群を 2 か所へ置く = 同じ放出の別の群を 1 か所ずつ置く")
    func particlesTwice() throws {
        let broken = try ParticlesTwice.reproduce()
        withKnownIssue("mokume#1651: 置き場所の写しが 1 つで、2 回目の particles が 1 回目を上書きする") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    // MARK: - 断片と描き場所

    @Test("再現: 本体で作った断片でも、描き場所で set を挟めば描き分けられる")
    func shaderSetGraphics() throws {
        let broken = try ShaderSetGraphics.reproduce()
        withKnownIssue("mokume#1652: 断片が作った面に縛られ、値の変更で閉じる列が描き場所に届かない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 断片の面の描き場所を置いた後で描き換えても、先に置いた形は置いた時点の絵で塗られる")
    func shaderSurfaceRedraw() throws {
        let broken = try ShaderSurfaceRedraw.reproduce()
        withKnownIssue("mokume#1653: 面を渡した描き場所を置いたと記録するのが列を閉じたときだけ") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: beginDraw の外で描き場所へ書いた画素も、image で出る")
    func graphicsSetOutside() throws {
        let broken = try GraphicsSetOutside.reproduce()
        withKnownIssue("mokume#1654: 写しを面へ戻すのが描き場所自身の flush だけで、置く側は戻さない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 効果を掛けた描き場所にフレームの外で書き戻しても、次のフレームの効果は 1 回ぶん")
    func effectsOffFrameSet() throws {
        let broken = try EffectsOffFrameSet.reproduce()
        withKnownIssue("mokume#1655: 次のフレームの最初の描き切りが、効果を通した写しを書き戻す") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    // MARK: - フレームの途中の描き切り・周囲の背景

    @Test("再現: フレームの途中で get を読んでも、影は同じ")
    func midFrameShadow() throws {
        let broken = try MidFrameShadow.reproduce()
        withKnownIssue("mokume#1656: 影の焼き付けが描き切りごとに走り、その回に溜めた立体しか見ない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 立体の後の background(.sky) は、loadPixels を挟んでも立体を消す")
    func loadPixelsSky() throws {
        let broken = try LoadPixelsSky.reproduce()
        withKnownIssue("mokume#1657: 周囲の背景が描き切りの後の奥行きと色を読み込んで、その上に描く") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: blendMode(.add) のままでも、background(.sky) は下地を置き換える")
    func addSky() throws {
        let broken = try AddSky.reproduce()
        withKnownIssue("mokume#1658: 周囲の背景がそのときの混ぜ方で描かれ、前のフレームに足される") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
