import mokume

/// mokume `v0.11.0` の「フレームをまたぐ」継ぎ目を突く物差し。
///
/// **作品ではない。** Probe が 1 枚の絵を 2 つの経路で比べるのに対し、こちらは**動き**を
/// 比べる — 時刻・端数の繰り越し・前のフレームの絵・渡した並び・積分の刻みは、1 枚目では
/// 食い違わず、フレームを重ねてはじめて左右がずれていく。数で押さえるのは
/// `Tests/DriftTests` の側で、窓はそれを目で確かめるためにある (README「確かめ方」)。
///
/// **タイルは本体の面へ直に描く。** 候補の 1 つが「描き場所 (`createGraphics`) の面では
/// 時刻が進まない」なので、Probe のように経路ごとに描き場所を持つと、窓そのものが
/// 疑っている口を通ってしまう。描き場所が要る候補 (`effectsCarry`) だけが自前で持つ。
@main
final class Drift: Sketch {
    static let columns = 3
    static let gap: Float = 8
    static let margin: Float = 16
    static let caption: Float = 22

    static var tileWidth: Float { Float(Motions.side) * 2 + gap }
    static var tileHeight: Float { caption + Float(Motions.side) }
    static var rows: Int { (Motions.all.count + columns - 1) / columns }

    var settings = SketchSettings(
        width: Int(margin * 2 + Float(columns) * tileWidth + Float(columns - 1) * margin),
        height: Int(margin * 2 + Float(rows) * tileHeight + Float(rows - 1) * margin),
        frameRate: Motions.frameRate,
        title: "drift — mokume v0.11.0")

    /// 候補 × 経路ぶんの動き。
    private let motions: [[any Motion]] = Motions.all.map { probe in
        Route.allCases.map { probe.make($0) }
    }

    func setup() {
        for pair in motions { for motion in pair { motion.setup(self) } }
    }

    func draw() {
        background(12)
        for (index, probe) in Motions.all.enumerated() {
            let x = Self.margin + Float(index % Self.columns) * (Self.tileWidth + Self.margin)
            let y = Self.margin + Float(index / Self.columns) * (Self.tileHeight + Self.margin)

            fill(220)
            noStroke()
            textSize(13)
            textAlign(.left, .top)
            text("\(probe.key.rawValue) — \(probe.title)", x, y)

            for (column, motion) in motions[index].enumerated() {
                let origin = SIMD2(x + Float(column) * (Float(Motions.side) + Self.gap), y + Self.caption)
                motion.draw(self, at: origin)
            }
        }
    }
}
