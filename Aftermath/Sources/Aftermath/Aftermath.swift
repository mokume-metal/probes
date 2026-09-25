import mokume

/// mokume で**失敗を起こした後のフレーム**が汚れないかを突く物差し。
///
/// **作品ではない。** 資源の生成が投げる・フレームの途中で放り出す・数でない値を渡す、と
/// いった失敗を途中のフレームで起こし、その後のフレームを、失敗を起こさなかった参照と
/// 比べる。数で押さえるのは `Tests/AftermathTests` の側で、窓はそれを目で確かめるために
/// ある (README「何をしているか」)。
///
/// **経路ごとに自前の `SketchRuntime` を持ち、その絵を本体へ貼る。** 片方の経路で起こした
/// 失敗が、面を分け合う隣の経路へ漏れて疑いに混ざらないようにするためである。内側の
/// 時計はテストと同じフレーム番号なので、窓の動きはテストが読む絵と同じ列になる。
@main
final class Aftermath: Sketch {
    /// 窓では 1 経路を 2 倍に広げて見せる。
    static let zoom: Float = 2
    static let gap: Float = 12
    static let margin: Float = 16
    static let header: Float = 56
    static let side = Float(Mishaps.side) * zoom

    var settings = SketchSettings(
        width: Int(margin * 2 + side * 2 + gap),
        height: Int(header + side + margin),
        frameRate: Mishaps.frameRate,
        title: "aftermath — mokume v0.11.2")

    /// いま見せている候補。
    private var index = 0
    /// その候補の 2 経路ぶんの舞台。
    private var rigs: [Rig] = []

    func setup() { show(0) }

    /// **1 度に 1 候補だけ回す。** 舞台は 1 枚ごとに絵を読み戻して貼るので、候補を全部
    /// 並べると 1 枚に 0.5 秒を越える。
    func show(_ next: Int) {
        index = (next + Mishaps.all.count) % Mishaps.all.count
        rigs = Route.allCases.map { Rig(Mishaps.all[index], $0) }
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1) }
        if keyCode == .arrowLeft { show(index - 1) }
    }

    func draw() {
        background(12)
        let mishap = Mishaps.all[index]
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Mishaps.all.count)  \(mishap.key.rawValue) — \(mishap.title)", Self.margin, 12)
        textSize(12)
        fill(150)
        text("← → で候補を切り替える。左が疑う書き方 (suspect)、右が参照 (reference)", Self.margin, 34)
        for (column, rig) in rigs.enumerated() {
            guard let picture = rig.step(in: self) else { continue }
            image(picture, Self.margin + Float(column) * (Self.side + Self.gap), Self.header, Self.side, Self.side)
        }
    }
}

/// 候補 1 件の 1 経路を回す舞台。1 巡を回し終えたら組み直して頭から回す。
final class Rig {
    let mishap: MishapCase
    let route: Route
    private var runtime: SketchRuntime?
    private var picture: Image?

    init(_ mishap: MishapCase, _ route: Route) {
        self.mishap = mishap
        self.route = route
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        do {
            if runtime == nil || runtime!.frameCount >= mishap.frames {
                runtime = try SketchRuntime(sketch: mishap.make(route), gpu: Rig.gpu)
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
