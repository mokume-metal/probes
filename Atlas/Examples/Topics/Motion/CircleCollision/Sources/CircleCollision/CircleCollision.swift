import Foundation
import mokume
import Support

/// Processing の [Circle Collision](https://processing.org/examples/circlecollision/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。
///
/// **台帳は `bend` と言った。当たっている。歪みは `PVector` に集まる。**
/// 原典は `PVector.random2D` / `mult` / `sub` / `mag` / `copy` / `normalize` /
/// `heading` / `add` の 8 つを使うが、**mokume にその 8 つに当たるものは 1 つも無い**。
/// `SIMD2<Float>` は演算子を持つので式としては書けるが、
/// **「ベクトルに頼む」という原典の書き味が、こちらでは演算子と自作の関数に散る。**
///
/// 速さを乱数で決めるので **画素では比べられない。**
final class CircleCollision: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Circle Collision")

    final class Ball {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let radius: Float
        let m: Float

        init(_ x: Float, _ y: Float, _ r: Float, angle: Float) {
            position = SIMD2(x, y)
            // 原典は `PVector.random2D()` と `velocity.mult(3)` の 2 行
            velocity = SIMD2(cos(angle), sin(angle)) * 3
            radius = r
            m = r * 0.1
        }

        func update() { position += velocity }

        func checkBoundaryCollision(width: Float, height: Float) {
            if position.x > width - radius {
                position.x = width - radius
                velocity.x *= -1
            } else if position.x < radius {
                position.x = radius
                velocity.x *= -1
            } else if position.y > height - radius {
                position.y = height - radius
                velocity.y *= -1
            } else if position.y < radius {
                position.y = radius
                velocity.y *= -1
            }
        }

        func checkCollision(_ other: Ball) {
            // 2 つの球の隔たり
            let distanceVect = other.position - position
            let distanceVectMag = mag(distanceVect.x, distanceVect.y)
            let minDistance = radius + other.radius
            guard distanceVectMag < minDistance else { return }

            let distanceCorrection = (minDistance - distanceVectMag) / 2.0
            let correctionVector = distanceVect / distanceVectMag * distanceCorrection
            other.position += correctionVector
            position -= correctionVector

            // 隔たりの向き (原典は `distanceVect.heading()`)
            let theta = atan2(distanceVect.y, distanceVect.x)
            let sine = sin(theta)
            let cosine = cos(theta)

            // 回した位置を入れておく。要るのは bTemp[1] だけ
            var bTemp: [SIMD2<Float>] = [.zero, .zero]
            bTemp[1].x = cosine * distanceVect.x + sine * distanceVect.y
            bTemp[1].y = cosine * distanceVect.y - sine * distanceVect.x

            // 速さも回す
            var vTemp: [SIMD2<Float>] = [.zero, .zero]
            vTemp[0].x = cosine * velocity.x + sine * velocity.y
            vTemp[0].y = cosine * velocity.y - sine * velocity.x
            vTemp[1].x = cosine * other.velocity.x + sine * other.velocity.y
            vTemp[1].y = cosine * other.velocity.y - sine * other.velocity.x

            // 回した後なら、1 次元の運動量の保存でぶつかった後の速さが出る
            var vFinal: [SIMD2<Float>] = [.zero, .zero]
            vFinal[0].x = ((m - other.m) * vTemp[0].x + 2 * other.m * vTemp[1].x) / (m + other.m)
            vFinal[0].y = vTemp[0].y
            vFinal[1].x = ((other.m - m) * vTemp[1].x + 2 * m * vTemp[0].x) / (m + other.m)
            vFinal[1].y = vTemp[1].y

            // 固まらないようにずらす
            bTemp[0].x += vFinal[0].x
            bTemp[1].x += vFinal[1].x

            // 位置と速さを元の向きへ戻す
            var bFinal: [SIMD2<Float>] = [.zero, .zero]
            bFinal[0].x = cosine * bTemp[0].x - sine * bTemp[0].y
            bFinal[0].y = cosine * bTemp[0].y + sine * bTemp[0].x
            bFinal[1].x = cosine * bTemp[1].x - sine * bTemp[1].y
            bFinal[1].y = cosine * bTemp[1].y + sine * bTemp[1].x

            other.position = position + bFinal[1]
            position += bFinal[0]

            velocity.x = cosine * vFinal[0].x - sine * vFinal[0].y
            velocity.y = cosine * vFinal[0].y + sine * vFinal[0].x
            other.velocity.x = cosine * vFinal[1].x - sine * vFinal[1].y
            other.velocity.y = cosine * vFinal[1].y + sine * vFinal[1].x
        }

        func display(on sketch: any Sketch) {
            sketch.noStroke()
            sketch.fill(204)
            sketch.ellipse(position.x, position.y, radius * 2, radius * 2)
        }
    }

    private var balls: [Ball] = []

    func setup() {
        balls = [
            Ball(100, 400, 20, angle: random(Float.pi * 2)),
            Ball(700, 400, 80, angle: random(Float.pi * 2)),
        ]
    }

    func draw() {
        background(51)
        for b in balls {
            b.update()
            b.display(on: self)
            b.checkBoundaryCollision(width: width, height: height)
        }
        balls[0].checkCollision(balls[1])
    }
}
