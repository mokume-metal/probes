import Foundation
import Testing
import mokume

@testable import Drift

/// 候補ごとの検査。**期待値は「正しい振る舞い」のほうに置く。**
///
/// 各検査は、疑いを確かめる前に**参照の側が動いていること**を押さえる (時刻が進む・
/// 粒が出る・効果が効く)。参照まで止まっていると、左右が一致しても何も言えないため。
@MainActor
@Suite struct DriftTests {
    /// 表示の値で 0…1 の橙・青・桃が、線形の値ではどこに来るかの大まかな判定。
    static func isOrange(_ c: LinearRGBA) -> Bool { c.red > 0.4 && c.blue < 0.2 }
    static func isBlue(_ c: LinearRGBA) -> Bool { c.blue > 0.4 && c.red < 0.2 }
    static func isPink(_ c: LinearRGBA) -> Bool { c.red > 0.4 && c.green < 0.2 }

    // MARK: - 時刻

    @Test("描き場所の断片が読む in.time は、本体の面と同じだけ進む")
    func graphicsTime() throws {
        // frameRate 30 の 16 枚目は 0.5 秒 — 断片の赤が最も強い
        let a = try run(.graphicsTime, .suspect, frames: 16, reading: [1, 16])
        let b = try run(.graphicsTime, .reference, frames: 16, reading: [1, 16])
        // 参照は脈打っている
        #expect(b[16]![80, 80].red > b[1]![80, 80].red + 0.3)
        // 1 枚目 (0 秒) は左右で同じ
        #expect(abs(a[1]![80, 80].red - b[1]![80, 80].red) < 0.02)
        withKnownIssue("mokume#1467: 時刻を渡すのが本体の面だけで、描き場所は time = 0 のまま") {
            #expect(
                abs(a[16]![80, 80].red - b[16]![80, 80].red) < 0.02,
                "0.5 秒の赤: 描き場所 \(a[16]![80, 80].red)、本体 \(b[16]![80, 80].red)")
        }
    }

    // MARK: - 粒

    @Test("1 つの粒へ 2 か所から出しても、どちらの噴き口からも頼んだ数が出る")
    func sharedEmitter() throws {
        let a = try run(.sharedEmitter, .suspect, frames: 60)[60]!
        let b = try run(.sharedEmitter, .reference, frames: 60)[60]!
        let (left, right) = (0..<80, 80..<160)
        let reference = (b.count(columns: left) { c, _, _ in Self.isOrange(c) }, b.count(columns: right) { c, _, _ in Self.isBlue(c) })
        let suspect = (a.count(columns: left) { c, _, _ in Self.isOrange(c) }, a.count(columns: right) { c, _, _ in Self.isBlue(c) })
        // 参照は両方から出ている
        #expect(reference.0 > 50 && reference.1 > 50, "参照の橙 \(reference.0)・青 \(reference.1)")
        withKnownIssue("mokume#1468: 端数の繰り越しが Particles に 1 つしか無く、噴き口どうしで取り合う") {
            #expect(suspect.0 > reference.0 / 2, "橙の画素: 1 つの粒 \(suspect.0)、別の粒 \(reference.0)")
            #expect(suspect.1 < reference.1 * 3 / 2, "青の画素: 1 つの粒 \(suspect.1)、別の粒 \(reference.1)")
        }
    }

    @Test("30 fps の drag(70) の粒は、出た位置のすぐそばで止まる")
    func dragLowRate() throws {
        let frames = Set(1...60)
        let a = try run(.dragLowRate, .suspect, frames: 60, reading: frames)
        let b = try run(.dragLowRate, .reference, frames: 60, reading: frames)
        let source = DragLowRate.source(.zero)
        func far(_ p: Picture) -> Int {
            p.count { c, x, y in
                let d = SIMD2(Float(x), Float(y)) - source
                return Self.isPink(c) && (d * d).sum() > 16 * 16
            }
        }
        func near(_ p: Picture) -> Int { p.count { c, _, _ in Self.isPink(c) } - far(p) }
        // 参照: 粒は出ていて、噴き口から離れない
        #expect(near(b[60]!) > 20)
        #expect(frames.map { far(b[$0]!) }.max() == 0)
        let farthest = frames.map { far(a[$0]!) }.max()!
        #expect(near(a[60]!) > 20, "噴き口のそばの画素 \(near(a[60]!))")
        withKnownIssue("mokume#1471: 減速を陽的に積分しており、a·Δt > 2 で速さが毎フレーム増える") {
            #expect(farthest == 0, "噴き口から 16 px より外の画素が、多いフレームで \(farthest)")
        }
    }

    // MARK: - フレームをまたぐ描き方

    @Test("残像の上にかけた効果は、次のフレームへ焼き込まれない (描き場所)")
    func effectsCarry() throws {
        let a = try run(.effectsCarry, .suspect, frames: 12, reading: [1, 12])
        let b = try run(.effectsCarry, .reference, frames: 12, reading: [1, 12])
        // 参照: 効果は効いていて (隅が下地より暗い)、フレームによらず同じ
        #expect(b[12]![3, 3].red < b[12]![80, 3].red - 0.05)
        #expect(abs(b[12]![3, 3].red - b[1]![3, 3].red) < 0.01)
        #expect(abs(a[1]![3, 3].red - b[1]![3, 3].red) < 0.01)
        withKnownIssue("mokume#1469: 最後の段が描画先へ直接書き、次のフレームがその絵を読み込む") {
            #expect(
                abs(a[12]![3, 3].red - b[12]![3, 3].red) < 0.02,
                "12 枚目の隅: 残像 \(a[12]![3, 3].red)、描き直し \(b[12]![3, 3].red)")
        }
    }

    @Test("残像の上にかけた効果は、次のフレームへ焼き込まれない (本体の面)")
    func effectsCarryOnMain() throws {
        func corner(trail: Bool) throws -> [Int: Picture] {
            try run(
                Scene { s in
                    if !trail || s.frameCount == 1 { s.background(235) }
                    s.effects([.vignette(amount: 0.6)])
                }, frames: 12, reading: [1, 12], dump: "effectsCarryOnMain-\(trail)")
        }
        let (a, b) = (try corner(trail: true), try corner(trail: false))
        #expect(b[12]![3, 3].red < b[12]![80, 80].red - 0.05)
        withKnownIssue("mokume#1469: 最後の段が描画先へ直接書き、次のフレームがその絵を読み込む") {
            #expect(
                abs(a[12]![3, 3].red - b[12]![3, 3].red) < 0.02,
                "12 枚目の隅: 残像 \(a[12]![3, 3].red)、描き直し \(b[12]![3, 3].red)")
        }
    }

    @Test("1 度だけ渡した numbers は、shader と同じく次のフレームにも残る")
    func numbersOnce() throws {
        // 16 枚目 (0.5 秒) は並びの値が 1
        let a = try run(.numbersOnce, .suspect, frames: 16, reading: [1, 2, 16])
        let b = try run(.numbersOnce, .reference, frames: 16, reading: [1, 2, 16])
        #expect(b[16]![80, 80].red > b[1]![80, 80].red + 0.2)
        #expect(abs(a[1]![80, 80].red - b[1]![80, 80].red) < 0.02)
        withKnownIssue("mokume#1470: 並びだけがフレームの頭で外れ、寿命も名乗られていない") {
            #expect(
                abs(a[16]![80, 80].red - b[16]![80, 80].red) < 0.02,
                "16 枚目の赤: 1 度だけ \(a[16]![80, 80].red)、毎フレーム \(b[16]![80, 80].red)")
        }
    }

    // MARK: - 止まっている間

    @Test("止まっている間のコールバックで置いた図形には、前のフレームの変換が効かない")
    func stoppedCallback() throws {
        /// `draw()` は `translate(50, 0)` で終わって止まる。押すと赤い 10 px 四方を置く —
        /// 疑う口はコールバックの中で、参照は次に描く `draw()` の頭で。
        final class Stopped: Sketch {
            var settings = SketchSettings(width: 160, height: 40, title: "stopped")
            let inCallback: Bool
            var pressed = false
            init(inCallback: Bool) { self.inCallback = inCallback }
            convenience init() { self.init(inCallback: false) }
            func draw() {
                if frameCount == 1 { background(0) }
                if pressed && !inCallback { square() }
                translate(50, 0)
                noLoop()
            }
            func mousePressed() {
                pressed = true
                if inCallback { square() }
                redraw()
            }
            func square() {
                noStroke()
                fill(255, 0, 0)
                rect(0, 0, 10, 10)
            }
        }
        func press(_ sketch: Stopped) throws -> Picture {
            try run(sketch, frames: 2, dump: "stoppedCallback-\(sketch.inCallback)") { frame, runtime in
                if frame == 2 {
                    runtime.input.enqueue(.mouseDown(x: 100, y: 30, button: 0))
                    runtime.input.enqueue(.mouseUp(x: 100, y: 30, button: 0))
                }
            }[2]!
        }
        let (a, b) = (try press(Stopped(inCallback: true)), try press(Stopped(inCallback: false)))
        // 参照: draw() の頭で置いた四角は、変換の無い (5, 5) に出る
        #expect(b[5, 5].red > 0.5 && b[55, 5].red < 0.05)
        withKnownIssue("mokume#1472: 変換を戻すのがフレームの頭だけで、フレームの外の図形に前の変換が効く") {
            #expect(a[5, 5].red > 0.5, "(5, 5) の赤 \(a[5, 5].red)")
            #expect(a[55, 5].red < 0.05, "(55, 5) の赤 \(a[55, 5].red)")
        }
    }
}

