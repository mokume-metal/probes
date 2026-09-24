import Foundation
import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ動きになるはずの 2 つの経路で描く。** `suspect` は作品がふつうに
/// 書く書き方をそのまま通し、`reference` は同じ動きを疑いの入らない書き方で作る
/// (毎フレーム設定し直す・解析解を描く・値を正規化してから渡す、など)。
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum HabitKey: String, CaseIterable, Sendable {
    case styleCarry, transformReset, trailFade, trailBackground, midFrameRead, layerComposite
    case pulseScale, negativeSize, spinnerArc, nanShape, growingCount, glyphChurn
    case pmouseStroke, dragDelta, keyHeld, pauseToggle, seedPerFrame, blendCarry
    case shapeReuse, polylineTrail, setupLayer, pixelFeedback, textCenter, tintFade
    case depthNoBackground
}

/// 候補 1 件。**1 経路 = 1 本のスケッチ**で、経路ごとに別の `SketchRuntime` で回す。
///
/// Drift は 1 枚の本体の面にタイルを並べたが、ここはそれができない。候補の多くが
/// 「`setup()` で決めた描き方がフレームをまたいで残るか」「面全体を薄める」「面の画素を
/// 読む」なので、面を分け合うと隣のタイルが疑いに混ざる。
struct HabitCase {
    let key: HabitKey
    /// 窓のタイルに出す見出し。
    let title: String
    /// 1 巡のフレーム数。窓はこれを回し終えると組み直して頭から回す。
    let frames: Int
    let make: @MainActor (Route) -> any Sketch
    /// 各フレームを進める直前に呼ぶ。入力を送る候補だけが持つ。
    var input: (@MainActor (Int, SketchRuntime) -> Void)? = nil
}

enum Habits {
    /// 1 経路ぶんの一辺 (論理の大きさ)。
    static let side = 160
    static let frameRate = 30

    static let all: [HabitCase] = [
        HabitCase(key: .styleCarry, title: "setup で 1 度決めた描き方", frames: 30) { StyleCarry(route: $0) },
        HabitCase(key: .transformReset, title: "戻さない translate/rotate", frames: 30) { TransformReset(route: $0) },
        HabitCase(key: .trailFade, title: "半透明の矩形で残像を薄める", frames: 90) { TrailFade(route: $0, byBackground: false) },
        HabitCase(key: .trailBackground, title: "background(0, a) の残像", frames: 90) { TrailFade(route: $0, byBackground: true) },
        HabitCase(key: .midFrameRead, title: "描いた直後に get / pixels", frames: 40) { MidFrameRead(route: $0) },
        HabitCase(key: .layerComposite, title: "透明に塗り直す描き場所", frames: 60) { LayerComposite(route: $0) },
        HabitCase(key: .pulseScale, title: "scale で脈打つ線", frames: 60) { PulseScale(route: $0) },
        HabitCase(key: .negativeSize, title: "sin で負になる大きさ", frames: 60) { NegativeSize(route: $0) },
        HabitCase(key: .spinnerArc, title: "回り続ける arc", frames: 60) { SpinnerArc(route: $0) },
        HabitCase(key: .nanShape, title: "NaN が 1 つ混ざる", frames: 20) { NanShape(route: $0) },
        HabitCase(key: .growingCount, title: "増えて減る図形の数", frames: GrowingCount.frames) { GrowingCount(route: $0) },
        HabitCase(key: .glyphChurn, title: "毎フレーム変わる字と大きさ", frames: GlyphChurn.frames) { GlyphChurn(route: $0) },
        HabitCase(
            key: .pmouseStroke, title: "pmouse で描くお絵描き", frames: PmouseStroke.frames,
            make: { PmouseStroke(route: $0) }, input: PmouseStroke.script),
        HabitCase(
            key: .dragDelta, title: "引きずって回す", frames: DragDelta.frames,
            make: { DragDelta(route: $0) }, input: DragDelta.script),
        HabitCase(
            key: .keyHeld, title: "押し続けたキーで動かす", frames: KeyHeld.frames,
            make: { KeyHeld(route: $0) }, input: KeyHeld.script),
        HabitCase(
            key: .pauseToggle, title: "スペースで一時停止", frames: PauseToggle.frames,
            make: { PauseToggle(route: $0) }, input: PauseToggle.script),
        HabitCase(key: .seedPerFrame, title: "毎フレーム randomSeed", frames: 30) { SeedPerFrame(route: $0) },
        HabitCase(key: .blendCarry, title: "戻さない blendMode(.add)", frames: 30) { BlendCarry(route: $0) },
        HabitCase(key: .shapeReuse, title: "createShape を毎フレーム置く", frames: 60) { ShapeReuse(route: $0) },
        HabitCase(key: .polylineTrail, title: "折れ線で引く軌跡", frames: 60) { PolylineTrail(route: $0) },
        HabitCase(key: .setupLayer, title: "setup で 1 度だけ描いた層", frames: 30) { SetupLayer(route: $0) },
        HabitCase(key: .pixelFeedback, title: "前のフレームの画素を読んで書く", frames: 40) { PixelFeedback(route: $0) },
        HabitCase(key: .textCenter, title: "中央揃えの数字", frames: 60) { TextCenter(route: $0) },
        HabitCase(key: .tintFade, title: "tint の不透明度で溶け込む絵", frames: 60) { TintFade(route: $0) },
        HabitCase(key: .depthNoBackground, title: "背景を塗らない 3D", frames: 30) { DepthNoBackground(route: $0) },
    ]

