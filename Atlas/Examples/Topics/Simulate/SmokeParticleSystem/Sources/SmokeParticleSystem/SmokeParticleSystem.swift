import Foundation
import mokume
import Support

/// Processing の [Smoke Particle System](https://processing.org/examples/smokeparticlesystem/) を 1 行ずつ移したもの。
/// 原典は 3 つのタブに分かれている。
///
/// **台帳は `bend` と言った。当たっている。歪みが 3 つ。**
/// `randomGaussian()` が無い (面の外に組む)、`PVector` の `add` / `mult` / `mag` /
/// `heading` / `copy` に当たるものが無い、`tint(255, lifespan)` の**明るさ + 透かしの
/// 2 つ組**が書けない。
///
/// 乱数で煙を作るので **画素では比べられない。**
final class SmokeParticleSystem: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Smoke Particle System")

    final class Particle {
        var loc: SIMD2<Float>
        var vel: SIMD2<Float>
        var acc = SIMD2<Float>(0, 0)
        var lifespan: Float = 100.0
        let img: Image?

        init(_ l: SIMD2<Float>, _ img: Image?, velocity: SIMD2<Float>) {
            loc = l
            vel = velocity
            self.img = img
        }

        func run(on sketch: any Sketch) {
            update()
            render(on: sketch)
        }

        /// 力を足す (重さは見ない)
        func applyForce(_ f: SIMD2<Float>) { acc += f }

        func update() {
            vel += acc
            loc += vel
            lifespan -= 2.5
            acc = .zero
        }

        func render(on sketch: any Sketch) {
            sketch.imageMode(.center)
            sketch.tint(255, lifespan)
            if let img { sketch.image(img, loc.x, loc.y) }
        }

        var isDead: Bool { lifespan <= 0.0 }
    }

    final class ParticleSystem {
        var particles: [Particle] = []
        let origin: SIMD2<Float>
        let img: Image?

        init(_ num: Int, _ v: SIMD2<Float>, _ img: Image?, velocity: () -> SIMD2<Float>) {
            origin = v
            self.img = img
            for _ in 0..<num { particles.append(Particle(origin, img, velocity: velocity())) }
        }

        func run(on sketch: any Sketch) {
            for i in stride(from: particles.count - 1, through: 0, by: -1) {
                particles[i].run(on: sketch)
                if particles[i].isDead { particles.remove(at: i) }
            }
        }

        func applyForce(_ dir: SIMD2<Float>) {
            for p in particles { p.applyForce(dir) }
        }

        func addParticle(velocity: SIMD2<Float>) {
            particles.append(Particle(origin, img, velocity: velocity))
        }
    }

    private var ps: ParticleSystem?

    func setup() {
        let img = try? loadImage(asset("Topics/Simulate/SmokeParticleSystem", "texture.png"))
        ps = ParticleSystem(0, SIMD2(width / 2, height - 60), img, velocity: { .zero })
    }

    func draw() {
        background(0)
        // マウスの横の位置で「風」を作る
        let dx = map(mouseX, 0, width, -0.2, 0.2)
        let wind = SIMD2<Float>(dx, 0)
        ps?.applyForce(wind)
        ps?.run(on: self)
        for _ in 0..<2 {
            ps?.addParticle(velocity: SIMD2(randomGaussian() * 0.3, randomGaussian() * 0.3 - 1.0))
        }
        drawVector(wind, SIMD2(width / 2, 50), 500)
    }

    private func drawVector(_ v: SIMD2<Float>, _ loc: SIMD2<Float>, _ scayl: Float) {
        pushMatrix()
        let arrowsize: Float = 4
        translate(loc.x, loc.y)
        stroke(255)
        // 原典は `v.heading()`。**向きを聞く口が無い**ので atan2 で書く
        rotate(atan2(v.y, v.x))
        let len = mag(v.x, v.y) * scayl
        line(0, 0, len, 0)
        line(len, 0, len - arrowsize, arrowsize / 2)
        line(len, 0, len - arrowsize, -arrowsize / 2)
        popMatrix()
    }

    /// 原典の `randomGaussian()`。**mokume の乱数は一様だけ**なので Box–Muller で組む。
    private func randomGaussian() -> Float {
        let u1 = max(random(1), 1e-7)
        let u2 = random(1)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}
