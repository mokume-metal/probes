import mokume

/// Processing の [Bounce](https://processing.org/examples/bounce/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — `frameRate(30)` は走り出す前にしか
/// 決められないので `SketchSettings` へ移る。`ellipseMode(RADIUS)` は名前が変わるだけ。
final class Bounce: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Bounce")

    private let rad: Float = 60        // 形の幅
    private var xpos: Float = 0
    private var ypos: Float = 0
    private let xspeed: Float = 2.8
    private let yspeed: Float = 2.2
    private var xdirection: Float = 1
    private var ydirection: Float = 1

    func setup() {
        noStroke()
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
        ellipseMode(.radius)
        xpos = width / 2
        ypos = height / 2
    }

    func draw() {
        background(102)

        xpos = xpos + (xspeed * xdirection)
        ypos = ypos + (yspeed * ydirection)

        // 面の縁を越えたら向きを反す
        if xpos > width - rad || xpos < rad { xdirection *= -1 }
        if ypos > height - rad || ypos < rad { ydirection *= -1 }

        ellipse(xpos, ypos, rad, rad)
    }
}