    static func named(_ key: HabitKey) -> HabitCase {
        all.first { $0.key == key }!
    }

    static var settings: SketchSettings {
        SketchSettings(width: side, height: side, frameRate: frameRate, title: "routine")
    }
}

/// 表示の値 (0…255) の色。
func display(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 255) -> LinearRGBA {
    .display(red: r / 255, green: g / 255, blue: b / 255, alpha: a / 255)
}

// MARK: - フレームの境目で描き方が残るか

/// `setup()` で色・線・揃え方・混ぜ方を 1 度だけ決め、`draw()` は描くだけ。
///
/// Processing の作品のいちばんありふれた形。変換はフレームの頭で戻るが、**描き方
/// (style) はフレームをまたいで残る**のが原典の約束で、mokume の `pushStyle` /
/// `popStyle` も「描き方」を変換と別に扱っている。参照は同じ設定を毎フレームし直す。
final class StyleCarry: Sketch {
    var settings = Habits.settings
    let route: Route
    private var swatch: Image!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() {
        swatch = try! createImage(16, 16)
        swatch.fill(display(255, 255, 255))
        if route == .suspect { style() }
    }

    func style() {
        fill(230, 80, 40)
        stroke(40, 200, 120)
        strokeWeight(6)
        rectMode(.center)
        ellipseMode(.corner)
        imageMode(.center)
        tint(60, 120, 255)
        textSize(40)
        textAlign(.center, .center)
        strokeCap(.square)
    }

    /// 描く区画。検査はどれが崩れたかを区画ごとに数える。
    static let regions: [(name: String, x: Range<Int>, y: Range<Int>)] = [
        ("rect (fill・stroke・rectMode)", 0..<80, 0..<80),
        ("ellipse (ellipseMode)", 80..<160, 0..<80),
        ("image (tint・imageMode)", 0..<80, 80..<160),
        ("text (textSize・textAlign)・line (strokeCap)", 80..<160, 80..<160),
    ]

    func draw() {
        if route == .reference { style() }
        background(20)
        rect(40, 40, 44, 44)
        ellipse(96, 16, 48, 48)
        image(swatch, 40, 120, 48, 48)
        text("A", 120, 112)
        line(90, 150, 150, 150)
    }
}

/// `draw()` の中で `translate` / `rotate` / `scale` を戻さずに使う。
///
/// 変換はフレームの頭で戻るのが原典の約束。戻らなければ図形はフレームごとに
/// 飛んでいく。参照は描く前に `resetMatrix()` する。
final class TransformReset: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        if route == .reference { resetMatrix() }
        background(20)
        noStroke()
        fill(240, 200, 60)
        translate(80, 80)
        rotate(0.4)
        scale(1.2, 1.2)
        rect(-30, -15, 60, 30)
        translate(40, 0)
        fill(60, 200, 240)
        circle(0, 0, 16)
    }
}

// MARK: - 残像

/// 1 枚目に白い四角を描き、以後は毎フレーム黒を α = 20/255 で重ねて薄めていく。
///
/// 残像はクリエイティブコーディングの定番で、`fill(0, a); rect(全面)` と
/// `background(0, a)` の 2 通りで書かれる。**混ぜ方が線形なら、n 回重ねた後の白は
/// (1 − α)^n** で、8 bit の面で起きる「いつまでも消えない薄い残像」も起きないはず
/// (mokume の面は半精度の浮動小数)。参照はその解の明るさの四角を 1 枚ずつ描き直す。
final class TrailFade: Sketch {
    static let alpha: Float = 20
    var settings = Habits.settings
    let route: Route
    let byBackground: Bool
    init(route: Route, byBackground: Bool) {
        self.route = route
        self.byBackground = byBackground
    }
    convenience init() { self.init(route: .reference, byBackground: false) }

