import Foundation
import mokume
import Support

/// Processing の [Reflection 1](https://processing.org/examples/reflection1/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。
///
/// **台帳は `bend` と言った。当たっている。** ここも歪みは `PVector` に集まる —
/// `random2D` / `mult` / `sub` / `normalize` / `dist` / `dot` / `set` / `add` の
/// **8 つに当たるものが 1 つも無い**。内積 (`dot`) だけは `SIMD2` の演算で書けるが、
/// 名前が消える。
///
/// 乱数で速さと地面を決めるので **画素では比べられない。**
final class Reflection1: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reflection 1")

    private var base1 = SIMD2<Float>(0, 0)
    private var base2 = SIMD2<Float>(0, 0)
    private var baseLength: Float = 0
    private var coords: [SIMD2<Float>] = []
    private var position = SIMD2<Float>(0, 0)
    private var velocity = SIMD2<Float>(0, 0)
    private let r: Float = 6
    private let speed: Float = 3.5

    func setup() {
        fill(128)
        base1 = SIMD2(0, height - 150)
        base2 = SIMD2(width, height)
        createGround()
        // 円は面の上の真ん中から始める
        position = SIMD2(width / 2, 0)
        // 初めの速さを乱数で決める (原典は `PVector.random2D()` と `mult(speed)`)
        let angle = random(Float.pi * 2)
        velocity = SIMD2(cos(angle), sin(angle)) * speed
    }

    func draw() {
        fill(0, 12)
        noStroke()
        rect(0, 0, width, height)
        // 地面
        fill(200)
        quad(base1.x, base1.y, base2.x, base2.y, base2.x, height, 0, height)
        // 地面の法線
        let delta = base2 - base1
        let baseDelta = delta / mag(delta.x, delta.y)
        let normal = SIMD2<Float>(-baseDelta.y, baseDelta.x)
        // 円
        noStroke()
        fill(255)
        ellipse(position.x, position.y, r * 2, r * 2)
        position += velocity
        // 入ってくる向き (長さ 1)
        var incidence = velocity * -1
        incidence /= mag(incidence.x, incidence.y)
        // 地面に当たったか
        for coord in coords {
            if dist(position.x, position.y, coord.x, coord.y) < r {
                // 原典は `incidence.dot(normal)`。**内積を頼む口が無い**
                let dot = incidence.x * normal.x + incidence.y * normal.y
                velocity = SIMD2(2 * normal.x * dot - incidence.x,
                                 2 * normal.y * dot - incidence.y) * speed
                stroke(255, 128, 0)
                line(position.x, position.y,
                     position.x - normal.x * 100, position.y - normal.y * 100)
            }
        }
        // 面の縁
        if position.x > width - r {
            position.x = width - r
            velocity.x *= -1
        }
        if position.x < r {
            position.x = r
            velocity.x *= -1
        }
        if position.y < r {
            position.y = r
            velocity.y *= -1
            base1.y = random(height - 100, height)
            base2.y = random(height - 100, height)
            createGround()
        }
    }

    private func createGround() {
        baseLength = dist(base1.x, base1.y, base2.x, base2.y)
        coords = (0..<Int(baseLength.rounded(.up))).map {
            SIMD2(base1.x + ((base2.x - base1.x) / baseLength) * Float($0),
                  base1.y + ((base2.y - base1.y) / baseLength) * Float($0))
        }
    }
}
