import mokume

/// Processing の [Hue](https://processing.org/examples/hue/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。`v0.6.0` でも当たっているが、理由が変わった。** 色相環を
/// 面の外に書く必要はもう無い ([#778](https://github.com/mokume-metal/mokume/issues/778) が入った)。
/// 残るのは `colorMode(HSB, height, height, height)` の**目盛りの畳み込み**だけである
/// (mokume の目盛りは 360/100/100 に固定)。
final class Hue: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Hue")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, height, height, height)` を呼ぶ。**目盛りを
        // 張り替える口は無い**ので、下の `color(hue:…)` へ渡す前に畳む
        noStroke()
        background(0)
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(color(
                hue: mouseY / height * 360,
                saturation: 100,
                brightness: 100))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
