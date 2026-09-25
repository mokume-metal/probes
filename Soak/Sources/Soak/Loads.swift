import Foundation
import mokume

/// どちらの経路で回すか。
///
/// **1 つの候補を、同じ仕事になるはずの 2 つの経路で回す。** `suspect` は疑っている口を
/// 通し、`reference` は同じ量の仕事を疑いの入らない書き方で作る。Probe・Drift が絵を
/// 比べたのに対し、ここで比べるのは**フレームを重ねたときの増え方と時間**である。
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum LoadKey: String, CaseIterable, Sendable {
    case unclosedShape, offFrameGraphics, modelSequence, pulsingText
    case polygonFill, solidStroke
}

/// 何を見る候補か。
enum Measure: Sendable {
    /// 1 枚あたりの footprint の増え方。**増え続けないこと**を見る。
    case memory
    /// 1 枚あたりの時間。**仕事の量に見合うこと**を見る。
    case time
}

/// 候補 1 件。**1 経路 = 1 本のスケッチ**で、経路ごとに別の `SketchRuntime` で回す。
///
/// 候補の多くがフレームをまたいで残るもの (閉じていない形・描き場所の溜め・読み込みの
/// 控え) を突くので、1 枚の面を分け合うと隣が疑いに混ざる。Routine と同じ作りである。
struct LoadCase {
    let key: LoadKey
    /// 窓の見出し。
    let title: String
    let measure: Measure
    let make: @MainActor (Route) -> any Sketch
}

enum Loads {
    /// 1 経路ぶんの一辺 (論理の大きさ)。
    static let side = 200
    static let frameRate = 30

    static let all: [LoadCase] = [
        LoadCase(key: .unclosedShape, title: "endShape の無い beginShape", measure: .memory) {
            UnclosedShape(route: $0)
        },
        LoadCase(key: .offFrameGraphics, title: "beginDraw を忘れた描き場所", measure: .memory) {
            OffFrameGraphics(route: $0)
        },
        LoadCase(key: .modelSequence, title: "連番の OBJ を 1 枚ずつ読む", measure: .memory) {
            ModelSequence(route: $0)
        },
        LoadCase(key: .pulsingText, title: "sin で脈打つ textSize", measure: .memory) {
            PulsingText(route: $0)
        },
        LoadCase(key: .polygonFill, title: "頂点の多い多角形の塗り", measure: .time) {
            PolygonFill(route: $0)
        },
        LoadCase(key: .solidStroke, title: "既定の線のままの sphere", measure: .time) {
            SolidStroke(route: $0)
        },
    ]

    static func named(_ key: LoadKey) -> LoadCase {
        all.first { $0.key == key }!
    }

    static var settings: SketchSettings {
        SketchSettings(width: side, height: side, frameRate: frameRate, title: "soak")
    }
}

// MARK: - メモリ

/// `beginShape()` を開いたまま、毎フレーム `vertex()` を足す。
///
/// **閉じ忘れは、黙って積み上がる。** 開いている印はフレームの境目で下りず、`vertex()` は
/// 次の `beginShape()` が来るまで点を積む (mokume の `Canvas+Vertices.swift`)。描かれる
/// ものは何も無く、警告も出ない。`setup()` で 1 度だけ開いて軌跡を足していく書き方が
/// いちばん踏みやすい。参照は毎フレーム開いて閉じる。
final class UnclosedShape: Sketch {
    static let points = 1000

    var settings = Loads.settings
    let route: Route

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() {
        if route == .suspect { beginShape() }
    }

    func draw() {
        background(12)
        noFill()
        stroke(230, 120, 60)
        if route == .reference { beginShape() }
        let phase = Float(frameCount) * 0.02
        for i in 0..<Self.points {
            let a = Float(i) / Float(Self.points) * 2 * .pi
            vertex(100 + 80 * cos(3 * a + phase), 100 + 80 * sin(2 * a))
        }
        if route == .reference { endShape() }
    }
}

