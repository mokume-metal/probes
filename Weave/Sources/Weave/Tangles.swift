import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ絵になるはずの 2 つの経路で描く。** `suspect` は機能を組み合わせて
/// 1 回で描き、`reference` は同じ機能を 1 つずつ使って同じ絵になるよう合成する (塗りだけの
/// 形と輪郭だけの形を重ねる・別の粒の群を使う・読み取りの行を抜く、など)。**食い違えば、
/// 組み合わせた片方の状態がもう片方の経路へ漏れているか、届いていない。**
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum TangleKey: String, CaseIterable, Sendable {
    // 混ぜ方・線の形
    case addFillStroke, blendFillStroke, polylineJoin, roundCapScale
    // 状態の保存と切り抜き
    case shapeCurveDetail, clipFraction, clipAligned, clipBackground
    // 粒
    case particlesTexture, particlesShader, particlesTwice
    // 断片と描き場所
    case shaderSetGraphics, shaderSurfaceRedraw, graphicsSetOutside, effectsOffFrameSet
    // フレームの途中の描き切り・周囲の背景
    case midFrameShadow, loadPixelsSky, addSky, textureSky
}

/// 候補 1 件。**1 経路 = 1 本のスケッチ**で、経路ごとに別の `SketchRuntime` で回す
/// (Aftermath と同じ形)。
struct TangleCase {
    let key: TangleKey
    /// 窓のタイルに出す見出し。
    let title: String
    /// 1 巡のフレーム数。
    let frames: Int
    /// 資源を作る。`setup()` で 1 度だけ呼ぶ。
    let prepare: @MainActor (Knot) -> Void
    /// 1 枚ぶん描く。経路は `knot.route`、何枚目かは `knot.frame` で分ける。
    let body: @MainActor (Knot) -> Void

    init(
        _ key: TangleKey, _ title: String, frames: Int = 1,
        prepare: @escaping @MainActor (Knot) -> Void = { _ in },
        _ body: @escaping @MainActor (Knot) -> Void
    ) {
        self.key = key
        self.title = title
        self.frames = frames
        self.prepare = prepare
        self.body = body
    }

    @MainActor func make(_ route: Route) -> Knot { Knot(route: route, prepare: prepare, body: body) }
}

/// 候補 1 件の 1 経路のスケッチ。資源の置き場を持ち、描くのは候補の `body` に任せる。
final class Knot: Sketch {
    var settings = Tangles.settings
    let route: Route
    /// 1 始まりのフレーム番号 (`draw()` の頭で進める)。
    private(set) var frame = 0
    var cloud: Particles!
    var cloud2: Particles!
    var layer: Canvas!
    var paint: Shader!

    private let prepare: (Knot) -> Void
    private let body: (Knot) -> Void

    init(route: Route, prepare: @escaping (Knot) -> Void, body: @escaping (Knot) -> Void) {
        self.route = route
        self.prepare = prepare
        self.body = body
    }
    /// `Sketch` が求めるだけで、窓からもテストからも呼ばない。
    convenience init() { self.init(route: .reference, prepare: { _ in }, body: { _ in }) }

    var suspect: Bool { route == .suspect }

    func setup() { prepare(self) }

    func draw() {
        frame += 1
        body(self)
    }
}

enum Tangles {
    /// 1 経路ぶんの一辺 (論理の大きさ)。
    static let side = 160
    static let frameRate = 30

    static var settings: SketchSettings {
        SketchSettings(width: side, height: side, frameRate: frameRate, title: "weave")
    }

    static func named(_ key: TangleKey) -> TangleCase {
        all.first { $0.key == key }!
    }

