import Foundation
import Testing
import mokume

@testable import Weave

/// 候補ごとの検査。**期待値は「組み合わせて 1 回で描いた絵は、1 つずつ使って合成した絵と
/// 同じ」に置く。**
///
/// 各検査は、比べる前に**参照の側が描けていること**を押さえる。参照まで何も出ていないと、
/// 左右が一致しても何も言えないため。
@MainActor
@Suite struct WeaveTests {
    /// 同じ絵とみなす差。**同じ機械・同じフレーム番号ならバイト単位で同じ絵が出る**
    /// (mokume ADR-0001 原則 2) ので、表示の 1 段 (1/255) より小さく置く。
    static let exact: Float = 0.004

    /// 下地より明るい画素の数。参照が描けていることを押さえる。
    static func lit(_ picture: Picture) -> Int {
        picture.count { c, _, _ in max(c.red, c.green, c.blue) > 0.2 }
    }

    /// 候補を 2 経路で回し、参照が描けていることを押さえる。**比べるのは `expectSame`** —
    /// 破れを `withKnownIssue` で包むとき、参照が描けていないことまで既知の問題に数えない
    /// ように分ける。
    func render(_ key: TangleKey, sourceLocation: SourceLocation = #_sourceLocation) throws -> (
        suspect: [Int: Picture], reference: [Int: Picture]
    ) {
        let a = try run(key, .suspect)
        let b = try run(key, .reference)
        let frames = Tangles.named(key).frames
        #expect(Self.lit(b[frames]!) > 100, "参照の \(frames) 枚目が描けていない", sourceLocation: sourceLocation)
        return (a, b)
    }

    /// 全部のフレームで、2 つの経路が同じ絵であること。
    func expectSame(
        _ pair: (suspect: [Int: Picture], reference: [Int: Picture]), sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for frame in pair.suspect.keys.sorted() {
            let n = differing(pair.suspect[frame]!, pair.reference[frame]!, threshold: Self.exact)
            #expect(n == 0, "\(frame) 枚目: \(n) 画素が違う", sourceLocation: sourceLocation)
        }
    }

    /// 参照が描けていることを押さえてから、全部のフレームを比べる (陰性対照)。
    func compare(_ key: TangleKey, sourceLocation: SourceLocation = #_sourceLocation) throws {
        expectSame(try render(key, sourceLocation: sourceLocation), sourceLocation: sourceLocation)
    }

    /// 参照が描けていることを押さえてから、破れを `issue` で名指しして比べる。
    func compareKnown(_ key: TangleKey, _ issue: Comment, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let pair = try render(key, sourceLocation: sourceLocation)
        withKnownIssue(issue) { expectSame(pair, sourceLocation: sourceLocation) }
    }

    /// **形 (位置・大きさ・向き) が同じこと。** 経路の違う同じ図形は縁の濃さが違ってよく、
    /// 縁を 50% の被覆で白黒にした形が一致する (mokume ADR-0039 決定 1)。白い線を黒地に
    /// 描く候補に使う。
    func compareShape(_ key: TangleKey, _ issue: Comment, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let a = try run(key, .suspect)[1]!
        let b = try run(key, .reference)[1]!
        #expect(Self.lit(b) > 100, "参照が描けていない", sourceLocation: sourceLocation)
        let n = a.count { c, x, y in (c.red >= 0.5) != (b[x, y].red >= 0.5) }
        withKnownIssue(issue) {
            #expect(n == 0, "50% で白黒にした形が \(n) 画素違う", sourceLocation: sourceLocation)
        }
    }

    // MARK: - 混ぜ方・線の形

    @Test("blendMode(.add) で塗りと輪郭を持つ図形 = 塗りだけと輪郭だけを重ねたもの")
    func addFillStroke() throws {
        // 帯の内側半分 (矩形の左辺の内側・円の輪郭の内側) で、塗りの青が足されているか
        let b = try run(.addFillStroke, .reference)[1]!
        #expect(b[26, 52].blue > 0.3 && b[26, 52].red > 0.2, "参照の帯の内側 \(b[26, 52])")
        try compareKnown(.addFillStroke, "mokume#1643: 塗りの被覆を「輪郭 over 塗り」の前提で割り戻し、不透明な輪郭の内側で塗りが消える")
    }

    @Test("陰性対照: blendMode(.blend) なら、塗りと輪郭を持つ図形 = 重ねたもの")
    func blendFillStroke() throws { try compare(.blendFillStroke) }

    @Test("一直線に並べた 3 点の太い折れ線 = 同じ 2 点を結ぶ line")
    func polylineJoin() throws {
        // (88, 72) は直線から 11.3 離れ、太さ 20 の帯 (半分 10) の外。参照では下地のまま
        let b = try run(.polylineJoin, .reference)[1]!
        #expect(b[88, 72].red < 0.1, "参照の帯の外 \(b[88, 72])")
        try compareShape(.polylineJoin, "mokume#1644: 任意多角形の折れ目を、形自身の座標軸に沿った正方形で埋める")
    }

    @Test("scale(20) した折れ線の丸い端 = 同じ拡大の line の丸い端")
    func roundCapScale() throws {
        // (33, 33) の中心は端の円の中心 (40, 40) から 9.2 で、半径 10 の内側
        let b = try run(.roundCapScale, .reference)[1]!
        #expect(b[33, 33].red > 0.5, "参照の丸い端 \(b[33, 33])")
        try compareShape(.roundCapScale, "mokume#1645: 円板の分割数を形自身の座標の半径で決め、拡大すると端が三角形になる")
    }

