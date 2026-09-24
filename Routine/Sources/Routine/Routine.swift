import mokume

/// mokume を、作品がふつう書く「単純な機能の組み合わせ」で動かして突く物差し。
///
/// **作品ではない。** Probe・Drift が mokume のソースを読んで当たりを付けたのに対し、
/// こちらは**中身を読まずに**、クリエイティブコーディングの作品が当たり前に踏む書き方
/// (setup で決めた描き方・残像・画素の読み書き・層・脈打つ大きさ・お絵描き…) を
/// フレームを重ねて回す。数で押さえるのは `Tests/RoutineTests` の側で、窓はそれを目で
/// 確かめるためにある (README「確かめ方」)。
///
/// **経路ごとに自前の `SketchRuntime` を持ち、その絵を本体へ貼る。** 候補の多くが
/// 面全体や `setup()` の描き方に触れるので、1 枚の面を分け合うと隣が疑いに混ざる。
/// 内側の時計はテストと同じフレーム番号なので、窓の動きはテストが読む絵と同じ列になる。
/// 入力を使う候補も、窓の操作ではなくテストと同じ出来事の台本で動く。
@main
final class Routine: Sketch {
    /// 窓では 1 経路を 2 倍に広げて見せる。
    static let zoom: Float = 2
    static let gap: Float = 12
    static let margin: Float = 16
    static let header: Float = 56
    static let side = Float(Habits.side) * zoom

    var settings = SketchSettings(
        width: Int(margin * 2 + side * 2 + gap),
        height: Int(header + side + margin),
        frameRate: Habits.frameRate,
        title: "routine — mokume v0.11.1")

    /// いま見せている候補。
    private var index = 0
    /// その候補の 2 経路ぶんの舞台。
    private var rigs: [Rig] = []

    func setup() { show(0) }

    /// **1 度に 1 候補だけ回す。** 舞台は 1 枚ごとに絵を読み戻して貼るので、候補を全部
    /// 並べると 1 枚に 0.5 秒を越える。
    func show(_ next: Int) {
        index = (next + Habits.all.count) % Habits.all.count
        rigs = Route.allCases.map { Rig(Habits.all[index], $0) }
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1) }
        if keyCode == .arrowLeft { show(index - 1) }
    }

    func draw() {
        background(12)
        let habit = Habits.all[index]
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Habits.all.count)  \(habit.key.rawValue) — \(habit.title)", Self.margin, 12)
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
    let habit: HabitCase
    let route: Route
    private var runtime: SketchRuntime?
    private var picture: Image?

    init(_ habit: HabitCase, _ route: Route) {
        self.habit = habit
        self.route = route
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        do {
            if runtime == nil || runtime!.frameCount >= habit.frames {
                runtime = try SketchRuntime(sketch: habit.make(route), gpu: Rig.gpu)
            }
            let runtime = runtime!
            habit.input?(runtime.frameCount + 1, runtime)
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
