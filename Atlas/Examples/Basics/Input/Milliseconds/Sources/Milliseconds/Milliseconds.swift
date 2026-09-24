import mokume
import Support

/// Processing の [Milliseconds](https://processing.org/examples/milliseconds/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ。** `millis()` は面に無いが Foundation で書ける。
/// 止まるのは **`colorMode` を帯ごとに呼び直す**ところで、原典は 20 本の帯それぞれで
/// 目盛りを張り替えて「同じ数が違う明るさになる」ことを見せる。mokume は色空間を
/// 持ち替えられないので、書く側が毎回畳むことになり、**主題そのものが薄くなる。**
///
/// 時計を読むので **画素では比べられない。**
final class Milliseconds: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Milliseconds")

    private var scale: Float = 0

    func setup() {
        noStroke()
        scale = width / 20
    }

    func draw() {
        for i in 0..<Int(scale) {
            // 原典はここで `colorMode(RGB, (i+1) * scale * 10)` を呼ぶ。**書けない**
            let top = Float(i + 1) * scale * 10
            fill(millis().truncatingRemainder(dividingBy: top) / top * 255)
            rect(Float(i) * scale, 0, scale, height)
        }
    }
}