/// 描き場所に `beginDraw()` を付けずに図形を置く。
///
/// **置いた図形が捨てられずに溜まる。** 変換と描き方の口は「フレームの外」を見て断るが、
/// 図形の口は見ずに溜め場へ積む。捨てるのは `background()` と `endDraw()` だけなので、
/// どちらも呼ばない描き場所では溜まり続ける。何も描かれず、警告も出ない。参照は
/// `beginDraw()` / `endDraw()` で挟む。
final class OffFrameGraphics: Sketch {
    static let circles = 1000

    var settings = Loads.settings
    let route: Route
    private var layer: Canvas!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() {
        layer = try! createGraphics(Loads.side, Loads.side)
    }

    func draw() {
        background(12)
        if route == .reference {
            layer.beginDraw()
            layer.background(.transparent)
        }
        layer.noStroke()
        layer.fill(90, 160, 240)
        for _ in 0..<Self.circles {
            layer.circle(random(Float(Loads.side)), random(Float(Loads.side)), 6)
        }
        if route == .reference { layer.endDraw() }
        image(layer, 0, 0)
    }
}

/// 連番の OBJ (動きを書き出した列) を、毎フレーム 1 枚ずつ読んで置く。
///
/// **読み込みの控えに上限が無い。** `loadModel` はパスを鍵に読んだモデルを控えるが、画像の
/// 控え (64 MiB) や立体の形の控え (64 個) と違って上限も追い出しも無い。列を 1 巡すると、
/// 全部のモデルが控えに残る。参照は同じ 1 枚を読み続ける (控えに当たる)。
final class ModelSequence: Sketch {
    /// 列の長さ。窓では 1 巡した後は控えに当たって増えなくなる。
    ///
    /// **列全体は、控えに上限が入ったときの予算より大きくしておく。** mokume#1593 は量で
    /// 64 MiB の予算を持たせると決めた。列が予算に収まると、直っても 1 巡の間は増え続けるので
    /// `withKnownIssue` が「起きなかった」で知らせない。1 枚約 1 MB × 160 枚で、予算の約 2.5 倍。
    static let length = 160
    /// 1 枚の格子の分割数。頂点は (grid + 1)² = 3721、三角形は 2 × grid² = 7200
    /// (1 枚の控えは 7200 × 3 点 × 48 B ≈ 1.04 MB の見込み)。
    static let grid = 60

    /// 列を書いた場所。**名前は中身 (列の長さと格子) だけで決め、既にあるファイルは書き直さない。**
    ///
    /// プロセスごとに別の場所へ書くと、`swift test` のたびに 12 MB が一時領域に残る。
    /// 中身は決まった式から作るので、同じ名前なら同じ中身である。
    static let files: [String] = {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("soak-models-\(length)x\(grid)")
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (0..<length).map { index in
            let url = directory.appendingPathComponent(String(format: "wave-%03d.obj", index))
            if !FileManager.default.fileExists(atPath: url.path) {
                try! obj(phase: Float(index) / Float(length) * 2 * .pi)
                    .write(to: url, atomically: true, encoding: .utf8)
            }
            return url.path
        }
    }()

    /// 波打つ格子 1 枚。
    static func obj(phase: Float) -> String {
        var lines: [String] = []
        let n = grid
        for i in 0...n {
            for j in 0...n {
                let (u, v) = (Float(i) / Float(n), Float(j) / Float(n))
                let z = 0.1 * sin(6 * u + phase) * cos(6 * v + phase)
                lines.append("v \(u - 0.5) \(v - 0.5) \(z)")
            }
        }
        for i in 0..<n {
            for j in 0..<n {
                let a = i * (n + 1) + j + 1
                lines.append("f \(a) \(a + 1) \(a + n + 2)")
                lines.append("f \(a) \(a + n + 2) \(a + n + 1)")
            }
        }
        return lines.joined(separator: "\n")
    }

    var settings = Loads.settings
    let route: Route

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        background(12)
        let index = route == .suspect ? (frameCount - 1) % Self.length : 0
        guard let wave = try? loadModel(Self.files[index]) else { return }
        lights()
        noStroke()
        fill(200, 170, 120)
        translate(100, 100)
        rotateX(1)
        model(wave)
    }
}

