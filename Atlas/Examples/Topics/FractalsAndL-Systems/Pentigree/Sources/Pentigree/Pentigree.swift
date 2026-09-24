import mokume

/// Processing の [Pentigree](https://processing.org/examples/pentigree/) を 1 行ずつ移したもの。
/// 原典は Geraldine Sarmiento 作。3 つのタブ (`Pentigree` / `LSystem` /
/// `PentigreeLSystem`) に分かれている。
///
/// **台帳は `write-only` と言った。当たっている** — `radians()` が無いので面の外に書く。
/// 描く口が面の上にあるので `render(on:)` が面を受け取る。**L システムそのものは
/// 文字列の書き換えなので、mokume の側の欠けに触れない** — 移植がいちばん素直な群である。
final class Pentigree: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Pentigree")

    /// 原典の `class LSystem` と `class PentigreeLSystem` をまとめたもの。
    final class PentigreeLSystem {
        var axiom = "F-F-F-F-F"
        var rule = "F-F++F+F-F-F"
        var production = ""
        var startLength: Float = 60.0
        var drawLength: Float = 60.0
        var theta = radians(72)
        var generations = 0
        var steps = 0

        init() { reset() }

        func reset() {
            production = axiom
            drawLength = startLength
            generations = 0
        }

        func simulate(_ gen: Int) {
            while generations < gen { production = iterate(production, rule) }
        }

        private func iterate(_ prod: String, _ rule: String) -> String {
            drawLength = drawLength * 0.6
            generations += 1
            return prod.replacingOccurrences(of: "F", with: rule)
        }

        func render(on sketch: any Sketch) {
            sketch.translate(sketch.width / 4, sketch.height / 2)
            steps += 3
            if steps > production.count { steps = production.count }
            for step in production.prefix(steps) {
                switch step {
                case "F":
                    sketch.noFill()
                    sketch.stroke(255)
                    sketch.line(0, 0, 0, -drawLength)
                    sketch.translate(0, -drawLength)
                case "+": sketch.rotate(theta)
                case "-": sketch.rotate(-theta)
                case "[": sketch.pushMatrix()
                case "]": sketch.popMatrix()
                default: break
                }
            }
        }
    }

    private let ps = PentigreeLSystem()

    func setup() {
        ps.simulate(3)
    }

    func draw() {
        background(0)
        ps.render(on: self)
    }
}
