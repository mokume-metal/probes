import mokume

/// Processing の [Simple Particle System](https://processing.org/examples/simpleparticlesystem/) を 1 行ずつ移したもの。
/// 原典は 3 つのタブ (`SimpleParticleSystem` / `Particle` / `ParticleSystem`) に分かれている。
///
/// **台帳は `bend` と言った。当たっている。**`PVector` の `add` / `copy` が無く、
/// `stroke(255, lifespan)` の**明るさ + 透かしの 2 つ組**も書けない。描く口が面の上に
/// あるので `display(on:)` が面を受け取る。
///
/// 乱数で速さを決めるので **画素では比べられない。**
final class SimpleParticleSystem: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Simple Particle System")

    /// 原典の `class Particle`。
    final class Particle {
        var position: SIMD2<Float>
        var velocity: SIMD2<Float>
        let acceleration = SIMD2<Float>(0, 0.05)
        var lifespan: Float = 255.0

        init(_ l: SIMD2<Float>, velocity: SIMD2<Float>) {
            position = l          // 原典は `l.copy()`。**値型なので代入で複製される**
            self.velocity = velocity
        }

        func run(on sketch: any Sketch) {
            update()
            display(on: sketch)
        }

        func update() {
            velocity += acceleration
            position += velocity
            lifespan -= 1.0
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(255, lifespan)
            sketch.fill(255, lifespan)
            sketch.ellipse(position.x, position.y, 8, 8)
        }

        var isDead: Bool { lifespan < 0.0 }
    }

    /// 原典の `class ParticleSystem`。
    final class ParticleSystem {
        var particles: [Particle] = []
        let origin: SIMD2<Float>

        init(_ position: SIMD2<Float>) {
            origin = position
        }

        func addParticle(velocity: SIMD2<Float>) {
            particles.append(Particle(origin, velocity: velocity))
        }

        func run(on sketch: any Sketch) {
            for i in stride(from: particles.count - 1, through: 0, by: -1) {
                particles[i].run(on: sketch)
                if particles[i].isDead { particles.remove(at: i) }
            }
        }
    }

    private var ps: ParticleSystem?

    func setup() {
        ps = ParticleSystem(SIMD2(width / 2, 50))
    }

    func draw() {
        background(0)
        // 原典は Particle の作り方の中で random を呼ぶ。**乱数は面の上にある**ので、
        // クラスの側からは呼べず、作るときに渡すことになる
        ps?.addParticle(velocity: SIMD2(random(-1, 1), random(-2, 0)))
        ps?.run(on: self)
    }
}
