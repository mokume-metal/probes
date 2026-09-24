import mokume

/// mokume `v0.11.0` の継ぎ目を突く物差し。
///
/// **作品ではない。** 候補 1 件を 1 枚のタイルにして格子に並べ、タイルの左に疑っている口の
/// 絵、右に同じ結果を素朴な口で作った絵を置く。左右が食い違っていれば、そこで mokume が
/// 約束を破っている。数で押さえるのは `Tests/ProbeTests` の側で、窓はそれを目で確かめる
/// ためにある (README「確かめ方」)。
///
/// **タイルは面を分けて描く。** 候補の多くは `background()` から始まり、立体は視点が面の
/// 中心を向く。本体の面に直に描くと互いを塗り潰すので、経路ごとに `createGraphics` の面を
/// 持ち、描いてから `image()` で貼る。
@main
final class Probe: Sketch {
    static let columns = 3
    static let gap: Float = 8
    static let margin: Float = 16
    static let caption: Float = 22

    static var tileWidth: Float { Float(Probes.side) * 2 + gap }
    static var tileHeight: Float { caption + Float(Probes.side) }
    static var rows: Int { (Probes.all.count + columns - 1) / columns }

    var settings = SketchSettings(
        width: Int(margin * 2 + Float(columns) * tileWidth + Float(columns - 1) * margin),
        height: Int(margin * 2 + Float(rows) * tileHeight + Float(rows - 1) * margin),
        title: "probe — mokume v0.11.0")

    /// 候補 × 経路ぶんの面。1 度だけ作る。
    private var surfaces: [[Canvas]] = []

    func setup() {
        surfaces = Probes.all.map { _ in
            Route.allCases.map { _ in try! createGraphics(Probes.side, Probes.side) }
        }
    }

    func draw() {
        background(12)
        for (index, probe) in Probes.all.enumerated() {
            let x = Self.margin + Float(index % Self.columns) * (Self.tileWidth + Self.margin)
            let y = Self.margin + Float(index / Self.columns) * (Self.tileHeight + Self.margin)

            fill(220)
            noStroke()
            textSize(13)
            textAlign(.left, .top)
            text("\(probe.key.rawValue) — \(probe.title)", x, y)

            for (column, route) in Route.allCases.enumerated() {
                let surface = surfaces[index][column]
                surface.beginDraw()
                probe.draw(surface, route)
                surface.endDraw()
                image(surface, x + Float(column) * (Float(Probes.side) + Self.gap), y + Self.caption)
            }
        }
    }
}