    /// n 枚目の白の明るさ (線形)。
    static func expected(frame: Int) -> Float { pow(1 - alpha / 255, Float(frame - 1)) }

    func draw() {
        noStroke()
        switch route {
        case .suspect:
            if frameCount == 1 {
                background(0)
                fill(255)
                rect(50, 50, 60, 60)
            } else if byBackground {
                background(0, Self.alpha)
            } else {
                fill(0, Self.alpha)
                rect(0, 0, width, height)
            }
        case .reference:
            background(0)
            let k = Self.expected(frame: frameCount)
            fill(LinearRGBA(straightRed: k, green: k, blue: k))
            rect(50, 50, 60, 60)
        }
    }
}

// MARK: - 画素

/// 動く赤い四角を描いた直後に、同じフレームの中で `get()` と `pixels` で読む。
/// さらに `pixels` へ緑の帯を書き、その上に青い四角を描く。
///
/// 読んだ色は下の段の見本に塗って見せる。**同じフレームで描いたものが読めて**、
/// **書いた画素の上に後から描いたものが重なる**のが期待。参照は読むはずの色を
/// そのまま塗り、帯も `rect` で描く。
final class MidFrameRead: Sketch {
    var settings = Habits.settings
    let route: Route
    /// 読んだ色 (検査が見る)。
    private(set) var readByGet: LinearRGBA = .transparent
    private(set) var readByPixels: LinearRGBA = .transparent
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static let red = display(230, 40, 40)
    static let green = display(40, 220, 90)
    static let blue = display(40, 90, 240)

    /// n 枚目の赤い四角の左端。毎フレーム 3 px ずつ右へ動く。
    static func x(_ frame: Int) -> Float { Float(10 + (frame * 3) % 100) }

    func draw() {
        background(0)
        noStroke()
        let x = Self.x(frameCount)
        fill(Self.red)
        rect(x, 10, 20, 50)
        switch route {
        case .suspect:
            readByGet = get(Int(x) + 10, 35)
            loadPixels()
            readByPixels = pixels[Int(x) + 10, 35]
            for yy in 70..<90 { for xx in 20..<140 { pixels[xx, yy] = Self.green } }
        case .reference:
            readByGet = Self.red
            readByPixels = Self.red
            fill(Self.green)
            rect(20, 70, 120, 20)
        }
        fill(Self.blue)
        rect(60, 60, 40, 40)
        // 読んだ色の見本
        fill(readByGet)
        rect(20, 120, 50, 30)
        fill(readByPixels)
        rect(90, 120, 50, 30)
    }
}

// MARK: - 重ねる

/// 毎フレーム透明に塗り直す描き場所に、半透明の円を 2 つ重ねて描き、本体へ貼る。
///
/// 「動くものだけを別の層に描く」書き方。**乗算済みの合成が正しければ、層を通しても
/// 本体へ直に描いても同じ絵**になり、前のフレームの円も残らない。参照は本体へ直に描く。
final class LayerComposite: Sketch {
    var settings = Habits.settings
    let route: Route
    private var layer: Canvas?
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() {
        if route == .suspect { layer = try! createGraphics(Habits.side, Habits.side) }
    }

    /// n 枚目の円の中心。
    static func center(_ frame: Int) -> Float { 40 + Float(frame % 40) * 2 }

    func draw() {
        background(30, 30, 60)
        let x = Self.center(frameCount)
        func paint(_ c: Canvas) {
            c.noStroke()
            c.fill(255, 120, 40, 128)
            c.circle(x, 70, 70)
            c.fill(40, 200, 255, 128)
            c.circle(x + 30, 95, 70)
        }
        if let layer {
            layer.beginDraw()
            layer.background(LinearRGBA.transparent)
            paint(layer)
            layer.endDraw()
            image(layer, 0, 0)
        } else {
            paint(canvas)
        }
    }
}

// MARK: - 揺れる大きさ

/// `scale(s)` で脈打たせる枠と線。**線の太さも s 倍になる**のが原典の約束
/// (Processing も p5 も、線は変換の中で太る)。参照は座標と太さを s 倍して直に描く。
final class PulseScale: Sketch {
    static let weight: Float = 4
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    /// n 枚目の倍率。0.4…2.0 を 2 秒で 1 往復。
    static func s(_ frame: Int) -> Float { 1.2 + 0.8 * sin(Float(frame - 1) / 30 * .pi) }

    func draw() {
        background(20)
        noFill()
        stroke(250, 220, 120)
        let s = Self.s(frameCount)
        switch route {
        case .suspect:
            translate(80, 80)
            scale(s, s)
            strokeWeight(Self.weight)
            rect(-30, -30, 60, 30)
            line(-30, 20, 30, 20)
        case .reference:
            strokeWeight(Self.weight * s)
            rect(80 - 30 * s, 80 - 30 * s, 60 * s, 30 * s)
            line(80 - 30 * s, 80 + 20 * s, 80 + 30 * s, 80 + 20 * s)
        }
    }
}

