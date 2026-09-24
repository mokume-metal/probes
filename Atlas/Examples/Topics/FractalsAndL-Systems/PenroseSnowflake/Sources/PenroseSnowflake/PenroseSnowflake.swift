import mokume

/// Processing の [Penrose Snowflake](https://processing.org/examples/penrosesnowflake/) を 1 行ずつ移したもの。
/// 原典は Geraldine Sarmiento 作。3 つのタブに分かれている。
///
/// **台帳は `write-only` と言った。当たっている** — `radians()` が無いので面の外に書く。
final class PenroseSnowflake: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Penrose Snowflake")

    final class PenroseSnowflakeLSystem {
        var axiom = "F3-F3-F3-F3-F"
        var ruleF = "F3-F3-F45-F++F3-F"
        var production = ""
        var startLength: Float = 450.0
        var drawLength: Float = 450.0
        var theta = radians(18)
        var generations = 0
        var steps = 0

        init() { reset() }

        func reset() {
            production = axiom
            drawLength = startLength
            generations = 0
        }

        func simulate(_ gen: Int) {
            while generations < gen { production = iterate(production) }
        }

        private func iterate(_ prod: String) -> String {
            var newProduction = ""
            for step in prod {
                newProduction += step == "F" ? ruleF : String(step)
            }
            drawLength = drawLength * 0.4
            generations += 1
            return newProduction
        }

        func render(on sketch: any Sketch) {
            sketch.translate(sketch.width, sketch.height)
            var repeats = 1
            steps += 3
            if steps > production.count { steps = production.count }
            for step in production.prefix(steps) {
                switch step {
                case "F":
                    for _ in 0..<repeats {
                        sketch.line(0, 0, 0, -drawLength)
                        sketch.translate(0, -drawLength)
                    }
                    repeats = 1
                case "+":
                    for _ in 0..<repeats { sketch.rotate(theta) }
                    repeats = 1
                case "-":
                    for _ in 0..<repeats { sketch.rotate(-theta) }
                    repeats = 1
                case "[": sketch.pushMatrix()
                case "]": sketch.popMatrix()
                default:
                    if let digit = step.wholeNumberValue, step.isNumber { repeats += digit }
                }
            }
        }
    }

    private let ps = PenroseSnowflakeLSystem()

    func setup() {
        stroke(255)
        noFill()
        ps.simulate(4)
    }

    func draw() {
        background(0)
        ps.render(on: self)
    }
}