/// `sin` で脈打つ大きさの字を描く。
///
/// **書体の控えが大きさごとに増える** ([mokume#1431])。`textSize` に毎フレーム違う
/// 浮動小数を渡すと、大きさごとに書体とその字の引き当ての控えが増える。脈打つ字は
/// 作品がふつうに書く形である。参照は大きさを固定し、同じ脈を `scale` で付ける。
///
/// [mokume#1431]: https://github.com/mokume-metal/mokume/issues/1431
final class PulsingText: Sketch {
    static let words = "永和九年歳在癸丑暮春之初"

    var settings = Loads.settings
    let route: Route

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        background(12)
        let pulse = 1 + 0.3 * sin(Float(frameCount) * 0.05)
        fill(240)
        textAlign(.center, .center)
        translate(100, 100)
        switch route {
        case .suspect:
            textSize(14 * pulse)
        case .reference:
            textSize(14)
            scale(pulse, pulse)
        }
        text(Self.words, 0, 0)
    }
}

// MARK: - 時間

/// 頂点の多い多角形を塗る。
///
/// **三角形分割が頂点数の二乗で重くなる。** 耳を探すたびに頭から走査し、耳の判定のたびに
/// 全頂点を見る (mokume の `Triangulation.swift`)。参照は同じ形を中心からの扇
/// (`.triangleFan`) で置く — 形が中心から見て星形なので、分割しなくても同じ絵になる。
final class PolygonFill: Sketch {
    var settings = Loads.settings
    let route: Route
    let vertices: Int

    init(route: Route, vertices: Int = 1000) {
        self.route = route
        self.vertices = vertices
    }
    convenience init() { self.init(route: .reference) }

    func point(_ i: Int) -> SIMD2<Float> {
        let a = Float(i) / Float(vertices) * 2 * .pi
        let r = 80 + 10 * sin(7 * a + Float(frameCount) * 0.05)
        return SIMD2(100 + r * cos(a), 100 + r * sin(a))
    }

    func draw() {
        background(12)
        noStroke()
        fill(120, 200, 140)
        switch route {
        case .suspect:
            beginShape()
            for i in 0..<vertices { vertex(point(i).x, point(i).y) }
            endShape(.close)
        case .reference:
            beginShape(.triangleFan)
            vertex(100, 100)
            for i in 0...vertices { vertex(point(i % vertices).x, point(i % vertices).y) }
            endShape()
        }
    }
}

/// 組み込みの立体を、既定の線 (`stroke` が効いたまま) で並べる。
///
/// **立体の線が、立体の数ぶん毎フレーム CPU で組み直される。** 稜線 1 本ごとに視線へ
/// 向けた帯を組み、点ごとに角を置く (既定の `.miter` では正方形、`.round` では円板 16 枚。
/// mokume の `Canvas+Solid.swift` の `strokeSolidEdges`)。既定で線が効いているので、`noStroke()` を書かない作品はみな
/// 通る。参照は `noStroke()` にした同じ置き方。
final class SolidStroke: Sketch {
    var settings = Loads.settings
    let route: Route
    let count: Int

    init(route: Route, count: Int = 100) {
        self.route = route
        self.count = count
    }
    convenience init() { self.init(route: .reference) }

    func draw() {
        background(12)
        lights()
        fill(200, 120, 90)
        stroke(250)
        if route == .reference { noStroke() }
        let columns = Int(Float(count).squareRoot().rounded(.up))
        let step = Float(Loads.side) / Float(columns)
        for i in 0..<count {
            push()
            translate(step * (Float(i % columns) + 0.5), step * (Float(i / columns) + 0.5), 0)
            rotateY(Float(frameCount) * 0.03)
            sphere(step * 0.35)
            pop()
        }
    }
}

// MARK: - テストだけ

/// 何もしないに近いスケッチ。`headlessAdvance` の舞台で、回し方だけを変えて比べる。
final class Idle: Sketch {
    var settings = Loads.settings

    func draw() {
        background(12)
        fill(240)
        rect(20, 20, 40, 40)
    }
}
