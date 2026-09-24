import mokume

/// Processing の [Penrose Tile](https://processing.org/examples/penrosetile/) を 1 行ずつ移したもの。
/// 原典は Geraldine Sarmiento 作。3 つのタブに分かれている。
///
/// **台帳は `write-only` と言った。半分だけ。** `radians()` が無いのはそのとおりだが、
/// `stroke(255, 60)` の**明るさ + 透かしの 2 つ組**も書けない。
final class PenroseTile: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Penrose Tile")

    final class PenroseLSystem {
        var axiom = "[X]++[X]++[X]++[X]++[X]"
        let ruleW = "YF++ZF4-XF[-YF4-WF]++"
        let ruleX = "+YF--ZF[3-WF--XF]+"
        let ruleY = "-WF++XF[+++YF++ZF]-"
        let ruleZ = "--YF++++WF[+ZF++++XF]--XF"
        var production = ""
        var startLength: Float = 460.0
        var drawLength: Float = 460.0
        var theta = radians(36)
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
                switch step {
                case "W": newProduction += ruleW
                case "X": newProduction += ruleX
                case "Y": newProduction += ruleY
                case "Z": newProduction += ruleZ
                case "F": break
                default: newProduction += String(step)
                }
            }
            drawLength = drawLength * 0.5
            generations += 1
            return newProduction
        }

        func render(on sketch: any Sketch) {
            sketch.translate(sketch.width / 2, sketch.height / 2)
            var pushes = 0
            var repeats = 1
            steps += 12
            if steps > production.count { steps = production.count }
            for step in production.prefix(steps) {
                switch step {
                case "F":
                    sketch.stroke(255, 60)
                    for _ in 0..<repeats {
                        sketch.line(0, 0, 0, -drawLength)
                        sketch.noFill()
                        sketch.translate(0, -drawLength)
                    }
                    repeats = 1
                case "+":
                    for _ in 0..<repeats { sketch.rotate(theta) }
                    repeats = 1
                case "-":
                    for _ in 0..<repeats { sketch.rotate(-theta) }
                    repeats = 1
                case "[":
                    pushes += 1
                    sketch.pushMatrix()
                case "]":
                    sketch.popMatrix()
                    pushes -= 1
                default:
                    if let digit = step.wholeNumberValue, step.isNumber { repeats = digit }
                }
            }
            // 開いたままの push を閉じる
            while pushes > 0 {
                sketch.popMatrix()
                pushes -= 1
            }
        }
    }

    private let ds = PenroseLSystem()

    func setup() {
        ds.simulate(4)
    }

    func draw() {
        background(0)
        ds.render(on: self)
    }
}
