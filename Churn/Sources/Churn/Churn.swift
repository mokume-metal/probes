import mokume

/// mokume で**物体を足し・消し・動かし続けたとき**に、絵が履歴・数・同一性に引きずられないかを突く物差し。
///
/// **作品ではない。** 候補 1 件を、1 つのことだけが違う 2 つの経路で描く (``Relation``)。
/// - 前置きの履歴
/// - runtime の積み重ね
/// - 比べる領域の外の数
/// - まとめて置くか 1 つずつ置くか
///
/// 数で押さえるのは `Tests/ChurnTests` の側で、窓はそれを目で確かめるためにある (README「何をしているか」)。
///
/// **経路ごとに自前の `SketchRuntime` を持ち、その絵を本体へ貼る** (Weave と同じ形)。内側の時計は
/// テストと同じフレーム番号なので、窓の動きはテストが読む絵と同じ列になる。
@main
final class Churn: Sketch {
    /// 窓では 1 経路を 2 倍に広げて見せる。
    static let zoom: Float = 2
    static let gap: Float = 12
    static let margin: Float = 16
    static let header: Float = 56
    static let side = Float(Scenes.side) * zoom

    var settings = SketchSettings(
        width: Int(margin * 2 + side * 2 + gap),
        height: Int(header + side + margin),
        frameRate: Scenes.frameRate,
        title: "churn — mokume v0.22.0")

    /// いま見せている候補。
    private var index = 0
    /// その候補の 2 経路ぶんの舞台。
    private var rigs: [Rig] = []

    func setup() { show(0) }

    /// **1 度に 1 候補だけ回す。** 舞台は 1 枚ごとに絵を読み戻して貼るので、候補を全部
    /// 並べると重い。
    func show(_ next: Int) {
        index = (next + Scenes.all.count) % Scenes.all.count
        rigs = Route.allCases.map { Rig(Scenes.all[index], $0) }
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1) }
        if keyCode == .arrowLeft { show(index - 1) }
    }

    func draw() {
        background(12)
        let churn = Scenes.all[index]
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Scenes.all.count)  \(churn.key.rawValue) — \(churn.title)", Self.margin, 12)
        textSize(12)
        fill(150)
        text("← → で候補を切り替える。左が suspect、右が reference", Self.margin, 34)
        for (column, rig) in rigs.enumerated() {
            guard let picture = rig.step(in: self) else { continue }
            image(picture, Self.margin + Float(column) * (Self.side + Self.gap), Self.header, Self.side, Self.side)
        }
    }
}

/// 候補 1 件の 1 経路を回す舞台。1 巡を回し終えたら組み直して頭から回す。
///
/// ``Relation/fresh`` の参照だけは、**1 枚ごとに runtime を組み直して**、その枚の場面を 1 枚目として描く。
final class Rig {
    let churn: ChurnCase
    let route: Route
    private var runtime: SketchRuntime?
    private var picture: Image?
    /// 1 巡の中の何枚目を描いたか。
    private var shown = 0

    init(_ churn: ChurnCase, _ route: Route) {
        self.churn = churn
        self.route = route
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        do {
            if shown >= churn.frames { (runtime, shown) = (nil, 0) }
            if churn.relation == .fresh && route == .reference {
                runtime = try SketchRuntime(sketch: churn.make(route, offset: shown), gpu: Rig.gpu)
            } else if runtime == nil {
                runtime = try SketchRuntime(sketch: churn.make(route), gpu: Rig.gpu)
            }
            let runtime = runtime!
            try runtime.advance()
            shown += 1
            let encoded = try runtime.target.encodeForDisplay()
            if picture?.width != encoded.width || picture?.height != encoded.height {
                picture = try host.createImage(encoded.width, encoded.height)
            }
            picture!.write(encoded)
            return picture
        } catch {
            return nil
        }
    }

    static let gpu = try! RenderDevice()
}
