import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ絵になるはずの 2 つの経路で描く。** 2 つの経路は、関係ごとに 1 つのことだけが違う
/// (``Relation``)。食い違えば、絵がその 1 つに引きずられている。
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 2 つの経路が何だけ違うか。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum Relation: Sendable {
    /// **履歴だけが違う。** 前置きの枚数で、`suspect` はがらくたを描き、`reference` は何も描かない。
    /// フレーム番号と `randomSeed` は揃えるので、前置きの後の絵は同じはずである。
    case history
    /// **runtime の積み重ねだけが違う。** `suspect` は 1 つの runtime で場面の列を回し、`reference` は
    /// 同じ場面を 1 枚ずつ新しい runtime の 1 枚目として描く。時刻を読まない場面に限る。
    case fresh
    /// **数だけが違う。** `suspect` は比べる領域の外に物体を足し、その数をフレームごとに変える。
    /// 比べる領域 (``ChurnCase/columns``) の絵は同じはずである。
    case locality
    /// **置き方だけが違う。** `suspect` はまとめて描き、`reference` は 1 つずつ描く。
    case equivalence
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum ChurnKey: String, CaseIterable, Sendable {
    // 履歴
    case historyBlank, historyMixed2D, historyParticles, history3DShadows
    // runtime の積み重ね
    case fresh2D, fresh3D
    // 数
    case localityForms, localityFolding, localityInstanceCap, localitySweep, localityShadow
    // 置き方
    case shapeAtRegions, shapeAtTranslucent, shapeAtSingleRegion, shapeAt3D
    case graphicsReuse, graphicsKeptAlive
}

/// 候補 1 件。**1 経路 = 1 本のスケッチ**で、経路ごとに別の `SketchRuntime` で回す (Weave と同じ形)。
struct ChurnCase {
    let key: ChurnKey
    let relation: Relation
    /// 窓のタイルに出す見出し。
    let title: String
    /// 1 巡のフレーム数。
    let frames: Int
    /// 比べるフレーム。省くと全部。
    let compared: ClosedRange<Int>?
    /// 比べる列。省くと全部 (``Relation/locality`` は物体を足す側を外す)。
    let columns: Range<Int>?
    /// 資源を作る。`setup()` で 1 度だけ呼ぶ。
    let prepare: @MainActor (Stir) -> Void
    /// 1 枚ぶん描く。経路は `stir.route`、何枚目かは `stir.frame` で分ける。
    let body: @MainActor (Stir) -> Void

    init(
        _ key: ChurnKey, _ relation: Relation, _ title: String, frames: Int,
        compared: ClosedRange<Int>? = nil, columns: Range<Int>? = nil,
        prepare: @escaping @MainActor (Stir) -> Void = { _ in },
        _ body: @escaping @MainActor (Stir) -> Void
    ) {
        self.key = key
        self.relation = relation
        self.title = title
        self.frames = frames
        self.compared = compared
        self.columns = columns
        self.prepare = prepare
        self.body = body
    }

    var comparedFrames: ClosedRange<Int> { compared ?? 1...frames }

    /// 1 経路のスケッチ。`offset` は ``Relation/fresh`` の参照が、何枚目から描き始めるか。
    @MainActor func make(_ route: Route, seed: UInt64 = Scenes.seed, offset: Int = 0) -> Stir {
        Stir(route: route, seed: seed, offset: offset, prepare: prepare, body: body)
    }
}

/// 候補 1 件の 1 経路のスケッチ。資源の置き場を持ち、描くのは候補の `body` に任せる。
final class Stir: Sketch {
    var settings = Scenes.settings
    let route: Route
    /// 場面の列とがらくたを作る種。
    let seed: UInt64
    /// 1 始まりのフレーム番号 (`draw()` の頭で進める)。``Relation/fresh`` の参照は `offset` から数える。
    private(set) var frame: Int
    /// 資源の置き場。
    let bag = Bag()
    /// `graphicsReuse` で、捨てた描き場所の `ObjectIdentifier` を新しい描き場所が引き継いだ回数。
    /// 引き継がなかったら破れの条件が立っていないので、検査はこれを先に押さえる。
    var reused = 0

    private let prepare: (Stir) -> Void
    private let body: (Stir) -> Void

    init(route: Route, seed: UInt64, offset: Int, prepare: @escaping (Stir) -> Void, body: @escaping (Stir) -> Void) {
        self.route = route
        self.seed = seed
        self.frame = offset
        self.prepare = prepare
        self.body = body
    }
    /// `Sketch` が求めるだけで、窓からもテストからも呼ばない。
    convenience init() { self.init(route: .reference, seed: 0, offset: 0, prepare: { _ in }, body: { _ in }) }

    var suspect: Bool { route == .suspect }

    func setup() { prepare(self) }

    func draw() {
        frame += 1
        body(self)
    }
}

/// スケッチが持つ資源。
final class Bag {
    var image: Image!
    var shape: Shape!
    var layer: Canvas!
    var paint: Shader!
    var cloud: Particles?
    /// がらくたが作っては捨てる群と描き場所。
    var junkClouds: [Particles] = []
    var junkLayers: [Canvas] = []
    /// 種から作った場面の列 (1 枚目が添字 0)。
    var scenes: [[Thing]] = []
    var random = SplitMix(seed: 0)
}

/// 種から決まる乱数 (SplitMix64)。**mokume の乱数は使わない** — 粒が同じ流れを読むので、場面を作る
/// だけで粒の絵が変わってしまう。
struct SplitMix {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// `0..<n` の整数。
    mutating func int(_ n: Int) -> Int { Int(next() % UInt64(n)) }
    /// `a...b` の小数 (100 万段)。
    mutating func float(_ a: Float, _ b: Float) -> Float { a + (b - a) * Float(next() % 1_000_000) / 1_000_000 }
}

/// 場面に置く物体 1 つ。
struct Thing {
    enum Kind: CaseIterable {
        case rect, ellipse, triangle, line, strokedRect, translucent, text, image, shape, shapeAt, arc, quad, star
        case graphics
    }
    var kind: Kind
    var x, y, w, h, angle: Float
    var red, green, blue, alpha: Float
    /// 生まれた順の番号。文字と 3D の形の選び方に使う。
    var id: Int
}

enum Scenes {
    /// 1 経路ぶんの一辺 (論理の大きさ)。
    static let side = 200
    static let frameRate = 30
    /// 窓とテストが既定で使う種。
    static let seed: UInt64 = 1

    static var settings: SketchSettings {
        SketchSettings(width: side, height: side, frameRate: frameRate, title: "churn")
    }

    /// **増やし・消し・動かす列。** 毎フレーム、5 つに 1 つを消し、ランダムな位置へ足し、全部を少し
    /// 動かして回す。足す位置は列の途中にも入るので、描く順も入れ替わる。
    static func scenes(seed: UInt64, frames: Int, kinds: [Thing.Kind], limit: Int) -> [[Thing]] {
        var random = SplitMix(seed: seed)
        var things: [Thing] = []
        var born = 0
        var list: [[Thing]] = []
        for _ in 0..<frames {
            things.removeAll { _ in random.int(5) == 0 }
            for _ in 0..<random.int(limit / 3 + 1) where things.count < limit {
                born += 1
                let thing = Thing(
                    kind: kinds[random.int(kinds.count)], x: random.float(0, 200), y: random.float(0, 200),
                    w: random.float(4, 60), h: random.float(4, 60), angle: random.float(0, 6.28),
                    red: Float(random.int(256)), green: Float(random.int(256)), blue: Float(random.int(256)),
                    alpha: random.int(2) == 0 ? 255 : Float(40 + random.int(200)), id: born)
                things.insert(thing, at: random.int(things.count + 1))
            }
            for i in things.indices {
                things[i].x += random.float(-15, 15)
                things[i].y += random.float(-15, 15)
                things[i].angle += random.float(-0.3, 0.3)
            }
            list.append(things)
        }
        return list
    }

    /// 場面が読む資源を作る。どの経路も同じものを作る。
    @MainActor static func prepareAssets(_ s: Stir) {
        s.bag.image = try! s.createImage(16, 16)
        for y in 0..<16 {
            for x in 0..<16 {
                s.bag.image.set(x, y, LinearRGBA.linear(red: Float(x) / 15, green: Float(y) / 15, blue: 0.5))
            }
        }
        // 2 つの領域を持つ形 — `rect` は距離関数の経路、`triangle` は平面の経路に積まれる
        s.bag.shape = s.createShape {
            s.noStroke()
            s.fill(255, 0, 0)
            s.rect(0, 0, 20, 20)
            s.fill(0, 0, 255)
            s.triangle(0, 0, 20, 0, 0, 20)
        }
        s.bag.layer = try! s.createGraphics(32, 32)
        s.bag.layer.beginDraw()
        s.bag.layer.background(0, 80, 160)
        s.bag.layer.fill(255, 200, 0)
        s.bag.layer.ellipse(16, 16, 20, 20)
        s.bag.layer.endDraw()
        // 時刻で縞を流す断片。履歴の関係でだけ時刻を読む (フレーム番号が揃うので、時刻も揃う)
        s.bag.paint = try! s.makeShader(
            """
            float4 paint(Fragment in, Values values) {
                float wave = sin(in.position.x * 0.3 - in.time * 4.0);
                return float4(in.color.rgb * (0.6 + 0.4 * wave), in.color.a);
            }
            """)
    }

    /// 2D の場面を 1 枚描く。**時刻を読まない** (``Relation/fresh`` の参照は時刻が違う)。
    @MainActor static func draw2D(_ s: Stir, _ things: [Thing]) {
        s.background(20)
        for t in things {
            s.push()
            s.translate(t.x, t.y)
            s.rotate(t.angle)
            s.fill(t.red, t.green, t.blue, t.alpha)
            s.noStroke()
            switch t.kind {
            case .rect: s.rect(-t.w / 2, -t.h / 2, t.w, t.h)
            case .ellipse: s.ellipse(0, 0, t.w, t.h)
            case .triangle: s.triangle(-t.w / 2, t.h / 2, t.w / 2, t.h / 2, 0, -t.h / 2)
            case .line:
                s.stroke(t.red, t.green, t.blue, t.alpha)
                s.strokeWeight(t.w / 10 + 0.5)
                s.line(-t.w / 2, 0, t.w / 2, 0)
            case .strokedRect:
                s.stroke(255 - t.red, 255 - t.green, 255 - t.blue, t.alpha)
                s.strokeWeight(3)
                s.rect(-t.w / 2, -t.h / 2, t.w, t.h)
            case .translucent:
                s.fill(t.red, t.green, t.blue, 90)
                s.ellipse(0, 0, t.w, t.w)
            case .text:
                s.textSize(8 + t.h / 3)
                s.text("o\(t.id % 37)", 0, 0)
            case .image:
                s.tint(t.red, t.green, t.blue, t.alpha)
                s.image(s.bag.image, -t.w / 2, -t.h / 2, t.w, t.h)
                s.noTint()
            case .shape: s.shape(s.bag.shape, -10, -10)
            case .shapeAt: s.shape(s.bag.shape, at: [Placement(x: -10, y: -10)])
            case .arc: s.arc(0, 0, t.w, t.h, 0, t.angle.truncatingRemainder(dividingBy: 6.28) + 0.5)
            case .quad: s.quad(-t.w / 2, -t.h / 2, t.w / 2, -t.h / 3, t.w / 3, t.h / 2, -t.w / 2, t.h / 3)
            case .star:
                s.beginShape()
                for k in 0..<10 {
                    let a = Float(k) / 10 * 6.2832
                    let r = k % 2 == 0 ? t.w / 2 : t.w / 4
                    s.vertex(r * cos(a), r * sin(a))
                }
                s.endShape(.close)
            case .graphics: s.image(s.bag.layer, -t.w / 2, -t.h / 2, t.w, t.h)
            }
            s.pop()
        }
    }

    /// 3D の場面を 1 枚描く。床に影を落とし、不透明・半透明・球・輪郭つきの箱を混ぜる。
    @MainActor static func draw3D(_ s: Stir, _ things: [Thing], shadows: Bool) {
        s.background(20)
        s.lights()
        if shadows { s.shadows(true) }
        s.noStroke()
        s.push()
        s.translate(100, 190, -40)
        s.fill(180)
        s.box(220, 6, 160)
        s.pop()
        for t in things {
            s.push()
            s.translate(t.x, t.y * 0.8, -20 + t.h / 3)
            s.rotateY(t.angle)
            s.rotateX(t.angle * 0.7)
            s.noStroke()
            switch t.id % 4 {
            case 0:
                s.fill(t.red, t.green, t.blue)
                s.box(t.w / 2)
            case 1:
                s.fill(t.red, t.green, t.blue, 110)
                s.box(t.w / 2)
            case 2:
                s.fill(t.red, t.green, t.blue, t.alpha)
                s.sphere(t.w / 4)
            default:
                s.stroke(255)
                s.strokeWeight(1.5)
                s.fill(t.red, t.green, t.blue)
                s.box(t.w / 3)
            }
            s.pop()
        }
    }

    /// **がらくたを 1 枚描く。** 履歴の関係の前置きで、`suspect` だけが描く。資源を作っては捨て、
    /// 文字の大きさ・粒の群・描き場所の大きさ・影・断片を毎フレーム変える。
    @MainActor static func junk(_ s: Stir) {
        var r = s.bag.random
        defer { s.bag.random = r }
        s.background(Float(r.int(255)))
        if s.bag.junkLayers.isEmpty || r.int(3) == 0 {
            s.bag.junkLayers.append(try! s.createGraphics(8 + r.int(60), 8 + r.int(60)))
        }
        if r.int(3) == 0, s.bag.junkLayers.count > 1 { s.bag.junkLayers.remove(at: r.int(s.bag.junkLayers.count)) }
        let layer = s.bag.junkLayers.last!
        layer.beginDraw()
        layer.background(Float(r.int(255)), 50, 90)
        layer.fill(255)
        layer.ellipse(4, 4, 10, 10)
        layer.endDraw()
        draw2D(s, s.bag.scenes[(s.frame - 1) % s.bag.scenes.count])
        s.image(layer, r.float(0, 200), r.float(0, 200))
        for _ in 0..<r.int(6) {
            s.textSize(Float(6 + r.int(120)))
            s.fill(255)
            s.text(String(UnicodeScalar(65 + r.int(50))!) + "あ漢\(r.int(999))", r.float(0, 200), r.float(0, 200))
        }
        if r.int(2) == 0, let cloud = try? s.makeParticles(count: 64 + r.int(3000)) { s.bag.junkClouds.append(cloud) }
        if r.int(3) == 0, !s.bag.junkClouds.isEmpty { s.bag.junkClouds.remove(at: r.int(s.bag.junkClouds.count)) }
        for cloud in s.bag.junkClouds {
            s.emit(cloud, from: .point(r.float(0, 200), r.float(0, 200)), rate: r.float(10, 900))
            s.force(cloud, .gravity(0, 30))
            s.particles(cloud)
        }
        s.push()
        s.lights()
        if r.int(2) == 0 { s.shadows(true) }
        s.translate(r.float(0, 200), r.float(0, 200), 0)
        s.fill(200, 100, 50, Float(r.int(256)))
        s.box(r.float(5, 40))
        s.pop()
        if r.int(4) == 0 {
            let count = r.int(20)
            var placements: [Placement] = []
            for _ in 0..<count { placements.append(Placement(x: r.float(0, 200), y: r.float(0, 200))) }
            s.shape(s.bag.shape, at: placements)
        }
        if r.int(4) == 0 {
            s.shader(s.bag.paint)
            s.rect(r.float(0, 200), r.float(0, 200), 30, 30)
            s.resetShader()
        }
    }

    /// **前置きの後に、どちらの経路も同じに描く場面。** `t` は前置きの後の何枚目か (0 始まり)。
    /// 1 枚目で `randomSeed` を揃え、粒の群と描き場所をその場で作る。
    @MainActor static func settled(_ s: Stir, t: Int) {
        if t == 0 {
            s.randomSeed(7)
            s.noiseSeed(3)
            s.bag.cloud = try! s.makeParticles(count: 2000)
            s.bag.layer = try! s.createGraphics(40, 40)
        }
        s.background(30)
        let f = Float(t)
        s.noStroke()
        for i in 0..<(5 + t % 7) {
            s.fill(Float(40 * i % 255), 180, 90, 200)
            s.ellipse(20 + Float(i) * 25 + f * 2, 40 + 10 * sin(f + Float(i)), 18, 18)
        }
        s.bag.layer.beginDraw()
        s.bag.layer.background(0, 0, 80)
        s.bag.layer.fill(255, 220, 0)
        s.bag.layer.ellipse(20 + f, 20, 14, 14)
        s.bag.layer.endDraw()
        s.image(s.bag.layer, 10 + f * 3, 120)
        s.fill(255)
        s.textSize(14 + Float(t % 3) * 6)
        s.text("frame \(t) ÅÉ漢字", 10, 190)
        s.emit(s.bag.cloud!, from: .point(150, 150), rate: 300, speed: 20...50, life: 1...2, size: 2...4)
        s.force(s.bag.cloud!, .gravity(0, 20), .wander(strength: 10))
        s.particles(s.bag.cloud!)
        s.shader(s.bag.paint)
        s.fill(255, 140, 0)
        s.rect(120, 10, 70, 40)
        s.resetShader()
        s.push()
        s.lights()
        s.shadows(true)
        s.translate(160, 100, 0)
        s.rotateY(f * 0.3)
        s.fill(90, 140, 230)
        s.box(26)
        s.pop()
        s.shape(s.bag.shape, at: [Placement(x: 60, y: 80)])
    }

    /// 比べる領域の外 (x ≥ 125) に足す物体の、i 番目の中心。数が 8000 を越えても領域に収める。
    static func far(_ i: Int) -> (x: Float, y: Float) {
        (140 + Float(i % 55), 10 + Float((i / 55) % 180))
    }
}
