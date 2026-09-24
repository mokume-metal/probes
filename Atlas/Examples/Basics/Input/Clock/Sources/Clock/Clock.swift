import Foundation
import mokume
import Support

/// Processing の [Clock](https://processing.org/examples/clock/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ当たっている。** `second()` / `minute()` /
/// `hour()` を読む口は面に無いが、**壁時計そのものは Foundation が持っている**ので、
/// 面の外に書けば届く (`Support/Processing.swift`)。無いのは値ではなく読む口である。
/// `beginShape(POINTS)` は `VertexKind.points` へ名前が変わるだけ。
///
/// 時計を読むので、原典と mokume で撮った瞬間が違う。**画素では比べられない。**
final class Clock: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Clock")

    private var cx: Float = 0
    private var cy: Float = 0
    private var secondsRadius: Float = 0
    private var minutesRadius: Float = 0
    private var hoursRadius: Float = 0
    private var clockDiameter: Float = 0

    func setup() {
        stroke(255)

        let radius = min(width, height) / 2
        secondsRadius = radius * 0.72
        minutesRadius = radius * 0.60
        hoursRadius = radius * 0.50
        clockDiameter = radius * 1.8

        cx = width / 2
        cy = height / 2
    }

    func draw() {
        background(0)

        // 文字盤
        fill(80)
        noStroke()
        ellipse(cx, cy, clockDiameter, clockDiameter)

        // sin / cos は 3 時から始まるので、HALF_PI を引いて真上から始める
        let s = map(second(), 0, 60, 0, .pi * 2) - .pi / 2
        let m = map(minute() + norm(second(), 0, 60), 0, 60, 0, .pi * 2) - .pi / 2
        let h = map(hour() + norm(minute(), 0, 60), 0, 24, 0, .pi * 4) - .pi / 2

        // 針
        stroke(255)
        strokeWeight(1)
        line(cx, cy, cx + cos(s) * secondsRadius, cy + sin(s) * secondsRadius)
        strokeWeight(2)
        line(cx, cy, cx + cos(m) * minutesRadius, cy + sin(m) * minutesRadius)
        strokeWeight(4)
        line(cx, cy, cx + cos(h) * hoursRadius, cy + sin(h) * hoursRadius)

        // 分の目盛り
        strokeWeight(2)
        beginShape(.points)
        for a in stride(from: 0, to: 360, by: 6) {
            let angle = radians(Float(a))
            vertex(cx + cos(angle) * secondsRadius, cy + sin(angle) * secondsRadius)
        }
        endShape()
    }
}