/// `sin()` で大きさを揺らすと、半分の時間は幅と高さが負になる。
///
/// 原典は負の幅を「反対側へ伸びる」と読む (`rect` は x + w から x まで、`ellipse` と
/// `circle` は絶対値)。参照は正規化した値を渡す。
final class NegativeSize: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    /// n 枚目の大きさ。−50…50 を 2 秒で 1 往復。
    static func size(_ frame: Int) -> Float { 50 * sin(Float(frame - 1) / 30 * .pi) }

    func draw() {
        background(20)
        noStroke()
        let w = Self.size(frameCount)
        switch route {
        case .suspect:
            fill(240, 120, 60)
            rect(60, 20, w, 40)
            fill(80, 200, 120)
            ellipse(40, 110, w, w * 0.6)
            fill(100, 140, 250)
            circle(120, 110, w)
        case .reference:
            fill(240, 120, 60)
            rect(min(60, 60 + w), 20, abs(w), 40)
            fill(80, 200, 120)
            ellipse(40, 110, abs(w), abs(w * 0.6))
            fill(100, 140, 250)
            circle(120, 110, abs(w))
        }
    }
}

/// 時刻で回し続けるローディングの円弧。角は増え続け、逆回しなら負になる。
///
/// 長く展示すると角は数千ラジアンになる。**角は 2π の周期で同じ弧**のはず。参照は
/// 2π で割った余りを渡す。
final class SpinnerArc: Sketch {
    /// 展示して 1 時間ほど経った角 (60 fps × 0.1 rad / frame)。
    static let offset: Double = 2 * .pi * 3000
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static func wrap(_ a: Double) -> Float {
        let r = a.truncatingRemainder(dividingBy: 2 * .pi)
        return Float(r < 0 ? r + 2 * .pi : r)
    }

    func draw() {
        background(20)
        noFill()
        strokeWeight(8)
        let t = Double(frameCount) * 0.1
        // 左: 長く回った正の角 / 右: 逆回しの負の角
        let spins: [(x: Float, start: Double, color: (Float, Float, Float))] = [
            (45, Self.offset + t, (250, 200, 80)),
            (115, -t, (80, 200, 250)),
        ]
        for spin in spins {
            stroke(spin.color.0, spin.color.1, spin.color.2)
            let span = 1.5 * Double.pi
            switch route {
            case .suspect:
                arc(spin.x, 80, 50, 50, Float(spin.start), Float(spin.start + span))
            case .reference:
                let a = Self.wrap(spin.start)
                arc(spin.x, 80, 50, 50, a, a + Float(span))
            }
        }
    }
}

/// 零ベクトルを正規化するなどで、座標に NaN が 1 つ混ざる。
///
/// 作品では珍しくない。**NaN の図形が描かれないのはよいが、同じフレームの他の図形や、
/// 次のフレームを巻き込まない**のが期待。参照は NaN の図形を描かない。
final class NanShape: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        background(20)
        noStroke()
        fill(240, 120, 60)
        rect(10, 10, 60, 60)
        if route == .suspect && frameCount <= 10 {
            let bad = Float.nan
            fill(255)
            circle(bad, 80, 20)
            stroke(255)
            line(80, 80, bad, 20)
            noStroke()
            beginShape()
            vertex(20, 100)
            vertex(bad, 150)
            vertex(60, 140)
            endShape(.close)
            rect(90, 90, Float.infinity, 20)
        }
        fill(80, 200, 120)
        circle(120, 40, 50)
        stroke(100, 140, 250)
        strokeWeight(5)
        line(20, 140, 140, 140)
    }
}

// MARK: - 数と量

/// 図形の数がフレームごとに増え (数十 → 25600)、途中で減る。粒の配列を回す作品の形。
///
/// 1 px 四方の四角を面の画素に 1 つずつ置くので、**光った画素の数 = 置いた数**になる。
/// 参照は同じ数を最初のフレームで置く。
final class GrowingCount: Sketch {
    static let frames = 20
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    /// n 枚目に置く数。16 枚目で面を埋め、17 枚目から 3000 に減る。
    static func count(_ frame: Int) -> Int {
        frame <= 16 ? min(Habits.side * Habits.side, frame * frame * 100) : 3000
    }

    func draw() {
        background(0)
        noStroke()
        fill(255, 200, 80)
        let n = route == .suspect ? Self.count(frameCount) : Self.count(Self.frames)
        for i in 0..<n {
            rect(Float(i % Habits.side), Float(i / Habits.side), 1, 1)
        }
    }
}

