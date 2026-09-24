import Foundation
import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ動きになるはずの 2 つの経路で描く。** `suspect` は疑っている口を
/// 通し、`reference` は同じ動きを別の (素朴な) 口で作る。Probe と違って比べるのは
/// 1 枚ではなく**動き**で、食い違いはフレームを重ねてはじめて出る。
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum MotionKey: String, CaseIterable, Sendable {
    case graphicsTime, sharedEmitter, effectsCarry, numbersOnce, dragLowRate
}

/// 候補 1 件の 1 経路。**状態を持つ** (面・粒・断片・並び) ので、経路ごとに 1 つ作る。
///
/// 描くのは `origin` を左上とする `Motions.side` 四方。窓では 1 枚の本体の面に候補を
/// 並べるので、**描き終えたら描き方を戻しておく** (断片・並び・切り抜き)。
@MainActor
protocol Motion: AnyObject {
    init(route: Route)
    func setup<S: Sketch>(_ s: S)
    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>)
}

struct MotionCase {
    let key: MotionKey
    /// 窓のタイルに出す見出し。
    let title: String
    let make: @MainActor (Route) -> any Motion
}

enum Motions {
    /// 1 経路ぶんの一辺。
    static let side = 160
    /// 窓もテストもこの速さで回す。`dragLowRate` の刻み (Δt = 1/30) はここから決まる。
    static let frameRate = 30

    static let all: [MotionCase] = [
        MotionCase(key: .graphicsTime, title: "描き場所の in.time") { GraphicsTime(route: $0) },
        MotionCase(key: .sharedEmitter, title: "1 つの粒に 2 つの噴き口") { SharedEmitter(route: $0) },
        MotionCase(key: .effectsCarry, title: "残像の上の効果") { EffectsCarry(route: $0) },
        MotionCase(key: .numbersOnce, title: "1 度だけ渡した numbers") { NumbersOnce(route: $0) },
        MotionCase(key: .dragLowRate, title: "30 fps の drag(70)") { DragLowRate(route: $0) },
    ]

    static func named(_ key: MotionKey) -> MotionCase {
        all.first { $0.key == key }!
    }
}

// MARK: - 時刻

/// 秒数で脈打つ断片。**`time` が進んでいれば、描き場所でも本体でも同じ色で脈打つ。**
///
/// 描き場所 (`createGraphics`) の説明は「2D も立体も字も効果も、画面と同じように書ける」と
/// 約束している。参照は本体の面へ直に塗ったもの。
final class GraphicsTime: Motion {
    /// 2 秒で 1 往復。0.5 秒で赤が最も強い。
    static let body = """
        float4 paint(Fragment in, Values values) {
            float k = 0.5 + 0.5 * sin(in.time * 3.14159265);
            return float4(k, 0.3 * k, 0.9 * (1.0 - k), 1.0);
        }
        """

    let route: Route
    private var pulse: Shader!
    private var surface: Canvas?

    init(route: Route) { self.route = route }

    func setup<S: Sketch>(_ s: S) {
        pulse = try! s.makeShader(Self.body, name: "pulse")
        if route == .suspect { surface = try! s.createGraphics(Motions.side, Motions.side) }
    }

    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>) {
        let side = Float(Motions.side)
        switch route {
        case .suspect:
            let surface = surface!
            surface.beginDraw()
            surface.noStroke()
            surface.shader(pulse)
            surface.rect(0, 0, side, side)
            surface.resetShader()
            surface.endDraw()
            s.image(surface, origin.x, origin.y)
        case .reference:
            s.noStroke()
            s.shader(pulse)
            s.rect(origin.x, origin.y, side, side)
            s.resetShader()
        }
    }
}

// MARK: - 粒

/// 左に橙、右に青の噴き口。**毎秒 15 個ずつ、30 fps なら 2 フレームに 1 個ずつ出る**はず。
///
/// `emit` の説明は、端数を繰り越すので「低いレートでも、長い目で見て頼んだ数が出る」と
/// 約束している。疑う口は 1 つの `Particles` へ 2 か所から出し、参照は噴き口ごとに
/// 別の `Particles` を持つ。
final class SharedEmitter: Motion {
    static let orange = LinearRGBA.display(red: 0.95, green: 0.55, blue: 0.15)
    static let blue = LinearRGBA.display(red: 0.2, green: 0.6, blue: 0.95)

    let route: Route
    private var left: Particles!
    private var right: Particles!

    init(route: Route) { self.route = route }

    func setup<S: Sketch>(_ s: S) {
        left = try! s.makeParticles(count: 256)
        right = route == .suspect ? left : try! s.makeParticles(count: 256)
    }

    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>) {
        let up = -Float.pi / 2
        for (particles, x, color) in [(left!, Float(45), Self.orange), (right!, Float(115), Self.blue)] {
            s.emit(
                particles, from: .point(origin.x + x, origin.y + 140), rate: 15,
                speed: 70...90, angle: (up - 0.25)...(up + 0.25), life: 1.6...1.6,
                size: 6...6, color: color)
        }
        s.force(left, .gravity(0, 40))
        s.particles(left)
        if right !== left {
            s.force(right, .gravity(0, 40))
            s.particles(right)
        }
    }
}

