import mokume

/// Processing の [Relativity](https://processing.org/examples/relativity/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
final class Relativity: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Relativity")

    private var a = LinearRGBA.transparent
    private var b = LinearRGBA.transparent
    private var c = LinearRGBA.transparent
    private var d = LinearRGBA.transparent
    private var e = LinearRGBA.transparent

    func setup() {
        noStroke()
        a = color(165, 167, 20)
        b = color(77, 86, 59)
        c = color(42, 106, 105)
        d = color(165, 89, 20)
        e = color(146, 150, 127)
        noLoop()
    }

    func draw() {
        drawBand(a, b, c, d, e, 0, Int(width) / 128)
        drawBand(c, a, d, b, e, Int(height) / 2, Int(width) / 128)
    }

    private func drawBand(_ v: LinearRGBA, _ w: LinearRGBA, _ x: LinearRGBA,
                          _ y: LinearRGBA, _ z: LinearRGBA, _ ypos: Int, _ barWidth: Int) {
        let num = 5
        let colorOrder = [v, w, x, y, z]
        for i in stride(from: 0, to: Int(width), by: barWidth * num) {
            for j in 0..<num {
                fill(colorOrder[j])
                rect(Float(i + j * barWidth), Float(ypos), Float(barWidth), height / 2)
            }
        }
    }
}