/// 毎フレーム違う字を違う大きさで描き (カウンタや流れる文)、最後に "Hello" に戻る。
///
/// 字の形は大きさ × 字ごとに焼いて持つのがふつうで、その置き場が溢れたり入れ替わったり
/// しても、**同じ字は同じ形で出る**のが期待。参照は "Hello" だけを描く。
final class GlyphChurn: Sketch {
    static let frames = 40
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static func hello(_ s: some Sketch) {
        s.fill(255)
        s.textSize(36)
        s.textAlign(.left, .baseline)
        s.text("Hello", 16, 96)
    }

    func draw() {
        background(20)
        noStroke()
        let churn = route == .suspect && frameCount > 1 && frameCount < Self.frames
        guard churn else { return Self.hello(self) }
        // 大きさを毎フレーム端数で変え (脈打つ字)、字も入れ替える (漢字 240 字 + カウンタ)
        fill(200, 220, 255)
        textAlign(.left, .top)
        textSize(9 + Float(frameCount) * 2.37)
        let base = 0x4E00 + frameCount * 240
        let line = String(String.UnicodeScalarView((0..<240).compactMap { Unicode.Scalar(base + $0) }))
        text(line, 0, 0, width, height)
        textSize(20 + Float(frameCount % 7) * 3.1)
        text("\(frameCount * 7919)", 4, 120)
    }
}

// MARK: - 入力

/// 押している間だけ `line(pmouseX, pmouseY, mouseX, mouseY)` を引くお絵描き。背景は 1 度だけ。
///
/// 1 画目を引いて離し、動かして別の場所で 2 画目を引く。**離していた間の移動は
/// 線にならず、書き始めも欠けない**のが期待。参照は同じ 2 画を `line` で直に引く。
final class PmouseStroke: Sketch {
    static let frames = 26
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    /// 1 画目は (20, 40) → (100, 40)、2 画目は (100, 120) → (140, 120)。
    static let first: (from: SIMD2<Float>, to: SIMD2<Float>) = ([20, 40], [100, 40])
    static let second: (from: SIMD2<Float>, to: SIMD2<Float>) = ([100, 120], [140, 120])

    /// 各フレームを進める直前に送る出来事。1 フレームに 1 つずつ動かす。
    static let script: @MainActor (Int, SketchRuntime) -> Void = { frame, runtime in
        let input = runtime.input
        switch frame {
        case 1: input.enqueue(.mouseMoved(x: 20, y: 40))  // 押す前に指を置く
        case 2: input.enqueue(.mouseDown(x: 20, y: 40, button: 0))
        case 3...10: input.enqueue(.mouseMoved(x: 20 + Float(frame - 2) * 10, y: 40))
        case 11: input.enqueue(.mouseUp(x: 100, y: 40, button: 0))
        case 12...15: input.enqueue(.mouseMoved(x: 100, y: 40 + Float(frame - 11) * 20))
        case 16: input.enqueue(.mouseDown(x: 100, y: 120, button: 0))
        case 17...20: input.enqueue(.mouseMoved(x: 100 + Float(frame - 16) * 10, y: 120))
        case 21: input.enqueue(.mouseUp(x: 140, y: 120, button: 0))
        default: break
        }
    }

    func draw() {
        stroke(255)
        strokeWeight(4)
        strokeCap(.round)
        switch route {
        case .suspect:
            if frameCount == 1 { background(0) }
            if isMousePressed { line(pmouseX, pmouseY, mouseX, mouseY) }
        case .reference:
            background(0)
            if frameCount >= 11 { line(Self.first.from.x, Self.first.from.y, Self.first.to.x, Self.first.to.y) }
            if frameCount >= 21 { line(Self.second.from.x, Self.second.from.y, Self.second.to.x, Self.second.to.y) }
        }
    }
}


