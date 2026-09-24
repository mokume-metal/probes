import Foundation
import mokume
import Support

/// Processing の [Rotate](https://processing.org/examples/rotate/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっている** — `second()` が無い。mokume に壁時計は
/// 無く、あるのは起動からの秒 (`time`) と `frameCount` と `deltaTime` だけなので、
/// 原典の「偶数秒のあいだだけ揺らす」は**時計の読み替えになる**。
///
/// 乱数を使うので **画素では比べられない。**
final class Rotate: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Rotate")

    private var angle: Float = 0
    private var jitter: Float = 0

    func setup() {
        noStroke()
        fill(255)
        rectMode(.center)
    }

    func draw() {
        background(51)
        // 原典は `second() % 2 == 0` (壁時計の偶数秒)。**書けない**ので、起動からの秒で読む
        if Int(time) % 2 == 0 {
            jitter = random(-0.1, 0.1)
        }
        angle = angle + jitter
        let c = cos(angle)
        translate(width / 2, height / 2)
        rotate(c)
        rect(0, 0, 180, 180)
    }
}
