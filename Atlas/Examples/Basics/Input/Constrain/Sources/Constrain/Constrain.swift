import Foundation
import mokume
import Support

/// Processing の [Constrain](https://processing.org/examples/constrain/) を 1 行ずつ移したもの。
///
/// **台帳は `write-only` と言った。当たっている** — `constrain()` が無いので面の外に書く。
/// `ellipseMode(RADIUS)` / `rectMode(CORNERS)` は `ShapeMode` へ名前が変わるだけで届く。
final class Constrain: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Constrain")

    private var mx: Float = 0
    private var my: Float = 0
    private let easing: Float = 0.05
    private let radius: Float = 24
    private let edge: Float = 100
    private var inner: Float { edge + radius }

    func setup() {
        noStroke()
        ellipseMode(.radius)
        rectMode(.corners)
    }

    func draw() {
        background(51)

        if abs(mouseX - mx) > 0.1 { mx = mx + (mouseX - mx) * easing }
        if abs(mouseY - my) > 0.1 { my = my + (mouseY - my) * easing }

        mx = constrain(mx, inner, width - inner)
        my = constrain(my, inner, height - inner)
        fill(76)
        rect(edge, edge, width - edge, height - edge)
        fill(255)
        ellipse(mx, my, radius, radius)
    }
}
