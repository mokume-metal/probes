import mokume

/// Processing の [Array Objects](https://processing.org/examples/arrayobjects/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。外れている。** 語彙はすべて当たるが、**自分で描けるクラスが
/// 書けない**。原典の `Module` は `PApplet` の内側のクラスなので `fill` も `ellipse` も
/// そのまま呼べる。mokume の描く口は `Sketch` の上にあるので、面を持ち回ることになる
/// (`display(on:)`)。原典 2 行が 1 行の引数を増やす。
///
/// 乱数を使うので、原典と mokume で数列が違う。**画素では比べられない。**
final class ArrayObjects: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Array Objects")

    /// 原典の `class Module`。**面を渡さないと描けない**ところだけが違う。
    final class Module {
        let xOffset: Float
        let yOffset: Float
        var x: Float
        var y: Float
        let unit: Float
        var xDirection: Float = 1
        var yDirection: Float = 1
        let speed: Float

        init(_ xOffset: Float, _ yOffset: Float, _ x: Float, _ y: Float, _ speed: Float, _ unit: Float) {
            self.xOffset = xOffset
            self.yOffset = yOffset
            self.x = x
            self.y = y
            self.speed = speed
            self.unit = unit
        }

        func update() {
            x = x + (speed * xDirection)
            if x >= unit || x <= 0 {
                xDirection *= -1
                x = x + (1 * xDirection)
                y = y + (1 * yDirection)
            }
            if y >= unit || y <= 0 {
                yDirection *= -1
                y = y + (1 * yDirection)
            }
        }

        func display(on sketch: any Sketch) {
            sketch.fill(255)
            sketch.ellipse(xOffset + x, yOffset + y, 6, 6)
        }
    }

    private let unit: Float = 40
    private var mods: [Module] = []

    func setup() {
        noStroke()
        let wideCount = Int(width / unit)
        let highCount = Int(height / unit)
        for y in 0..<highCount {
            for x in 0..<wideCount {
                mods.append(Module(Float(x) * unit, Float(y) * unit, unit / 2, unit / 2,
                                   random(0.05, 0.8), unit))
            }
        }
    }

    func draw() {
        background(0)
        for mod in mods {
            mod.update()
            mod.display(on: self)
        }
    }
}
