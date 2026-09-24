import mokume

/// Processing の [Increment Decrement](https://processing.org/examples/incrementdecrement/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。歪みは色のほうが大きい。**
/// 原典の `colorMode(RGB, width)` は**灰色の目盛りを 0〜640 に張り替える** 1 行で、
/// 続く `stroke(a)` の `a` (0〜640) がそのまま明るさになる。mokume には色の範囲を
/// 変える口が無いので、書く側で 255 へ畳み直すことになり、**原典が見せたかった
/// 「目盛りは変えられる」という主題そのものが消える**。
/// `frameRate(30)` も走り出す前にしか決められない。
final class IncrementDecrement: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Increment Decrement")

    private var a: Float = 0
    private var b: Float = 0
    private var direction = true

    func setup() {
        // 原典はここで `colorMode(RGB, width)` を呼ぶ。**書けない**
        a = 0
        b = width
        direction = true
    }

    func draw() {
        a += 1
        if a > width {
            a = 0
            direction = !direction
        }
        if direction == true {
            stroke(a / width * 255)
        } else {
            stroke((width - a) / width * 255)
        }
        line(a, 0, a, height / 2)

        b -= 1
        if b < 0 { b = width }
        if direction == true {
            stroke((width - b) / width * 255)
        } else {
            stroke(b / width * 255)
        }
        line(b, height / 2 + 1, b, height)
    }
}