    static let all: [TangleCase] = [
        // MARK: 混ぜ方・線の形

        // 塗りと輪郭を 1 つの図形で描く = 塗りだけの図形の上に輪郭だけの図形を重ねる。
        // 距離関数の経路は「三角形を重ねたのと同じ式」を名乗る (Shapes.metal の
        // mokume_formFragment) が、塗りの被覆を「輪郭 over 塗り」の前提で割り戻す
        TangleCase(.addFillStroke, "blendMode(.add) × 塗りと輪郭を両方持つ図形") { k in
            k.background(0)
            k.blendMode(.add)
            if k.suspect {
                Tangles.fillAndStroke(k, fill: true, stroke: true)
            } else {
                Tangles.fillAndStroke(k, fill: true, stroke: false)
                Tangles.fillAndStroke(k, fill: false, stroke: true)
            }
            k.blendMode(.blend)
        },
        // 陰性対照: `.blend` なら、重ねた 2 つと 1 つの図形は同じ絵になる
        TangleCase(.blendFillStroke, "blendMode(.blend) × 塗りと輪郭 (陰性対照)") { k in
            k.background(0)
            if k.suspect {
                Tangles.fillAndStroke(k, fill: true, stroke: true)
            } else {
                Tangles.fillAndStroke(k, fill: true, stroke: false)
                Tangles.fillAndStroke(k, fill: false, stroke: true)
            }
        },
        // 一直線に並べた 3 点の折れ線 = 同じ 2 点を結ぶ `line()`。折れ目は、形自身の
        // 座標軸に沿った正方形で埋められる (Canvas+Outline.swift の appendSquare)
        TangleCase(.polylineJoin, "斜めの折れ線 × 太い線の折れ目") { k in
            k.background(0)
            k.noFill()
            k.stroke(255)
            k.strokeWeight(20)
            if k.suspect {
                k.beginShape()
                k.vertex(20, 20)
                k.vertex(80, 80)
                k.vertex(140, 140)
                k.endShape()
            } else {
                k.line(20, 20, 140, 140)
            }
        },
        // 拡大した折れ線の丸い端 = 同じ拡大の `line()`。円板の分割数を、形自身の座標の
        // 半径 (0.5) で決めている (Canvas+Folding.swift の segmentCount)
        TangleCase(.roundCapScale, "scale(20) × 折れ線の丸い端") { k in
            k.background(0)
            k.noFill()
            k.stroke(255)
            k.scale(20, 20)
            k.strokeWeight(1)
            if k.suspect {
                k.beginShape()
                k.vertex(2, 2)
                k.vertex(6, 2)
                k.endShape()
            } else {
                k.line(2, 2, 6, 2)
            }
        },

        // MARK: 状態の保存と切り抜き

        // `createShape` の中で変えた曲線の細かさは、外の曲線に効かない。createShape は
        // 「記録の間に触った状態は外へ出さない」と名乗る (Canvas+Shape.swift) が、
        // curveDetail / curveTightness は写し取って戻す一式の外にある
        TangleCase(.shapeCurveDetail, "createShape × curveDetail") { k in
            k.background(0)
            _ = k.createShape {
                if k.suspect { k.curveDetail(2) }
                k.rect(0, 0, 10, 10)
            }
            k.noFill()
            k.stroke(255)
            k.strokeWeight(4)
            k.beginShape()
            k.vertex(20, 130)
            k.bezierVertex(20, 20, 140, 20, 140, 130)
            k.endShape()
        },
        // 描く矩形と同じ切り抜きは、何も削らない。右端・下端は Int へ切り捨てるが、左端・
        // 上端は外側へ丸まる (Canvas+Style.swift の clip)
        TangleCase(.clipFraction, "clip × 小数の座標") { k in
            k.background(0)
            k.noStroke()
            k.fill(255)
            if k.suspect { k.clip(10.5, 10.5, 40, 40) }
            k.rect(10.5, 10.5, 40, 40)
            k.noClip()
        },
        // 陰性対照: 整数の座標なら、同じ矩形の切り抜きは何も削らない
        TangleCase(.clipAligned, "clip × 整数の座標 (陰性対照)") { k in
            k.background(0)
            k.noStroke()
            k.fill(255)
            if k.suspect { k.clip(10, 10, 40, 40) }
            k.rect(10, 10, 40, 40)
            k.noClip()
        },
        // 切り抜きの中の `background()` = 切り抜きの中を同じ色の矩形で塗る。Processing
        // (P2D の glClear は scissor に従う) と p5 (2D の clip の中の fillRect) は内側だけを
        // 塗る。mokume は溜めた図形を捨て、描き切りの clear で面全体を塗る
        TangleCase(.clipBackground, "clip × background") { k in
            k.background(0, 0, 255)
            k.noStroke()
            k.fill(0, 255, 0)
            k.rect(100, 0, 60, 160)
            k.clip(0, 0, 80, 160)
            if k.suspect {
                k.background(255, 0, 0)
            } else {
                k.fill(255, 0, 0)
                k.rect(0, 0, 160, 160)
            }
            k.noClip()
        },

        // MARK: 粒

        // `texture()` を貼ったままでも、粒は白い板で出る。CPU の経路 (「速い側を照らす
        // 物差し」) は記録した面を張り直すが、GPU の経路 (既定) は張り直さない
        // (Canvas+Particles.swift の placeFromGPU)
        TangleCase(.particlesTexture, "particles × texture", prepare: Tangles.prepareCloud) { k in
            k.background(0)
            if k.suspect { k.texture(k.layer) } else { k.noTexture() }
            Tangles.emitCloud(k, k.cloud, x: 80)
            k.particles(k.cloud)
            k.noTexture()
        },
        // `shader()` を当てたままでも、粒は記録した塗りで出る (同じく GPU の経路だけが
        // 記録した塗りを当て直さない)
        TangleCase(.particlesShader, "particles × shader", prepare: Tangles.prepareCloud) { k in
            k.background(0)
            if k.suspect { k.shader(k.paint) } else { k.resetShader() }
            Tangles.emitCloud(k, k.cloud, x: 80)
            k.particles(k.cloud)
            k.resetShader()
        },
        // 1 フレームで同じ群を 2 か所に置く = 同じ放出をした別の群を 1 か所ずつ置く。
        // 粒の置き場所の写しは 1 つしかなく、2 回目が 1 回目を上書きする
        // (Particles.write → Numbers.write)
        TangleCase(.particlesTwice, "1 フレームに particles を 2 回", prepare: Tangles.prepareCloud) { k in
            k.background(0)
            Tangles.emitCloud(k, k.cloud, x: 0)
            if !k.suspect { Tangles.emitCloud(k, k.cloud2, x: 0) }
            k.push()
            k.translate(40, 0)
            k.particles(k.cloud)
            k.pop()
            k.push()
            k.translate(120, 0)
            k.particles(k.suspect ? k.cloud : k.cloud2)
            k.pop()
        },

        // MARK: 断片と描き場所

        // 本体で作った断片を描き場所で使い、`set` を挟んで 2 つ描く = 描き場所で作った
        // 断片で同じことをする。断片は作った面に縛られ、値の変更で閉じる列が描き場所の
        // 側に届かない (Shader.set → canvas.shaderValuesWillChange)
        TangleCase(
            .shaderSetGraphics, "本体の断片 × 描き場所で set を挟む",
            prepare: { k in
                k.layer = try! k.createGraphics(Tangles.side, Tangles.side)
                k.paint =
                    k.suspect
                    ? try! k.makeShader(Tangles.redByValue, values: ["k": 0])
                    : try! k.layer.makeShader(Tangles.redByValue, values: ["k": 0])
            }
        ) { k in
            k.background(0)
            k.layer.beginDraw()
            k.layer.background(0)
            k.layer.noStroke()
            k.layer.shader(k.paint)
            k.paint.set("k", 1)
            k.layer.rect(0, 0, 80, 160)
            k.paint.set("k", 0.25)
            k.layer.rect(80, 0, 80, 160)
            k.layer.resetShader()
            k.layer.endDraw()
            k.image(k.layer, 0, 0)
        },
        // 断片の面に渡した描き場所を、置いた後で描き換えても、先に置いた形は置いた時点の
        // 絵で塗られる (Sketch+Graphics.swift「先に置いた形が、後から描き換えた絵に化ける
        // ことはない」)。reference は描き換える前に断片を外して列を閉じる
        TangleCase(
            .shaderSurfaceRedraw, "断片の面の描き場所 × 置いた後の描き換え",
            prepare: { k in
                k.layer = try! k.createGraphics(Tangles.side, Tangles.side)
                k.paint = try! k.makeShader(Tangles.sampleLayer, surfaces: ["pic": .graphics(k.layer)])
            }
        ) { k in
            k.background(0)
            k.noStroke()
            k.layer.beginDraw()
            k.layer.background(255, 0, 0)
            k.layer.endDraw()
            k.shader(k.paint)
            k.rect(0, 0, 80, 160)
            if !k.suspect { k.resetShader() }
            k.layer.beginDraw()
            k.layer.background(0, 0, 255)
            k.layer.endDraw()
            k.resetShader()
            k.image(k.layer, 80, 0, 80, 160)
        },
        // `beginDraw()` の外で描き場所へ書いた画素 = `beginDraw()` / `endDraw()` で囲んで
        // 書いた画素。`get` は書いた値を返すのに、`image` には出ない (写しを面へ戻すのが
        // 自分の flush だけ)
        TangleCase(
            .graphicsSetOutside, "描き場所の外の set × image",
            prepare: { k in
                k.layer = try! k.createGraphics(Tangles.side, Tangles.side)
                if !k.suspect { k.layer.beginDraw() }
                for y in 0..<Tangles.side {
                    for x in 0..<(Tangles.side / 2) { k.layer.set(x, y, Tangles.red) }
                }
                if !k.suspect { k.layer.endDraw() }
            }
        ) { k in
            k.background(0)
            k.image(k.layer, 0, 0)
        },
        // 効果を掛けた描き場所に、フレームの外で値を変えずに書き戻しても、次のフレームの
        // 効果は 1 回ぶん (Sketch+Effects.swift「効果はどのフレームにも 1 回ぶんだけ
        // かかる」)。書き戻すのは右下の 1 画素で、比べるのはそこから離れた所
        TangleCase(
            .effectsOffFrameSet, "描き場所の効果 × フレームの外の set", frames: 2,
            prepare: { k in k.layer = try! k.createGraphics(Tangles.side, Tangles.side) }
        ) { k in
            k.layer.beginDraw()
            if k.frame == 1 {
                k.layer.background(0)
                k.layer.noStroke()
                k.layer.fill(255)
                k.layer.rect(0, 0, 80, 160)
            }
            k.layer.effects([.invert()])
            k.layer.endDraw()
            if k.frame == 1 && k.suspect { k.layer.set(155, 155, k.layer.get(155, 155)) }
            k.background(0)
            k.image(k.layer, 0, 0)
        },

        // MARK: フレームの途中の描き切り・周囲の背景

        // フレームの途中で `get` を読んでも、影は同じ。読むと描き切りが挟まり、影の
        // 焼き付けがその回に溜めた立体しか見ない (Sketch+Shadow.swift「焼き付けは
        // フレームの終わりに 1 度だけ」・Sketch+Pixels.swift「呼んでも絵が 1 画素も
        // 変わらない」)
        TangleCase(.midFrameShadow, "フレームの途中の get × 影") { k in
            k.background(0)
            k.camera(80, -60, 200, 80, 80, 0, 0, 1, 0)
            k.lights()
            k.shadows(true)
            k.noStroke()
            k.fill(230)
            k.push()
            k.translate(80, 60, 0)
            k.sphere(25)
            k.pop()
            if k.suspect { _ = k.get(0, 0) }
            k.castShadow(false)
            k.push()
            k.translate(80, 120, 0)
            k.box(160, 6, 160)
            k.pop()
        },
        // 立体を置いた後の `background(.sky)` は、`loadPixels()` を挟んでも立体を消す
        // (`loadPixels` の約束は「呼んでも絵が 1 画素も変わらない」)
        TangleCase(.loadPixelsSky, "立体 → loadPixels → background(.sky)") { k in
            k.lights()
            k.fill(255)
            k.push()
            k.translate(80, 80, 0)
            k.box(60)
            k.pop()
            if k.suspect { k.loadPixels() }
            k.background(.sky)
        },
        // `background(.sky)` は下地を置き換える。色の `background` は混ぜ方を見ずに面を
        // 消すのに、周囲の背景は混ぜ方をそのまま使うので、`.add` のまま呼ぶと前の
        // フレームに足される
        TangleCase(.addSky, "blendMode(.add) × background(.sky)", frames: 2) { k in
            k.blendMode(k.suspect ? .add : .blend)
            k.background(.sky)
            k.blendMode(.blend)
        },
        // 陰性対照: `texture()` を貼ったままでも、周囲の背景は同じ
        TangleCase(.textureSky, "texture × background(.sky) (陰性対照)", prepare: Tangles.prepareCloud) { k in
            if k.suspect { k.texture(k.layer) }
            k.background(.sky)
            k.noTexture()
        },
    ]