    // MARK: - 状態の保存と切り抜き

    @Test("createShape の中で変えた curveDetail は、外の曲線に効かない")
    func shapeCurveDetail() throws {
        try compareKnown(.shapeCurveDetail, "mokume#1646: curveDetail / curveTightness が createShape の写し取って戻す一式の外にある")
    }

    @Test("小数の座標でも、描く矩形と同じ切り抜きは何も削らない")
    func clipFraction() throws {
        try compareKnown(.clipFraction, "mokume#1641: 切り抜きの右端・下端を Int へ切り捨て、半分覆われた列と行を落とす")
    }

    @Test("陰性対照: 整数の座標なら、描く矩形と同じ切り抜きは何も削らない")
    func clipAligned() throws { try compare(.clipAligned) }

    @Test("切り抜きの中の background = 切り抜きの中を同じ色で塗る (Processing・p5)")
    func clipBackground() throws {
        try compareKnown(.clipBackground, "mokume#1648: background が切り抜きを見ず、溜めた図形を捨てて面全体を塗る")
    }

    // MARK: - 粒

    @Test("texture を貼ったままでも、粒は白い板で出る")
    func particlesTexture() throws {
        try compareKnown(.particlesTexture, "mokume#1649: GPU の経路の粒が記録した面を張り直さず、利用者の texture を読む")
    }

    @Test("shader を当てたままでも、粒は記録した塗りで出る")
    func particlesShader() throws {
        try compareKnown(.particlesShader, "mokume#1650: GPU の経路の粒が記録した塗りを当て直さず、利用者の断片で塗る")
    }

    @Test("1 フレームに同じ群を 2 か所へ置く = 同じ放出の別の群を 1 か所ずつ置く")
    func particlesTwice() throws {
        try compareKnown(.particlesTwice, "mokume#1651: 置き場所の写しが 1 つで、2 回目の particles が 1 回目を上書きする")
    }

    // MARK: - 断片と描き場所

    @Test("本体で作った断片でも、描き場所で set を挟めば描き分けられる")
    func shaderSetGraphics() throws {
        try compareKnown(.shaderSetGraphics, "mokume#1652: 断片が作った面に縛られ、値の変更で閉じる列が描き場所に届かない")
    }

    @Test("断片の面の描き場所を置いた後で描き換えても、先に置いた形は置いた時点の絵で塗られる")
    func shaderSurfaceRedraw() throws {
        try compareKnown(.shaderSurfaceRedraw, "mokume#1653: 面を渡した描き場所を置いたと記録するのが列を閉じたときだけ")
    }

    @Test("beginDraw の外で描き場所へ書いた画素も、image で出る")
    func graphicsSetOutside() throws {
        // 書いた値は get では読める (読む口どうしで食い違う)
        let knot = Tangles.named(.graphicsSetOutside).make(.suspect)
        _ = try run(knot, frames: 1)
        #expect(gap(knot.layer.get(40, 80), Tangles.red) < Self.exact, "get が書いた値を返さない")
        try compareKnown(.graphicsSetOutside, "mokume#1654: 写しを面へ戻すのが描き場所自身の flush だけで、置く側は戻さない")
    }

    @Test("効果を掛けた描き場所にフレームの外で書き戻しても、次のフレームの効果は 1 回ぶん")
    func effectsOffFrameSet() throws {
        let a = try run(.effectsOffFrameSet, .suspect)
        let b = try run(.effectsOffFrameSet, .reference)
        #expect(Self.lit(b[2]!) > 1000)
        // 書き戻した右下の 1 画素から離れた所だけを比べる
        for frame in 1...2 {
            let n = differing(a[frame]!, b[frame]!, columns: 0..<140, threshold: Self.exact)
            if frame == 1 {
                #expect(n == 0, "1 枚目: \(n) 画素が違う")
            } else {
                withKnownIssue("mokume#1655: 次のフレームの最初の描き切りが、効果を通した写しを書き戻す") {
                    #expect(n == 0, "2 枚目: \(n) 画素が違う")
                }
            }
        }
    }

    // MARK: - フレームの途中の描き切り・周囲の背景

    @Test("フレームの途中で get を読んでも、影は同じ")
    func midFrameShadow() throws {
        try compareKnown(.midFrameShadow, "mokume#1656: 影の焼き付けが描き切りごとに走り、その回に溜めた立体しか見ない")
    }

    @Test("立体の後の background(.sky) は、loadPixels を挟んでも立体を消す")
    func loadPixelsSky() throws {
        try compareKnown(.loadPixelsSky, "mokume#1657: 周囲の背景が描き切りの後の奥行きと色を読み込んで、その上に描く")
    }

    @Test("blendMode(.add) のままでも、background(.sky) は下地を置き換える")
    func addSky() throws {
        try compareKnown(.addSky, "mokume#1658: 周囲の背景がそのときの混ぜ方で描かれ、前のフレームに足される")
    }

    @Test("陰性対照: texture を貼ったままでも、background(.sky) は同じ")
    func textureSky() throws { try compare(.textureSky) }
}
