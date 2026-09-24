import mokume

/// Processing の [Map](https://processing.org/examples/map/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている。** 原典が主題にしている `map()` が
/// mokume に無いので、割って掛ける式を書く。→ [mokume#883](https://github.com/mokume-metal/mokume/issues/883)
///
/// 台帳によれば `map` を要求する例は **33 本** (測る対象に入るものだけ) ある。
/// Ring 1 本の都合ではない。
final class Map: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Map")

    /// 原典の `background(0)`
    private static let ground = LinearRGBA.display(red: 0, green: 0, blue: 0)

    func setup() {
        noStroke()
    }

    func draw() {
        background(Self.ground)
        // 原典の `map(mouseX, 0, width, 0, 175)`。**写像が無い**ので割って掛ける
        let c = mouseX / width * 175
        // 原典の `map(mouseX, 0, width, 40, 300)`
        let d = 40 + mouseX / width * (300 - 40)
        // 原典の `fill(255, c, 0)`
        fill(.display(red: 1, green: c / 255, blue: 0))
        ellipse(width / 2, height / 2, d, d)
    }
}
