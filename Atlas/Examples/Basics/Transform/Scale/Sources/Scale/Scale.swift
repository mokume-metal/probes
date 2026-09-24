import Foundation
import mokume

/// Processing の [Scale](https://processing.org/examples/scale/) を 1 行ずつ移したもの。
/// 原典は Denis Grutze 作。
///
/// **台帳は `bend` と言った。当たっている。歪みが 2 つ。**
/// `scale(s)` の**引数 1 つの一様な拡大が書けない** (mokume は `scale(x, y)` から) のと、
/// `frameRate(30)` が走り出す前にしか決められないこと。
final class Scale: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Scale")

    private var a: Float = 0.0
    private var s: Float = 0.0

    func setup() {
        noStroke()
        rectMode(.center)
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
    }

    func draw() {
        background(102)

        a = a + 0.04
        s = cos(a) * 2

        translate(width / 2, height / 2)
        scale(s, s)     // 原典は `scale(s)` の 1 引数
        fill(51)
        rect(0, 0, 50, 50)

        translate(75, 0)
        fill(255)
        scale(s, s)
        rect(0, 0, 50, 50)
    }
}
