import mokume

/// Processing の [Saturation](https://processing.org/examples/saturation/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。`v0.6.0` でも当たっている。** 色相・彩度・明度で色を作る口は
/// 入ったが ([#778](https://github.com/mokume-metal/mokume/issues/778))、目盛りは 360/100/100 に
/// 固定で、`colorMode(HSB, width, height, 100)` のように**目盛りを張り替える口は無い**。
/// 原典の 1 行が、呼ぶ側での目盛りの畳み込みになる。
///
/// **締めるのも呼ぶ側の仕事。** 原典は目盛りの上限で丸めるが、mokume は丸めず、
/// 上へ突き抜けたぶんを色域の外の色として保つ (ADR-0033 決定 5)。
final class Saturation: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Saturation")

    private let barWidth: Float = 20
    private var lastBar: Float = -1

    func setup() {
        // 原典はここで `colorMode(HSB, width, height, 100)` を呼ぶ。**目盛りを
        // 張り替える口は無い**ので、下の `color(hue:…)` へ渡す前に畳む
        noStroke()
    }

    func draw() {
        let whichBar = (mouseX / barWidth).rounded(.down)
        if whichBar != lastBar {
            let barX = whichBar * barWidth
            fill(color(
                hue: barX / width * 360,
                saturation: constrain(mouseY / height * 100, 0, 100),
                brightness: 66))
            rect(barX, 0, barWidth, height)
            lastBar = whichBar
        }
    }
}
