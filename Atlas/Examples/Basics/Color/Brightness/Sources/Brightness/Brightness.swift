import mokume

/// Processing の [Brightness](https://processing.org/examples/brightness/) を 1 行ずつ移したもの。
/// 原典は Rusty Robison 作。
///
/// **台帳は `bend` と言った。`v0.6.0` でも当たっているが、背負う量は減った。**
/// 色相・彩度・明度から色を作る口は入ったので変換は要らなくなり、残るのは
/// `colorMode(HSB, width, 100, height)` の**目盛りの畳み込み**だけになった
/// (mokume の目盛りは 360/100/100 に固定)。
///
/// マウスで塗る例なので、窓を持たない書き出しでは左端の 1 本だけが出る。
final class Brightness: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Brightness")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, width, 100, height)` を呼ぶ。**目盛りを
        // 張り替える口は無い**ので、下の `color(hue:…)` へ渡す前に畳む
        noStroke()
        background(0)
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(color(
                hue: barX / width * 360,
                saturation: 100,
                brightness: constrain(mouseY / height * 100, 0, 100)))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
