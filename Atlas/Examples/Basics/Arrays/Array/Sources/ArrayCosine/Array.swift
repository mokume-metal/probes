import Foundation
import mokume

/// Processing の [Array](https://processing.org/examples/array/) を 1 行ずつ移したもの。
///
/// **型の名前だけ原典と違う。** 例の名前は `Array` だが、Swift の `Array` とぶつかるので
/// `ArrayCosine` にしてある (例名は置き場が持つので、台帳との対応は崩れない)。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止まるのは進行だけで、
/// `draw()` は毎フレーム同じ線を同じ場所へ引き直していたので**絵は変わらない**。
/// 「口が無い」には、絵が出せないものと、構造だけ壊れるものの 2 つがあり、これは後者だった。
final class ArrayCosine: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Array")

    private var coswave: [Float] = []

    func setup() {
        coswave = (0..<Int(width)).map { i in
            // 原典の `map(i, 0, width, 0, PI)`。**mokume に map が無い** ([#883](https://github.com/mokume-metal/mokume/issues/883))
            let amount = map(Float(i), 0, width, 0, .pi)
            return abs(cos(amount))
        }
        background(255)
        noLoop()
    }

    func draw() {
        var y1: Float = 0
        var y2 = height / 3
        for i in 0..<Int(width) {
            stroke(coswave[i] * 255)
            line(Float(i), y1, Float(i), y2)
        }

        y1 = y2
        y2 = y1 + y1
        for i in 0..<Int(width) {
            stroke(coswave[i] * 255 / 4)
            line(Float(i), y1, Float(i), y2)
        }

        y1 = y2
        y2 = height
        for i in 0..<Int(width) {
            stroke(255 - coswave[i] * 255)
            line(Float(i), y1, Float(i), y2)
        }
    }
}
