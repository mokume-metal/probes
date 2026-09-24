import mokume

/// Processing の [Distance 1D](https://processing.org/examples/distance1d/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// マウスで動く例なので、窓を持たない書き出しでは `mouseX` が 0 のまま撮れる。
final class Distance1D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Distance 1D")

    private var xpos1: Float = 0
    private var xpos2: Float = 0
    private var xpos3: Float = 0
    private var xpos4: Float = 0
    private let thin: Float = 8
    private let thick: Float = 36

    func setup() {
        noStroke()
        xpos1 = width / 2
        xpos2 = width / 2
        xpos3 = width / 2
        xpos4 = width / 2
    }

    func draw() {
        background(0)

        let mx = mouseX * 0.4 - width / 5.0

        fill(102)
        rect(xpos2, 0, thick, height / 2)
        fill(204)
        rect(xpos1, 0, thin, height / 2)
        fill(102)
        rect(xpos4, height / 2, thick, height / 2)
        fill(204)
        rect(xpos3, height / 2, thin, height / 2)

        xpos1 += mx / 16
        xpos2 += mx / 64
        xpos3 -= mx / 16
        xpos4 -= mx / 64

        if xpos1 < -thin { xpos1 = width }
        if xpos1 > width { xpos1 = -thin }
        if xpos2 < -thick { xpos2 = width }
        if xpos2 > width { xpos2 = -thick }
        if xpos3 < -thin { xpos3 = width }
        if xpos3 > width { xpos3 = -thin }
        if xpos4 < -thick { xpos4 = width }
        if xpos4 > width { xpos4 = -thick }
    }
}
