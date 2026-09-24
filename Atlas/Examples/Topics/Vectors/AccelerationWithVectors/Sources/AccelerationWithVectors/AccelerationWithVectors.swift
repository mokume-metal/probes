import mokume
import Support

/// Processing の [Acceleration With Vectors](https://processing.org/examples/accelerationwithvectors/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** 原典は `PVector.sub` / `setMag` /
/// `add` / `limit` の 4 つで「向きと大きさを別々に扱う」ところを見せるが、
/// **mokume にその 4 つに当たるものは無い**ので、長さで割って掛け直す式になる。
final class AccelerationWithVectors: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Acceleration With Vectors")

    /// 原典の `class Mover`。位置・速さ・加速を持つ。
    final class Mover {
        var location: SIMD2<Float>
        var velocity = SIMD2<Float>(0, 0)
        let topspeed: Float = 5

        init(width: Float, height: Float) {
            location = SIMD2(width / 2, height / 2)
        }

        func update(mouseX: Float, mouseY: Float) {
            // 位置からマウスへ向くベクトル
            let mouse = SIMD2<Float>(mouseX, mouseY)
            var acceleration = mouse - location
            // 原典は `acceleration.setMag(0.2)`。**長さを決め直す口が無い**
            let length = mag(acceleration.x, acceleration.y)
            acceleration = length > 0 ? acceleration / length * 0.2 : .zero

            velocity += acceleration
            // 原典は `velocity.limit(topspeed)`。**上限で切る口も無い**
            let speed = mag(velocity.x, velocity.y)
            if speed > topspeed { velocity = velocity / speed * topspeed }
            location += velocity
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(255)
            sketch.strokeWeight(2)
            sketch.fill(127)
            sketch.ellipse(location.x, location.y, 48, 48)
        }
    }

    private var mover: Mover?

    func setup() {
        mover = Mover(width: width, height: height)
    }

    func draw() {
        background(0)
        mover?.update(mouseX: mouseX, mouseY: mouseY)
        mover?.display(on: self)
    }
}
