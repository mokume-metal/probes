import mokume

/// mokume を**条件の格子**の上で動かし、**関係**で突く物差し。
///
/// **作品ではない。** 他の物差しが 160² の面・細かさ 1・30 fps の 1 点で mokume の別の経路と
/// 比べるのに対し、こちらは面の大きさ・細かさ・fps を振り、成り立つはずの関係 (鏡映・
/// 90° 回転・平行移動・切り抜き・細かさと縮小・fps をまたいだ 1 秒後) で比べる。数で押さえる
/// のは `Tests/LatticeTests` の側で、窓はそれを目で確かめるためにある (README「何をしているか」)。
///
/// **左右の絵は、それぞれ自前の `SketchRuntime` で描いて貼る。** 面の大きさ・細かさ・fps は
/// 組み立てのときにしか決められないので、条件ごとに別のランタイムが要る。
@main
final class Lattice: Sketch {
    static let tile: Float = 320
    static let gap: Float = 12
    static let margin: Float = 16
    static let header: Float = 56

    var settings = SketchSettings(
        width: Int(margin * 2 + tile * 2 + gap),
        height: Int(header + tile + margin),
        frameRate: 30,
        title: "lattice — mokume v0.12.0")

    private var index = 0
    private var rigs: [Rig] = []

    func setup() { show(0) }

    func show(_ next: Int) {
        index = (next + Pairs.all.count) % Pairs.all.count
        let pair = Pairs.all[index]
        rigs = [Rig(pair.left, frames: pair.frames), Rig(pair.right, frames: pair.frames)]
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1) }
        if keyCode == .arrowLeft { show(index - 1) }
    }

    func draw() {
        background(12)
        let pair = Pairs.all[index]
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Pairs.all.count)  \(pair.title)", Self.margin, 12)
        textSize(12)
        fill(150)
        text("← → で切り替える。左: \(pair.leftLabel)  右: \(pair.rightLabel)", Self.margin, 34)
        for (column, rig) in rigs.enumerated() {
            guard let picture = rig.step(in: self) else { continue }
            // 縦横比を保って升に収める
            let scale = min(Self.tile / Float(picture.width), Self.tile / Float(picture.height))
            image(
                picture, Self.margin + Float(column) * (Self.tile + Self.gap), Self.header,
                Float(picture.width) * scale, Float(picture.height) * scale)
        }
    }
}

/// 窓に並べる 1 組。
struct Pair {
    let title: String
    let leftLabel: String
    let rightLabel: String
    let frames: Int
    let left: @MainActor () -> Scene
    let right: @MainActor () -> Scene
}

enum Pairs {
    static let all: [Pair] = relations + [
        Pair(
            title: "細かさ 0.5 の三角形の経路の太さ 1 の輪郭 (quad)", leftLabel: "上辺 y = 10", rightLabel: "上辺 y = 11",
            frames: 1, left: { Cases.thinOutline(.quad, y: 10, density: 0.5) },
            right: { Cases.thinOutline(.quad, y: 11, density: 0.5) }),
        Pair(
            title: "透明の下地に描いた縁の拡大", leftLabel: "細かさ 0.5", rightLabel: "細かさ 1", frames: 1,
            left: { Cases.edges(density: 0.5, clear: true) }, right: { Cases.edges(density: 1, clear: true) }),
        Pair(
            title: "利用者の効果の in.position で 8 画素の市松", leftLabel: "細かさ 0.5", rightLabel: "細かさ 1",
            frames: 1, left: { Cases.mosaic(density: 0.5) }, right: { Cases.mosaic(density: 1) }),
        Pair(
            title: "clip(10.9, 0, 10, 40) と rect(10.9, 0, 10, 40)", leftLabel: "clip", rightLabel: "rect", frames: 1,
            left: { Cases.clipped(x: 10.9, width: 10, density: 1) },
            right: { Cases.filled(x: 10.9, width: 10, density: 1) }),
        Pair(
            title: "毎秒 fps 個の粒を 1 秒 (50 個のはず / 60 個のはず)", leftLabel: "fps 50", rightLabel: "fps 60",
            frames: 50, left: { Cases.emitRow(fps: 50) }, right: { Cases.emitRow(fps: 60) }),
    ]

    /// 図形ごとに、関係の変換を掛けたものとそのままのもの。
    static let relations: [Pair] = [
        ("circleStroke", Relation.mirrorX), ("text", .rotate90), ("contour", .rotate270),
        ("polylineMiter", .mirrorY), ("rotatedRect", .shift),
    ].map { key, relation in
        Pair(
            title: "\(key) に \(relation.rawValue)", leftLabel: relation.rawValue, rightLabel: "そのまま", frames: 1,
            left: { Cases.figure(Figures.named(key), relation) }, right: { Cases.figure(Figures.named(key)) })
    }
}

/// 1 枚の絵を回す舞台。1 巡を回し終えたら組み直して頭から回す。
final class Rig {
    let make: @MainActor () -> Scene
    let frames: Int
    private var runtime: SketchRuntime?
    private var picture: Image?

    init(_ make: @escaping @MainActor () -> Scene, frames: Int) {
        self.make = make
        self.frames = frames
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        do {
            if runtime == nil || runtime!.frameCount >= frames {
                // 1 枚で済む絵は、組み直さずに同じ絵を貼り続ける
                if runtime != nil, frames == 1, let picture { return picture }
                runtime = try SketchRuntime(sketch: make(), gpu: Rig.gpu)
            }
            let runtime = runtime!
            try runtime.advance()
            let shown = try runtime.target.encodeForDisplay()
            if picture?.width != shown.width || picture?.height != shown.height {
                picture = try host.createImage(shown.width, shown.height)
            }
            picture!.write(shown)
            return picture
        } catch {
            return nil
        }
    }

    static let gpu = try! RenderDevice()
}
