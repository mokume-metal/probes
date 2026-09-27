import mokume

/// 列が使う資源と、いまの描く先。
///
/// **資源は setup で決まった形に作る** — 絵 (`img`)・描き場所 (`g`)・保持した形 (`form`)・
/// 粒 (`dots`)・断片 (`paint`)。列は作り直す口 (`createGraphics` など) で取り替えられる。
/// 番兵だけが使う絵 (`sentinelPicture`) は列から触れない。
final class Stage {
    let sketch: Played
    var main: Canvas { sketch.canvas }
    /// いまの描く先。`beginDraw` で描き場所へ、`endDraw` とフレームの頭で本体へ戻る。
    var current: Canvas
    var picture: Image
    var layer: Canvas
    var form: Shape
    var dots: Particles
    var paint: Shader
    let sentinelPicture: Image

    init(_ sketch: Played) throws {
        self.sketch = sketch
        current = sketch.canvas
        picture = try sketch.createImage(32, 32)
        for y in 0..<32 {
            for x in 0..<32 {
                picture.set(x, y, (x / 8 + y / 8) % 2 == 0 ? color(250, 250, 250) : color(30, 120, 220))
            }
        }
        layer = try sketch.createGraphics(64, 64)
        form = sketch.createShape {
            sketch.rect(-10, -10, 20, 20)
            sketch.ellipse(0, 0, 14, 14)
        }
        dots = try sketch.makeParticles(count: 512)
        paint = try sketch.makeShader(
            "float4 paint(Fragment in, Values values) { return float4(values.k, 0.5, 1 - values.k, 1); }",
            values: ["k": 0.5])
        sentinelPicture = try sketch.createImage(24, 24)
        for y in 0..<24 {
            for x in 0..<24 {
                sentinelPicture.set(x, y, color(Float(x * 10), Float(y * 10), 160))
            }
        }
    }
}

/// 列を 1 本回すスケッチ。**最後のフレームの後に番兵のフレームを 1 枚描く。**
///
/// 番兵は、列が触りうる状態のうちフレームを越えるもの (塗り・線・混ぜ方・字・貼る絵・
/// 断片・露出…。mokume `Canvas.Style` と ADR-0021 決定 4) を明示して既定へ戻してから、
/// 決まった絵を描く。フレームを越えないもの (変換・切り抜き・光・効果・視点) は mokume が
/// フレームの境目で戻す約束なので、番兵は戻さない。**戻さなかったものが番兵の絵に出れば、
/// 境目で戻す約束の破れ**であり、明示して戻したものが出れば、戻す口が効いていない。
final class Played: Sketch {
    var settings = SketchSettings(width: 160, height: 120, frameRate: 30, title: "tumble")

    let program: Program
    /// 真なら番兵を描かず、列のフレームを頭から繰り返す (漏れを測る `Examine.soak`)。
    let loops: Bool
    private(set) var stage: Stage?
    /// 資源を作れなかったとき、その説明。列は回さない。
    private(set) var setupFailure: String?

    init(_ program: Program, loops: Bool = false) {
        self.program = program
        self.loops = loops
    }
    convenience init() { self.init(.empty) }

    func setup() {
        do {
            stage = try Stage(self)
        } catch {
            setupFailure = "\(error)"
            return
        }
        guard let stage else { return }
        for op in program.setup {
            Catalog.byName[op.name]?.apply(stage, stage.current, op.args)
        }
    }

    func draw() {
        guard let stage else { return }
        var index = frameCount - 1
        if loops, !program.frames.isEmpty { index %= program.frames.count }
        guard index < program.frames.count else { return sentinel(stage) }
        stage.current = canvas
        for op in program.frames[index] {
            Catalog.byName[op.name]?.apply(stage, stage.current, op.args)
        }
    }

    /// 番兵。**ここを変えたら、`Repros/` の再現に写した番兵も揃える。**
    func sentinel(_ stage: Stage) {
        stage.current = canvas
        // フレームを越える状態を、明示して既定へ戻す
        fill(255)
        stroke(255)
        strokeWeight(1)
        strokeCap(.round)
        strokeJoin(.miter)
        blendMode(.blend)
        rectMode(.corner)
        ellipseMode(.center)
        imageMode(.corner)
        noTint()
        noTexture()
        resetShader()
        noTextFont()
        textSize(12)
        textStyle(.normal)
        textAlign(.left, .baseline)
        textWrap(.word)
        curveDetail(20)
        curveTightness(0)
        canvas.exposure(1)
        canvas.toneMapping(.clip)

        background(24)
        noStroke()
        fill(220, 60, 40)
        rect(8, 8, 48, 36)
        stroke(40, 200, 90)
        strokeWeight(3)
        line(64, 8, 152, 44)
        noStroke()
        fill(60, 90, 230)
        ellipse(36, 82, 44, 30)
        fill(240)
        textSize(14)
        text("Tb 7", 70, 92)
        image(stage.sentinelPicture, 124, 60, 28, 28)
        fill(250, 200, 40, 128)
        triangle(96, 116, 150, 96, 156, 118)
        lights()
        fill(200)
        translate(128, 104, 0)
        rotateY(0.6)
        box(10)
    }
}