/// 押したまま引きずって棒を回す。回す量は `mouseDragged(deltaX:deltaY:)` の引数で足す。
///
/// 説明は「1 フレームに移動が 3 件届けば 3 回呼ばれ、**足せばフレーム合計 (`dragX`) と
/// 一致する**」「**押した瞬間には増えない**」と約束している。参照は `draw()` で `dragX`
/// を足す。2 回目は離れた場所で押すので、押した瞬間の飛びが入れば食い違う。
final class DragDelta: Sketch {
    static let frames = 30
    /// 押している間に横へ動いた量の合計 (押した瞬間の飛びは含めない)。
    static let travel: Float = 8 * 3 * 6 + 6 * 3 * -4
    var settings = Habits.settings
    let route: Route
    private(set) var angle: Float = 0
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    /// 1 回目: (20, 80) で押し、8 フレーム × 3 件ずつ右へ 6 px。
    /// 2 回目: (150, 30) で押し、6 フレーム × 3 件ずつ左へ 4 px。
    static let script: @MainActor (Int, SketchRuntime) -> Void = { frame, runtime in
        let input = runtime.input
        switch frame {
        case 2: input.enqueue(.mouseDown(x: 20, y: 80, button: 0))
        case 3...10:
            for k in 1...3 { input.enqueue(.mouseMoved(x: 20 + Float((frame - 3) * 3 + k) * 6, y: 80)) }
        case 11: input.enqueue(.mouseUp(x: 164, y: 80, button: 0))
        case 12: input.enqueue(.mouseMoved(x: 150, y: 30))
        case 14: input.enqueue(.mouseDown(x: 150, y: 30, button: 0))
        case 15...20:
            for k in 1...3 { input.enqueue(.mouseMoved(x: 150 - Float((frame - 15) * 3 + k) * 4, y: 30)) }
        case 21: input.enqueue(.mouseUp(x: 78, y: 30, button: 0))
        default: break
        }
    }

    func mouseDragged(deltaX: Float, deltaY: Float) {
        if route == .suspect { angle += deltaX }
    }

    func draw() {
        if route == .reference { angle += dragX }
        background(20)
        stroke(250, 200, 80)
        strokeWeight(8)
        translate(80, 80)
        rotate(angle * 0.01)
        line(-60, 0, 60, 0)
    }
}

/// 押し続けた矢印キーで四角を動かす (ゲームの定番)。途中で OS のキーの繰り返しが届く。
///
/// **押している間は毎フレーム同じだけ進み、離せば止まる**のが期待。繰り返しの出来事が
/// 状態を崩さないことも。参照は押していたフレーム数から位置を計算して描く。
final class KeyHeld: Sketch {
    static let frames = 26
    static let step: Float = 5
    var settings = Habits.settings
    let route: Route
    private(set) var x: Float = 10
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static let script: @MainActor (Int, SketchRuntime) -> Void = { frame, runtime in
        let input = runtime.input
        switch frame {
        case 3: input.enqueue(.keyDown(code: .arrowRight, characters: "", isRepeat: false))
        case 8...14: input.enqueue(.keyDown(code: .arrowRight, characters: "", isRepeat: true))
        case 20: input.enqueue(.keyUp(code: .arrowRight))
        default: break
        }
    }

    /// 押していたフレーム (3 枚目で押し、20 枚目で離す)。
    static func held(through frame: Int) -> Int { max(0, min(frame, 19) - 2) }

    func draw() {
        switch route {
        case .suspect: if isKeyDown(.arrowRight) { x += Self.step }
        case .reference: x = 10 + Self.step * Float(Self.held(through: frameCount))
        }
        background(20)
        noStroke()
        fill(80, 220, 160)
        rect(x, 60, 20, 40)
    }
}

/// スペースで `noLoop()` と `loop()` を切り替える一時停止。止まっている間も窓は前の絵を出す。
///
/// **止めている間は `draw()` が呼ばれず絵がそのまま残り、再開すると `frameCount` の続きから
/// 動く**のが期待。参照は止めずに回した絵で、同じ `frameCount` の絵と比べる。
final class PauseToggle: Sketch {
    static let frames = 30
    var settings = Habits.settings
    let route: Route
    private var running = true
    /// 最後に描いたときの `frameCount`。
    private(set) var drawn = 0
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static let script: @MainActor (Int, SketchRuntime) -> Void = { frame, runtime in
        if frame == 8 || frame == 18 {
            runtime.input.enqueue(.keyDown(code: .space, characters: " ", isRepeat: false))
            runtime.input.enqueue(.keyUp(code: .space))
        }
    }

    func keyPressed() {
        guard route == .suspect, keyCode == .space else { return }
        running.toggle()
        if running { loop() } else { noLoop() }
    }

    func draw() {
        drawn = frameCount
        background(20)
        noStroke()
        fill(240, 120, 60)
        rect(Float((frameCount * 4) % 140), 60, 20, 40)
        fill(255)
        textSize(16)
        text("\(frameCount)", 10, 20)
    }
}

// MARK: - 種

