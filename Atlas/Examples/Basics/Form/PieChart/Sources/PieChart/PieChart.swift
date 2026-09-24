import mokume

/// Processing の [Pie Chart](https://processing.org/examples/piechart/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止めても絵は変わらない。
/// `map()` と `radians()` も無いので面の外に書く ([#883](https://github.com/mokume-metal/mokume/issues/883))。
final class PieChart: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Pie Chart")

    private let angles: [Float] = [30, 10, 45, 35, 60, 38, 75, 67]

    func setup() {
        noStroke()
        noLoop()
    }

    func draw() {
        background(100)
        pieChart(300, angles)
    }

    private func pieChart(_ diameter: Float, _ data: [Float]) {
        var lastAngle: Float = 0
        for i in data.indices {
            let shade = map(Float(i), 0, Float(data.count), 0, 255)
            fill(shade)
            arc(width / 2, height / 2, diameter, diameter, lastAngle, lastAngle + radians(data[i]))
            lastAngle += radians(data[i])
        }
    }
}
