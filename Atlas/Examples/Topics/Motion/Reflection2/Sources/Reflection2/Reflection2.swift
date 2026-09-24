import Foundation
import mokume
import Support

/// Processing の [Reflection 2](https://processing.org/examples/reflection2/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。原典は 3 つのタブ (`Reflection2` / `Ground` / `Orb`) に分かれている。
///
/// **台帳は `bend` と言った。当たっている。**`PVector` の `add` / `copy` が無いのと、
/// 描く口が面の上にあるので `display(on:)` が面を受け取ること。
/// `dist()` も無いので面の外に書く。
///
/// 乱数で地面を作るので **画素では比べられない。**
final class Reflection2: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reflection 2")

    /// 原典の `class Ground`。
    struct Ground {
        let x1: Float, y1: Float, x2: Float, y2: Float
        let x: Float, y: Float, len: Float, rot: Float

        init(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) {
            self.x1 = x1; self.y1 = y1; self.x2 = x2; self.y2 = y2
            x = (x1 + x2) / 2
            y = (y1 + y2) / 2
            len = dist(x1, y1, x2, y2)
            rot = atan2(y2 - y1, x2 - x1)
        }
    }

    /// 原典の `class Orb`。位置と速さを持つ。
    final class Orb {
        var position: SIMD2<Float>
        var velocity = SIMD2<Float>(0.5, 0)
        let r: Float
        /// 地面に当たったときに 80% へ落とす
        let damping: Float = 0.8

        init(_ x: Float, _ y: Float, _ r: Float) {
            position = SIMD2(x, y)
            self.r = r
        }

        func move(gravity: SIMD2<Float>) {
            velocity += gravity
            position += velocity
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.fill(200)
            sketch.ellipse(position.x, position.y, r * 2, r * 2)
        }

        func checkWallCollision(width: Float) {
            if position.x > width - r {
                position.x = width - r
                velocity.x *= -damping
            } else if position.x < r {
                position.x = r
                velocity.x *= -damping
            }
        }

        func checkGroundCollision(_ groundSegment: Ground) {
            var deltaX = position.x - groundSegment.x
            var deltaY = position.y - groundSegment.y
            let cosine = cos(groundSegment.rot)
            let sine = sin(groundSegment.rot)
            // 直交して当たりを見られるよう、地面と速さを回す
            let groundXTemp = cosine * deltaX + sine * deltaY
            var groundYTemp = cosine * deltaY - sine * deltaX
            let velocityXTemp = cosine * velocity.x + sine * velocity.y
            var velocityYTemp = cosine * velocity.y - sine * velocity.x

            if groundYTemp > -r && position.x > groundSegment.x1 && position.x < groundSegment.x2 {
                groundYTemp = -r
                velocityYTemp *= -1.0
                velocityYTemp *= damping
            }

            deltaX = cosine * groundXTemp - sine * groundYTemp
            deltaY = cosine * groundYTemp + sine * groundXTemp
            velocity.x = cosine * velocityXTemp - sine * velocityYTemp
            velocity.y = cosine * velocityYTemp + sine * velocityXTemp
            position.x = groundSegment.x + deltaX
            position.y = groundSegment.y + deltaY
        }
    }

    private var orb: Orb?
    private let gravity = SIMD2<Float>(0, 0.05)
    private let segments = 40
    private var ground: [Ground] = []

    func setup() {
        orb = Orb(50, 50, 3)
        // 地面の高さを決める
        let peakHeights = (0...segments).map { _ in random(height - 40, height - 30) }
        let segs = Float(segments)
        ground = (0..<segments).map {
            Ground(width / segs * Float($0), peakHeights[$0],
                   width / segs * Float($0 + 1), peakHeights[$0 + 1])
        }
    }

    func draw() {
        noStroke()
        fill(0, 15)
        rect(0, 0, width, height)

        guard let orb else { return }
        orb.move(gravity: gravity)
        orb.display(on: self)
        orb.checkWallCollision(width: width)
        for segment in ground { orb.checkGroundCollision(segment) }

        fill(127)
        beginShape()
        for segment in ground {
            vertex(segment.x1, segment.y1)
            vertex(segment.x2, segment.y2)
        }
        vertex(ground[segments - 1].x2, height)
        vertex(ground[0].x1, height)
        endShape(.close)
    }
}
