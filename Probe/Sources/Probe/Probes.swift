import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ絵になるはずの 2 つの経路で描く。** `suspect` は疑っている口を
/// 通し、`reference` は同じ結果を別の (素朴な) 口で作る。左右が食い違えば、どちらかが
/// 約束を破っている — 窓で並べれば目で、テストで画素を読めば数で分かる。
enum Route: CaseIterable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum ProbeKey: String, CaseIterable, Sendable {
    case mirroredSolid, blendOnTransparent, ellipticArc, curveContour, fillAlpha
    case hairline, bevelJoin, spriteBleed, clipTranslate, trailingSpace
    case ellipsoidScale, cameraKeepsOrtho
}

/// 候補 1 件。`draw` は `Probes.side` 四方の面 (本体の面でも `createGraphics` の面でもよい) に、原点を左上として描く。
struct Case {
    /// テストと README が名指しする鍵。
    let key: ProbeKey
    /// 窓のタイルに出す見出し。
    let title: String
    /// 立体を描くか。立体は視点が面の中心を向くので、タイルでは描く位置の扱いが変わる。
    let solid: Bool
    let draw: @MainActor (Canvas, Route) -> Void
}

enum Probes {
    /// 1 経路ぶんの面の一辺。
    static let side = 160

    static let all: [Case] = [
        mirroredSolid, blendOnTransparent, ellipticArc, curveContour, fillAlpha,
        hairline, bevelJoin, spriteBleed, clipTranslate, trailingSpace,
        ellipsoidScale, cameraKeepsOrtho,
    ]

    static func named(_ key: ProbeKey) -> Case {
        all.first { $0.key == key }!
    }

    // MARK: - 立体

    /// 鏡映した不透明の箱。**鏡映は裏返しではない** — 映った箱は、同じ箱を逆に回したものと
    /// 同じ絵になるはずである。光は見る向きから当てるので、手前の面が明るい。
    static let mirroredSolid = Case(key: .mirroredSolid, title: "scale(-1) した箱", solid: true) { s, route in
        s.background(20)
        s.noStroke()
        s.directionalLight(255, 255, 255, 0, 0, -1)
        s.fill(230, 60, 40)
        s.translate(Float(side) / 2, Float(side) / 2)
        switch route {
        case .suspect:
            s.scale(-1, 1, 1)
            s.rotateY(0.6)
        case .reference:
            s.rotateY(-0.6)
        }
        s.rotateX(0.5)
        s.box(70)
    }

    /// `ellipsoid(a, b, c)` と、`scale(a, b, c)` した単位球。v0.11.0 で入った原形の見張り。
    static let ellipsoidScale = Case(key: .ellipsoidScale, title: "ellipsoid と scale の球", solid: true) { s, route in
        s.background(20)
        s.noStroke()
        s.directionalLight(255, 255, 255, -0.4, 0.5, -1)
        s.fill(90, 170, 230)
        s.translate(Float(side) / 2, Float(side) / 2)
        s.rotateZ(0.4)
        switch route {
        case .suspect:
            s.ellipsoid(60, 30, 20)
        case .reference:
            s.scale(60, 30, 20)
            s.sphere(1)
        }
    }

    /// `ortho()` の後の引数なしの `camera()` が写し方を残すか (v0.11.0 の修正の見張り)。
    /// 参照は `camera()` を書かない平行投影。透視に戻っていれば、箱の奥の辺が縮んで見える。
    static let cameraKeepsOrtho = Case(key: .cameraKeepsOrtho, title: "ortho の後の camera()", solid: true) { s, route in
        s.background(20)
        s.noStroke()
        s.lights()
        s.fill(240, 200, 80)
        s.ortho()
        if route == .suspect { s.camera() }
        s.translate(Float(side) / 2, Float(side) / 2)
        s.rotateX(0.6)
        s.rotateY(0.7)
        s.box(70)
    }

    // MARK: - 混ぜ方

    /// 透明な下地へ `multiply` で赤を置く。**下地が何も無いなら、混ぜる相手が無いので
    /// 赤がそのまま載る** (W3C の合成の式で αb = 0 のとき)。参照は `blend` で置いた赤。
    static let blendOnTransparent = Case(key: .blendOnTransparent, title: "透明の上の multiply", solid: false) { s, route in
        s.background(LinearRGBA.transparent)
        s.noStroke()
        s.fill(230, 40, 40)
        if route == .suspect { s.blendMode(.multiply) }
        s.rect(20, 20, 120, 120)
    }

    /// 範囲の外の不透明度。**p5 と同じく 0…255 へ締まる**なら、負は 0 (何も置かない)。
    static let fillAlpha = Case(key: .fillAlpha, title: "fill の α が負", solid: false) { s, route in
        s.background(128)
        s.noStroke()
        switch route {
        case .suspect: s.fill(255, -100)
        case .reference: s.fill(255, 0)
        }
        s.rect(20, 20, 120, 120)
    }

    // MARK: - 2D の形