/// 出た位置のすぐそばで止まるはずの粒。
///
/// `.drag(a)` の説明は「速さに逆らう。1 秒あたりに削る割合」。a = 70 なら速さは 1/70 秒で
/// 1/e になり、出た粒は v / a ≈ 0.9 px 進んで止まる。参照はその解 `x0 + v/a (1 - e^{-a t})`
/// を CPU で描いた点。**刻みが粗いと、`1 − a·Δt` が負になる** (30 fps で −1.33)。
final class DragLowRate: Motion {
    static let drag: Float = 70
    static let speed: Float = 60
    /// 何秒ごとに 1 個出すか。
    static let interval: Float = 0.5
    static let life: Float = 3
    static let color = LinearRGBA.display(red: 0.95, green: 0.3, blue: 0.5)

    let route: Route
    private var dust: Particles!
    /// 参照の側が出した粒の、生まれてからの秒数。
    private var ages: [Float] = []
    private var sinceLast: Float = .infinity

    init(route: Route) { self.route = route }

    func setup<S: Sketch>(_ s: S) {
        if route == .suspect { dust = try! s.makeParticles(count: 64) }
    }

    /// 噴き口。タイルの左寄りの中ほど。
    static func source(_ origin: SIMD2<Float>) -> SIMD2<Float> { origin + [30, 80] }

    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>) {
        let side = Float(Motions.side)
        let start = Self.source(origin)
        // 飛び去った粒が隣のタイルを汚さないように切る。切り抜きは面の座標で読まれる
        s.clip(origin.x, origin.y, side, side)
        switch route {
        case .suspect:
            s.emit(
                dust, from: .point(start.x, start.y), rate: 1 / Self.interval,
                speed: Self.speed...Self.speed, angle: 0...0, life: Self.life...Self.life,
                size: 8...8, color: Self.color)
            s.force(dust, .drag(Self.drag))
            s.particles(dust)
        case .reference:
            // 噴き口と同じ繰り越しで出す: 間隔が溜まったら 1 個
            let dt = s.deltaTime
            ages = ages.map { $0 + dt }.filter { $0 < Self.life }
            sinceLast += dt
            if sinceLast >= Self.interval {
                ages.append(0)
                sinceLast = sinceLast.isFinite ? sinceLast - Self.interval : 0
            }
            s.noStroke()
            s.fill(Self.color)
            for age in ages {
                let x = start.x + Self.speed / Self.drag * (1 - exp(-Self.drag * age))
                s.rect(x - 4, start.y - 4, 8, 8)
            }
        }
        s.noClip()
    }
}

// MARK: - フレームをまたぐ描き方

/// 残像を残す面にかける `vignette`。**縁の暗さはフレームによらず一定**のはず。
///
/// `effects` の説明は「フレームの終わりに立つ段」「フレームを越えない」「フレームの途中で
/// 読む画素にはまだ効いていない」。効果が段なら、残像 (前のフレームの絵) は効果を通す
/// 前の絵で、縁は毎フレーム同じだけ暗くなる。参照は毎フレーム下地から描き直す面。
///
/// 効果は面全体にかかるので、経路ごとに自前の描き場所へ描いて貼る。
final class EffectsCarry: Motion {
    let route: Route
    private var surface: Canvas!
    private var frames = 0

    init(route: Route) { self.route = route }

    func setup<S: Sketch>(_ s: S) {
        surface = try! s.createGraphics(Motions.side, Motions.side)
    }

    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>) {
        frames += 1
        let side = Float(Motions.side)
        let angle = Float(frames) * 0.12
        surface.beginDraw()
        if route == .reference || frames == 1 { surface.background(235) }
        surface.noStroke()
        surface.fill(40, 120, 220)
        surface.circle(side / 2 + 45 * cos(angle), side / 2 + 45 * sin(angle), 18)
        surface.effects([.vignette(amount: 0.6)])
        surface.endDraw()
        s.image(surface, origin.x, origin.y)
    }
}

/// `in.numbers[0]` の明るさで塗る断片と、毎フレーム値を書き換える並び。
///
/// 断片 (`shader`) は説明が「フレームを越える」と名乗る。並び (`numbers`) は寿命を
/// 名乗っていない。疑う口は並びを 1 枚目だけ渡し、以後は値だけを書き換える —
/// **並びは値を差し替える箱**なので、渡し直さずに中身だけ変えるのがふつうの書き方である。
/// 参照は毎フレーム渡し直す。
final class NumbersOnce: Motion {
    static let body = """
        float4 paint(Fragment in, Values values) {
            float k = in.numbers[0];
            return float4(0.15 + 0.8 * k, 0.75 * k, 0.2, 1.0);
        }
        """

    let route: Route
    private var glow: Shader!
    private var level: Numbers!
    private var frames = 0

    init(route: Route) { self.route = route }

    func setup<S: Sketch>(_ s: S) {
        glow = try! s.makeShader(Self.body, name: "glow")
        level = try! s.makeNumbers(count: 1)
    }

    /// 2 秒で 1 往復する値。
    static func level(at time: Float) -> Float { 0.5 + 0.5 * sin(time * .pi) }

    func draw<S: Sketch>(_ s: S, at origin: SIMD2<Float>) {
        frames += 1
        level.set(Self.level(at: s.time), at: 0)
        s.noStroke()
        s.shader(glow)
        if route == .reference || frames == 1 { s.numbers(level) }
        s.rect(origin.x, origin.y, Float(Motions.side), Float(Motions.side))
        s.resetShader()
        // 疑う口は外さない (外したら比べられない)。参照は、後に描くタイルへ並びを
        // 貸さないように外す
        if route == .reference { s.resetNumbers() }
    }
}
