import mokume

/// Processing / p5.js でよく使う口に、mokume `v0.11.1` がどこまで届くかを測る物差し。
///
/// **作品ではない。** 手本の口 1 つを 1 枚のタイルにし、実際に mokume で書いて並べる。
/// タイルの下に手本の綴りと判定 (`Verdict`) を刷る。口の一覧は `Entries` の 1 か所だけにあり、
/// 窓もテストも同じ定義を描く。
///
/// **タイルは面を分けて描く。** 多くのタイルが `background()` から始まり、立体は視点が面の
/// 中心を向く。本体の面に直に描くと互いを塗り潰すので、タイルごとに `createGraphics` の面を
/// 持ち、描いてから `image()` で貼る (Probe と同じ形)。
@main
final class Reach: Sketch {
    /// タイルを描く面の一辺。
    static let side = 96
    /// 窓に貼るときの一辺。**縮めて貼る** — 110 枚を等倍で並べると、ノートの画面に収まらない。
    static let shown: Float = 80
    static let columns = 16
    static let gap: Float = 10
    static let margin: Float = 16
    static let caption: Float = 28

    /// `unreached` が本体を呼ばないための値。**定数にしない** — 定数だと本体が
    /// 「決して実行されない」と警告される。
    nonisolated(unsafe) static var neverTrue = false

    /// テストが 1 枚だけ描くときの口。置くと面がタイル 1 枚の大きさになり、本体の面へ直に描く。
    static var solo: Entry?

    static var cellWidth: Float { shown + gap }
    static var cellHeight: Float { shown + caption + gap }
    static var rows: Int { (Entries.all.count + columns - 1) / columns }

    var settings: SketchSettings = Reach.solo == nil
        ? SketchSettings(
            width: Int(margin * 2 + Float(columns) * cellWidth - gap),
            height: Int(margin * 2 + Float(rows) * cellHeight - gap),
            title: "reach — mokume v0.11.1")
        : SketchSettings(width: side, height: side, title: "reach")

    /// タイルごとの面。1 度だけ作る。
    private var surfaces: [Canvas] = []
    /// 画像の口に渡す絵。**資材を持たない** — リポジトリに画像を置かないので、画素から作る。
    private(set) var sample: Image!
    /// 押されているキーの数。`keyIsPressed` を面の外に書くための控え (`Support.swift`)。
    var keysDown = 0

    init() {}

    func setup() {
        sample = try! createImage(32, 32)
        for y in 0..<32 {
            for x in 0..<32 {
                let checker = (x / 8 + y / 8) % 2 == 0
                sample.set(x, y, checker ? color(240, 190, 60) : color(40, 110, 200))
            }
        }
        if Self.solo == nil {
            surfaces = Entries.all.map { _ in try! createGraphics(Self.side, Self.side) }
        }
    }

    func draw() {
        if let entry = Self.solo {
            Self.paint(entry, on: canvas, by: self)
            return
        }
        background(12)
        for (index, entry) in Entries.all.enumerated() {
            let x = Self.margin + Float(index % Self.columns) * Self.cellWidth
            let y = Self.margin + Float(index / Self.columns) * Self.cellHeight
            let surface = surfaces[index]
            surface.beginDraw()
            Self.paint(entry, on: surface, by: self)
            surface.endDraw()
            image(surface, x, y, Self.shown, Self.shown)
            label(entry, x, y + Self.shown + 2)
        }
    }

    func keyPressed() { keysDown += 1 }
    func keyReleased() { keysDown = max(keysDown - 1, 0) }

    /// タイル 1 枚の下地と既定の様式。**どのタイルも同じ状態から描き始める。**
    static func paint(_ entry: Entry, on c: Canvas, by sketch: Reach) {
        c.push()
        c.background(28)
        c.fill(235, 120, 60)
        c.stroke(240)
        c.strokeWeight(2)
        switch entry.tile {
        case .picture(let body):
            body(c, sketch)
        case .value(let body):
            c.noStroke()
            c.fill(220)
            c.textSize(12)
            c.textAlign(.center, .center)
            c.text(body(sketch), Float(side) / 2, Float(side) / 2)
        case .absent:
            c.noFill()
            c.stroke(200, 60, 60)
            c.line(12, 12, Float(side) - 12, Float(side) - 12)
            c.line(Float(side) - 12, 12, 12, Float(side) - 12)
        }
        c.pop()
    }

    private func label(_ entry: Entry, _ x: Float, _ y: Float) {
        noStroke()
        textSize(10)
        textAlign(.left, .top)
        fill(210)
        text(fitted(entry.reference, Self.cellWidth - 2), x, y)
        switch entry.verdict {
        case .same, .renamed, .host, .drop: fill(110, 200, 120)
        case .write: fill(230, 200, 90)
        case .bend: fill(240, 140, 60)
        case .none: fill(230, 80, 80)
        }
        text(entry.verdict.rawValue, x, y + 13)
    }

    /// 幅に収まるところまで切り詰める。隣のタイルの見出しに重ねない。
    private func fitted(_ string: String, _ width: Float) -> String {
        if textWidth(string) <= width { return string }
        var cut = string
        while !cut.isEmpty && textWidth(cut + "…") > width { cut.removeLast() }
        return cut + "…"
    }
}