    /// 横長の楕円の扇。**角は媒介変数の角** (Processing・p5 と同じ) なので、45° の切り口は
    /// `(rx cos 45°, ry sin 45°)` を通る。参照はその点を並べた多角形。
    static let ellipticArc = Case(key: .ellipticArc, title: "楕円の arc の切り口", solid: false) { s, route in
        s.background(20)
        s.noStroke()
        s.fill(230, 60, 40)
        let (cx, cy, rx, ry): (Float, Float, Float, Float) = (20, 60, 130, 40)
        switch route {
        case .suspect:
            s.arc(cx, cy, rx * 2, ry * 2, 0, Float.pi / 4)
        case .reference:
            s.beginShape()
            s.vertex(cx, cy)
            for step in 0...64 {
                let t = Float(step) / 64 * .pi / 4
                s.vertex(cx + rx * cos(t), cy + ry * sin(t))
            }
            s.endShape(.close)
        }
    }

    /// `curveVertex` の外周に、`curveVertex` の穴。**穴は外周の点を引き継がない**はず。
    /// 参照は、外周だけの形を塗ってから、穴と同じ曲線の形を下地の色で塗ったもの。
    static let curveContour = Case(key: .curveContour, title: "curveVertex の穴", solid: false) { s, route in
        s.background(20)
        s.noStroke()
        let c = Float(side) / 2
        @MainActor func ring(_ radius: Float, reversed: Bool) {
            // Catmull–Rom は両端の 1 点ずつを制御点にするので、閉じるには 3 点を足す
            let count = 8
            let indices = reversed ? Array((0..<(count + 3)).reversed()) : Array(0..<(count + 3))
            for index in indices {
                let a = Float(index % count) / Float(count) * 2 * .pi
                s.curveVertex(c + radius * cos(a), c + radius * sin(a))
            }
        }
        s.fill(80, 200, 120)
        switch route {
        case .suspect:
            s.beginShape()
            ring(70, reversed: false)
            s.beginContour()
            ring(30, reversed: true)
            s.endContour()
            s.endShape(.close)
        case .reference:
            s.beginShape()
            ring(70, reversed: false)
            s.endShape(.close)
            s.fill(20)
            s.beginShape()
            ring(30, reversed: true)
            s.endShape(.close)
        }
    }

    /// 0.1 px の縦線を、整数の位置と半端な位置に 1 本ずつ引く。**どちらも同じだけ淡い**はず。
    static let hairline = Case(key: .hairline, title: "0.1px の線の濃さ", solid: false) { s, route in
        s.background(0)
        s.stroke(255)
        s.strokeWeight(0.1)
        let x: Float = route == .suspect ? 80 : 80.5
        s.line(x, 10, x, 150)
    }

    /// 太い線の bevel。**矩形の口と、同じ 4 隅の quad の口は同じ絵**になるはず。
    static let bevelJoin = Case(key: .bevelJoin, title: "bevel の rect と quad", solid: false) { s, route in
        s.background(20)
        s.noFill()
        s.stroke(240, 200, 80)
        s.strokeWeight(30)
        s.strokeJoin(.bevel)
        switch route {
        case .suspect: s.rect(40, 40, 80, 80)
        case .reference: s.quad(40, 40, 120, 40, 120, 120, 40, 120)
        }
    }

    /// 2 コマのスプライトシート (左が赤・右が青) の左のコマだけを拡大する。
    /// **青は 1 画素も出ない**はず。参照は赤 1 色の絵。
    static let spriteBleed = Case(key: .spriteBleed, title: "コマの拡大のにじみ", solid: false) { s, route in
        s.background(20)
        let image = sheet(bothFrames: route == .suspect, in: s)
        s.image(image, 0, 0, Float(side), Float(side), 0, 0, 8, 8)
    }

    /// 平行移動の後の `clip()`。**切り抜きは描く位置と同じ座標で読む**なら、動かした先が残る。
    /// 参照は、動かした先を面の座標で切り抜いたもの。
    static let clipTranslate = Case(key: .clipTranslate, title: "translate の後の clip", solid: false) { s, route in
        s.background(20)
        s.noStroke()
        s.fill(90, 170, 230)
        switch route {
        case .suspect:
            s.translate(60, 60)
            s.clip(0, 0, 60, 60)
            s.rect(-60, -60, Float(side), Float(side))
        case .reference:
            s.clip(60, 60, 60, 60)
            s.rect(0, 0, Float(side), Float(side))
        }
    }

    /// 矩形へ流し込んだ右揃えの 1 行。**末尾の空白は行の幅に数えない**はずなので、
    /// 空白を足しても右端は動かない。
    static let trailingSpace = Case(key: .trailingSpace, title: "右揃えの末尾の空白", solid: false) { s, route in
        s.background(20)
        s.fill(240)
        s.noStroke()
        s.textSize(28)
        s.textAlign(.right, .top)
        s.text(route == .suspect ? "mokume  " : "mokume", 0, 60, Float(side) - 10, 60)
    }

    // MARK: - 絵

    private static var sheets: [Bool: Image] = [:]

    /// 8x8 のコマを 2 つ横に並べた絵。`bothFrames` が偽なら 1 コマぶんの赤だけ。
    static func sheet(bothFrames: Bool, in s: Canvas) -> Image {
        if let cached = sheets[bothFrames] { return cached }
        let image = try! s.createImage(bothFrames ? 16 : 8, 8)
        for y in 0..<8 {
            for x in 0..<image.width {
                let red = x < 8
                image.set(x, y, .display(red: red ? 0.9 : 0.1, green: 0.15, blue: red ? 0.1 : 0.9))
            }
        }
        sheets[bothFrames] = image
        return image
    }
}
