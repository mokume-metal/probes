import Foundation
import mokume
import Support

/// Processing の [Flocking](https://processing.org/examples/flocking/) を 1 行ずつ移したもの。
/// 原典は 3 つのタブ (`Flocking` / `Flock` / `Boid`) に分かれている。
///
/// **台帳は `bend` と言った。`v0.6.0` で歪みが 3 つから 2 つに減った。**
/// 1. **`PVector` に当たるメソッドが 1 つも無い** — `add` / `sub` / `mult` / `div` /
///    `normalize` / `limit` / `mag` / `dist` / `heading2D` の 9 個をすべて書き直す。
///    この例は**ベクトルの算術そのものが主題**なので、歪みがいちばん大きく出る
/// 2. `beginShape(TRIANGLES)` は `VertexKind.triangles` で当たる (ここは届く)
/// 3. `mousePressed()` の口は **`v0.6.0` で入った**
///    ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。押した場所へ 1 羽足せる
///
/// 乱数で向きを決めるので **画素では比べられない。**
final class Flocking: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Flocking")

    /// 原典の `class Boid`。
    final class Boid {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        var acceleration = SIMD2<Float>(0, 0)
        let r: Float = 2.0
        let maxforce: Float = 0.03   // 向きを変える力の上限
        let maxspeed: Float = 2      // 速さの上限

        init(_ x: Float, _ y: Float, angle: Float) {
            velocity = SIMD2(cos(angle), sin(angle))
            position = SIMD2(x, y)
        }

        func run(_ boids: [Boid], on sketch: any Sketch) {
            flock(boids)
            update()
            borders(width: sketch.width, height: sketch.height)
            render(on: sketch)
        }

        func applyForce(_ force: SIMD2<Float>) { acceleration += force }

        /// 3 つの決まりから、毎回あたらしい加速を積む
        func flock(_ boids: [Boid]) {
            applyForce(separate(boids) * 1.5)
            applyForce(align(boids) * 1.0)
            applyForce(cohesion(boids) * 1.0)
        }

        func update() {
            velocity += acceleration
            velocity = limit(velocity, maxspeed)
            position += velocity
            acceleration = .zero
        }

        /// 目標へ向く力 (向きたい方向 − いまの速さ)
        func seek(_ target: SIMD2<Float>) -> SIMD2<Float> {
            var desired = target - position
            desired = normalized(desired) * maxspeed
            return limit(desired - velocity, maxforce)
        }

        func render(on sketch: any Sketch) {
            // 速さの向きへ回した三角形を描く。原典は `velocity.heading2D()`
            let theta = atan2(velocity.y, velocity.x) + radians(90)

            sketch.fill(200, 100)
            sketch.stroke(255)
            sketch.pushMatrix()
            sketch.translate(position.x, position.y)
            sketch.rotate(theta)
            sketch.beginShape(.triangles)
            sketch.vertex(0, -r * 2)
            sketch.vertex(-r, r * 2)
            sketch.vertex(r, r * 2)
            sketch.endShape()
            sketch.popMatrix()
        }

        /// 端をまたいで反対側へ出す
        func borders(width: Float, height: Float) {
            if position.x < -r { position.x = width + r }
            if position.y < -r { position.y = height + r }
            if position.x > width + r { position.x = -r }
            if position.y > height + r { position.y = -r }
        }

        /// 離れる — 近すぎる相手から離れる向きの力
        func separate(_ boids: [Boid]) -> SIMD2<Float> {
            let desiredseparation: Float = 25.0
            var steer = SIMD2<Float>(0, 0)
            var count = 0
            for other in boids {
                let d = dist(position.x, position.y, other.position.x, other.position.y)
                if d > 0 && d < desiredseparation {
                    steer += normalized(position - other.position) / d
                    count += 1
                }
            }
            if count > 0 { steer /= Float(count) }
            if mag(steer.x, steer.y) > 0 {
                steer = normalized(steer) * maxspeed - velocity
                steer = limit(steer, maxforce)
            }
            return steer
        }

        /// 揃える — 近くの相手の速さの平均へ寄せる
        func align(_ boids: [Boid]) -> SIMD2<Float> {
            let neighbordist: Float = 50
            var sum = SIMD2<Float>(0, 0)
            var count = 0
            for other in boids {
                let d = dist(position.x, position.y, other.position.x, other.position.y)
                if d > 0 && d < neighbordist {
                    sum += other.velocity
                    count += 1
                }
            }
            guard count > 0 else { return SIMD2(0, 0) }
            sum = normalized(sum / Float(count)) * maxspeed
            return limit(sum - velocity, maxforce)
        }

        /// 集まる — 近くの相手の真ん中へ向かう
        func cohesion(_ boids: [Boid]) -> SIMD2<Float> {
            let neighbordist: Float = 50
            var sum = SIMD2<Float>(0, 0)
            var count = 0
            for other in boids {
                let d = dist(position.x, position.y, other.position.x, other.position.y)
                if d > 0 && d < neighbordist {
                    sum += other.position
                    count += 1
                }
            }
            guard count > 0 else { return SIMD2(0, 0) }
            return seek(sum / Float(count))
        }

        // 原典の `normalize()` と `limit()`。**どちらも mokume に当たるものが無い**
        private func normalized(_ v: SIMD2<Float>) -> SIMD2<Float> {
            let length = mag(v.x, v.y)
            return length > 0 ? v / length : v
        }

        private func limit(_ v: SIMD2<Float>, _ maximum: Float) -> SIMD2<Float> {
            let length = mag(v.x, v.y)
            return length > maximum ? v / length * maximum : v
        }
    }

    /// 原典の `class Flock`。
    final class Flock {
        var boids: [Boid] = []

        func run(on sketch: any Sketch) {
            for b in boids { b.run(boids, on: sketch) }
        }

        func addBoid(_ b: Boid) { boids.append(b) }
    }

    private let flock = Flock()

    func setup() {
        for _ in 0..<150 {
            flock.addBoid(Boid(width / 2, height / 2, angle: random(Float.pi * 2)))
        }
    }

    func draw() {
        background(50)
        flock.run(on: self)
    }

    /// 原典の `void mousePressed()` — 押した場所へ 1 羽足す。
    func mousePressed() {
        flock.addBoid(Boid(mouseX, mouseY, angle: random(Float.pi * 2)))
    }
}
