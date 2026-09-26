import mokume

/// mokume の**機能を組み合わせたときだけ崩れる継ぎ目**を突く物差し。
///
/// **作品ではない。** 1 つずつなら正しく動く機能を 2 つ以上組み合わせて 1 回で描き
/// (`suspect`)、同じ機能を 1 つずつ使って同じ絵になるよう合成したもの (`reference`) と
/// 比べる。数で押さえるのは `Tests/WeaveTests` の側で、窓はそれを目で確かめるために
/// ある (README「何をしているか」)。
///
/// **経路ごとに自前の `SketchRuntime` を持ち、その絵を本体へ貼る** (Aftermath と同じ形)。
/// 組み合わせた側の状態が、面を分け合う隣の経路へ漏れて疑いに混ざらないようにするため
/// である。内側の時計はテストと同じフレーム番号なので、窓の動きはテストが読む絵と同じ列に
/// なる。
@main
final class Weave: Sketch {
    /// 窓では 1 経路を 2 倍に広げて見せる。
    static let zoom: Float = 2
    static let gap: Float = 12
    static let margin: Float = 16
    static let header: Float = 56
    static let side = Float(Tangles.side) * zoom

    var settings = SketchSettings(
        width: Int(margin * 2 + side * 2 + gap),
        height: Int(header + side + margin),
        frameRate: Tangles.frameRate,
        title: "weave — mokume v0.12.0")

    /// いま見せている候補。
    private var index = 0
    /// その候補の 2 経路ぶんの舞台。
    private var rigs: [Rig] = []

    func setup() { show(0) }

    /// **1 度に 1 候補だけ回す。** 舞台は 1 枚ごとに絵を読み戻して貼るので、候補を全部
    /// 並べると 1 枚に 0.5 秒を越える。
    func show(_ next: Int) {
        index = (next + Tangles.all.count) % Tangles.all.count
        rigs = Route.allCases.map { Rig(Tangles.all[index], $0) }
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1) }
        if keyCode == .arrowLeft { show(index - 1) }
    }

    func draw() {
        background(12)
        let tangle = Tangles.all[index]
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Tangles.all.count)  \(tangle.key.rawValue) — \(tangle.title)", Self.margin, 12)
        textSize(12)
        fill(150)
        text("← → で候補を切り替える。左が組み合わせ (suspect)、右が 1 つずつの合成 (reference)", Self.margin, 34)
        for (column, rig) in rigs.enumerated() {
            guard let picture = rig.step(in: self) else { continue }
            image(picture, Self.margin + Float(column) * (Self.side + Self.gap), Self.header, Self.side, Self.side)
        }
    }
}

/// 候補 1 件の 1 経路を回す舞台。1 巡を回し終えたら組み直して頭から回す。
final class Rig {
    let tangle: TangleCase
    let route: Route
    private var runtime: SketchRuntime?
    private var picture: Image?

    init(_ tangle: TangleCase, _ route: Route) {
        self.tangle = tangle
        self.route = route
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        do {
            if runtime == nil || runtime!.frameCount >= tangle.frames {
                runtime = try SketchRuntime(sketch: tangle.make(route), gpu: Rig.gpu)
            }
            let runtime = runtime!
            try runtime.advance()
            let shown = try runtime.target.encodeForDisplay()
            if picture?.width != shown.width || picture?.height != shown.height {
                picture = try host.createImage(shown.width, shown.height)
            }
            picture!.write(shown)
            return picture
        } catch {
            return nil
        }
    }

    static let gpu = try! RenderDevice()
}