    // MARK: - 部品

    static let red = color(255, 0, 0)
    static let white = color(255, 255, 255)

    /// 青い塗りと赤い輪郭 (太さ 12) の矩形と円。`fill` / `stroke` で片方だけにできる。
    @MainActor static func fillAndStroke(_ k: Knot, fill: Bool, stroke: Bool) {
        if fill { k.fill(0, 0, 160) } else { k.noFill() }
        if stroke { k.stroke(160, 0, 0) } else { k.noStroke() }
        k.strokeWeight(12)
        k.rect(24, 24, 56, 56)
        k.circle(112, 112, 56)
    }

    /// 値 `k` を赤に塗る断片。
    static let redByValue = """
        float4 paint(Fragment in, Values values) { return float4(values.k, 0, 0, 1); }
        """

    /// 面 `pic` をそのまま読む断片。
    static let sampleLayer = """
        float4 paint(Fragment in, Values values, Surfaces surfaces) { return mokume_sample(surfaces.pic, in.uv); }
        """

    /// 粒の群 2 つ・赤く塗った 8 × 8 の描き場所・緑の断片。
    @MainActor static func prepareCloud(_ k: Knot) {
        k.cloud = try! k.makeParticles(count: 512)
        k.cloud2 = try! k.makeParticles(count: 512)
        k.layer = try! k.createGraphics(8, 8)
        k.layer.beginDraw()
        k.layer.background(255, 0, 0)
        k.layer.endDraw()
        k.paint = try! k.makeShader("float4 paint(Fragment in, Values values) { return float4(0, 1, 0, 1); }")
    }

    /// 動かない白い粒を 1 か所に 100 個出す (寿命 5 秒・大きさ 20)。
    @MainActor static func emitCloud(_ k: Knot, _ cloud: Particles, x: Float) {
        k.emit(cloud, from: .point(x, 80), rate: 3000, speed: 0...0, life: 5...5, size: 20...20, color: white)
    }
}