/// `draw()` の頭で `randomSeed` / `noiseSeed` を撒き直し、毎フレーム同じ配置を描く。
///
/// 「ランダムだが止まって見える絵」の定番。描いた後で別の用途に `random()` を
/// フレームごとに違う回数だけ引いても、**次のフレームの頭で撒き直せば同じ並び**に戻る
/// のが期待。参照は 1 枚目の配置 (1 枚目は撒いた直後なので疑いが入らない)。
final class SeedPerFrame: Sketch {
    var settings = Habits.settings
    let route: Route
    private var jitter: Float = 0
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        background(20)
        noStroke()
        randomSeed(7)
        noiseSeed(3)
        for i in 0..<40 {
            let x = random(Float(Habits.side))
            let y = random(20, Float(Habits.side) - 20)
            let d = 4 + 20 * noise(Float(i) * 0.37, 1.5)
            fill(random(80, 255), random(80, 255), 180)
            circle(x, y, d)
        }
        // 描いた後で別の用途に引く (フレームごとに回数が違う)
        if route == .suspect {
            for _ in 0..<(frameCount * 13 % 29) { jitter += random(-1, 1) + noise(jitter) }
        }
    }
}


/// 光る粒のために `blendMode(.add)` にして、戻さずに終える。次のフレームの頭は `background`。
///
/// **下地を塗るのは混ぜ方によらず「塗り潰し」**で、足し算の混ぜ方が残っていても前の絵は
/// 消えるのが期待 (原典の `background` は混ぜ方を見ない)。参照は頭で `.blend` に戻す。
final class BlendCarry: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        if route == .reference { blendMode(.blend) }
        background(10)
        blendMode(.add)
        noStroke()
        fill(60, 30, 120)
        for i in 0..<5 {
            circle(50 + Float(i) * 15, 80 + 20 * sin(Float(frameCount) * 0.2 + Float(i)), 50)
        }
    }
}

/// `setup()` で `createShape` した星を、毎フレーム動かしながら何か所にも置く。
///
/// 同じ形の使い回しは粒や群れの定番。**置いた場所に、その場で頂点を並べたのと同じ形が
/// 出る**のが期待。参照は同じ頂点を `translate` して毎フレーム描く。
final class ShapeReuse: Sketch {
    var settings = Habits.settings
    let route: Route
    private var star: Shape = .empty
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static let points: [SIMD2<Float>] = (0..<10).map { i in
        let r: Float = i % 2 == 0 ? 14 : 6
        let a = Float(i) * .pi / 5 - .pi / 2
        return [r * cos(a), r * sin(a)]
    }

    func outline() {
        noStroke()
        fill(250, 210, 90)
        beginShape()
        for p in Self.points { vertex(p.x, p.y) }
        endShape(.close)
    }

    func setup() {
        if route == .suspect { star = createShape { outline() } }
    }

    /// n 枚目に置く場所。5 × 4 の格子が右へ流れる。
    static func spots(_ frame: Int) -> [SIMD2<Float>] {
        (0..<20).map { i in
            [Float(i % 5) * 34 + 12 + Float((frame * 2) % 34) - 17, Float(i / 5) * 36 + 25]
        }
    }

    func draw() {
        background(20)
        for p in Self.spots(frameCount) {
            switch route {
            case .suspect:
                shape(star, p.x, p.y)
            case .reference:
                push()
                translate(p.x, p.y)
                outline()
                pop()
            }
        }
    }
}

/// 動く点の最近 40 か所を、`beginShape` / `vertex` の折れ線で引く軌跡。
///
/// 折れ目も端も丸い太線は、**1 本ずつ引いた丸い端の線分を重ねたものと同じ形**になるはず。
/// 参照は線分を 1 本ずつ引く。
final class PolylineTrail: Sketch {
    static let length = 40
    var settings = Habits.settings
    let route: Route
    private var trail: [SIMD2<Float>] = []
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        let t = Float(frameCount) * 0.09
        trail.append([80 + 60 * sin(t * 1.3), 80 + 55 * sin(t * 2.1 + 0.5)])
        if trail.count > Self.length { trail.removeFirst() }
        background(20)
        noFill()
        stroke(120, 220, 255)
        strokeWeight(7)
        strokeCap(.round)
        strokeJoin(.round)
        switch route {
        case .suspect:
            beginShape()
            for p in trail { vertex(p.x, p.y) }
            endShape()
        case .reference:
            for (p, q) in zip(trail, trail.dropFirst()) { line(p.x, p.y, q.x, q.y) }
        }
    }
}


// MARK: - 層と画素をフレームをまたいで使う

/// `setup()` で描き場所に 1 度だけ背景の模様を描き、毎フレーム貼ってから動くものを描く。
///
/// 重い下絵を先に焼いておく定番 (p5 でも Processing でも `setup` で `pg` に描く)。
/// **描き場所の中身は描いた後ずっと残る**のが期待。参照は毎フレーム同じ模様を描き直す。
final class SetupLayer: Sketch {
    var settings = Habits.settings
    let route: Route
    private var layer: Canvas!
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func pattern(_ c: Canvas) {
        c.background(30, 40, 70)
        c.noStroke()
        for i in 0..<8 {
            c.fill(60 + Float(i) * 20, 90, 200 - Float(i) * 15)
            c.rect(Float(i) * 20, Float(i % 3) * 30 + 20, 20, 90)
        }
    }