/// その場で書いた `draw()` だけのスケッチ。
final class Scene: Sketch {
    var settings = SketchSettings(
        width: Motions.side, height: Motions.side, frameRate: Motions.frameRate, title: "scene")
    let body: (Scene) -> Void
    init(_ body: @escaping (Scene) -> Void) { self.body = body }
    /// `Sketch` が求めるだけで、検査からは呼ばない。
    convenience init() { self.init { _ in } }
    func draw() { body(self) }
}

/// 窓と同じ並びを、窓を出さずに 1 枚ずつ書き出す。**`DRIFT_FRAMES` を渡したときだけ走る。**
///
/// PR に載せる動きの証跡 (アニメーション WebP) の素材で、検査ではない。窓は実時間で
/// 回るが、ここはフレーム番号の時計なので、書き出した列は同じ機械なら毎回同じになる。
@MainActor
@Test(
    "窓と同じ並びを 1 枚ずつ書き出す",
    .enabled(if: ProcessInfo.processInfo.environment["DRIFT_FRAMES"] != nil))
func writeFrames() throws {
    let directory = URL(fileURLWithPath: ProcessInfo.processInfo.environment["DRIFT_FRAMES"]!)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let runtime = try SketchRuntime(sketch: Drift(), gpu: gpu)
    defer { runtime.closePlugins() }
    for frame in 1...(Motions.frameRate * 4) {
        try runtime.advance()
        let name = String(format: "frame.%04d.png", frame)
        try runtime.target.writePNG(to: directory.appendingPathComponent(name))
    }
}
