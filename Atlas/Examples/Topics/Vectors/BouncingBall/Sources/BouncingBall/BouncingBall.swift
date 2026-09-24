import mokume

/// Processing の [Bouncing Ball](https://processing.org/examples/bouncingball/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** `PVector` は `SIMD2<Float>` で書けるが、
/// **`add()` に当たるメソッドが無い**ので `+=` になる。演算としては同じでも、
/// 原典の「ベクトルに足してもらう」書き味は消える。
final class BouncingBall: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Bouncing Ball")

    private var location = SIMD2<Float>(100, 100)   // 形の位置
    private var velocity = SIMD2<Float>(1.5, 2.1)   // 形の速さ
    private let gravity = SIMD2<Float>(0, 0.2)      // 重さ。加速として効く

    func draw() {
        background(0)

        // 位置に速さを足す (原典は `location.add(velocity)`)
        location += velocity
        // 速さに重さを足す
        velocity += gravity

        // 縁で跳ね返る
        if location.x > width || location.x < 0 {
            velocity.x = velocity.x * -1
        }
        if location.y > height {
            // 底に当たったところで、ほんの少し速さを落とす
            velocity.y = velocity.y * -0.95
            location.y = height
        }
        stroke(255)
        strokeWeight(2)
        fill(127)
        ellipse(location.x, location.y, 48, 48)
    }
}