    func setup() {
        layer = try! createGraphics(Habits.side, Habits.side)
        if route == .suspect {
            layer.beginDraw()
            pattern(layer)
            layer.endDraw()
        }
    }

    func draw() {
        if route == .reference {
            layer.beginDraw()
            pattern(layer)
            layer.endDraw()
        }
        image(layer, 0, 0)
        noStroke()
        fill(250, 220, 90)
        circle(20 + Float(frameCount * 4 % 120), 80, 24)
    }
}

/// 背景を塗らず、`pixels` で前のフレームの絵を読んで 1 px 右へずらして書き戻す。
///
/// 砂や生命ゲームのような「画素が次の画素を決める」作品の形。**`loadPixels()` はその
/// 時点の面を読み、書いた画素は次のフレームに残る**のが期待。参照は 1 枚目の模様を
/// フレーム数ぶんずらした位置に直に描く。
final class PixelFeedback: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func seed(at dx: Float) {
        noStroke()
        fill(250, 120, 60)
        rect(10 + dx, 30, 12, 40)
        fill(80, 200, 240)
        rect(30 + dx, 90, 20, 12)
    }

    func draw() {
        switch route {
        case .suspect:
            if frameCount == 1 {
                background(0)
                seed(at: 0)
                return
            }
            loadPixels()
            let side = Habits.side
            for y in 0..<side {
                for x in stride(from: side - 1, to: 0, by: -1) { pixels[x, y] = pixels[x - 1, y] }
                pixels[0, y] = LinearRGBA(straightRed: 0, green: 0, blue: 0)
            }
        case .reference:
            background(0)
            seed(at: Float(frameCount - 1))
        }
    }
}

/// 毎フレーム桁の変わる数字を `textAlign(.center)` で真ん中に置く。
///
/// **中央揃えは `x − textWidth / 2` に左揃えで置いたのと同じ場所**になるはず。
/// 参照は `textWidth` で左端を計算する。
final class TextCenter: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static func label(_ frame: Int) -> String { "\(frame * frame * 37 % 100_003)" }

    func draw() {
        background(20)
        fill(255)
        textSize(28)
        let label = Self.label(frameCount)
        switch route {
        case .suspect:
            textAlign(.center, .baseline)
            text(label, 80, 90)
        case .reference:
            textAlign(.left, .baseline)
            text(label, 80 - textWidth(label) / 2, 90)
        }
    }
}

/// 白い絵を `tint(255, a)` で 0 から溶け込ませる (a がフレームごとに増える)。
///
/// **`tint` の 4 つ目は不透明度**なので、同じ色の四角を `fill(255, a)` で塗ったのと
/// 同じ濃さになるはず。参照は `fill` の四角。
final class TintFade: Sketch {
    var settings = Habits.settings
    let route: Route
    private var white: Image!
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    static func alpha(_ frame: Int) -> Float { min(255, Float(frame - 1) * 5) }

    func setup() {
        white = try! createImage(8, 8)
        white.fill(display(255, 255, 255))
    }

    func draw() {
        background(40, 60, 120)
        noStroke()
        let a = Self.alpha(frameCount)
        switch route {
        case .suspect:
            tint(255, a)
            image(white, 30, 30, 100, 100)
            noTint()
        case .reference:
            fill(255, a)
            rect(30, 30, 100, 100)
        }
    }
}

// MARK: - 立体

/// 背景を塗らずに回す 3D。1 枚目に手前の大きな赤い箱を描き、以後は奥の小さな青い箱だけ。
///
/// 原典は奥行きをフレームごとに消す (色は残る)。**新しいフレームの青い箱は、前の
/// フレームの赤い絵の上に出る**のが期待。参照は同じ青い箱を下地の上に描く (中心の色だけ比べる)。
final class DepthNoBackground: Sketch {
    var settings = Habits.settings
    let route: Route
    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        noStroke()
        lights()
        if route == .reference || frameCount == 1 { background(20) }
        if route == .suspect && frameCount == 1 {
            push()
            translate(80, 80, 60)
            fill(230, 50, 50)
            box(90)
            pop()
            return
        }
        push()
        translate(80, 80, -120)
        rotateY(Float(frameCount) * 0.1)
        rotateX(0.4)
        fill(50, 90, 240)
        box(60)
        pop()
    }
}
