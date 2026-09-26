import Testing
import mokume

@testable import Lattice

/// **条件を 1 点から動かして見つけた破れ。** どれも 160²・細かさ 1・30 fps では出ない。
///
/// 破れは `withKnownIssue("mokume#NNNN: …")` で包み、同じ検査の中で**破れない条件** (対照) を
/// 包まずに押さえる。直ると包みが「起きなかった」で赤くなる。
@MainActor
@Suite struct BreachTests {
    // MARK: - 細かさ

    /// 太さ 1 の輪郭の総光量。細かさ 1 なら置く位置によらず一定。
    func outlineLight(_ path: Cases.OutlinePath, y: Float, density: Float) throws -> Float {
        try run(Cases.thinOutline(path, y: y, density: density), name: "outline-\(path)-\(y)-\(density)").light
    }

    @Test("細かさ 0.5 でも、太さ 1 の輪郭は置く位置によらずその太さぶんの濃さで出る", arguments: Cases.OutlinePath.allCases)
    func thinOutline(path: Cases.OutlinePath) throws {
        let reference = try outlineLight(path, y: 10, density: 1)
        #expect(reference > 50)
        #expect(abs(try outlineLight(path, y: 11, density: 1) - reference) < 1, "細かさ 1 で位置により揺れる")
        let check = {
            for y: Float in [10, 11] {
                let light = try outlineLight(path, y: y, density: 0.5)
                // 拡大段は総光量を少し増やす (upscaleRange) ので、許容は ±20%
                #expect(abs(light - reference) < reference * 0.2, "上辺 y = \(y) で総光量 \(light) (細かさ 1 は \(reference))")
            }
        }
        if path.triangles {
            try withKnownIssue("mokume#1637: 三角形の経路の細い線が、細かさ 0.5 で位置の偶奇により消える・倍になる") { try check() }
        } else {
            try check()
        }
    }

    @Test("細かさ < 1 の拡大を通しても、乗算済みの決まり (α ≤ 1・色 ≤ α) を保つ")
    func upscaleKeepsPremultiplied() throws {
        func broken(_ density: Float) throws -> (alpha: Int, color: Int) {
            let p = try run(Cases.edges(density: density, clear: true), name: "edges-\(density)")
            let alpha = p.values.count { $0.w > 1.001 }
            let color = p.values.count { max($0.x, $0.y, $0.z) > $0.w + 0.001 }
            return (alpha, color)
        }
        let full = try broken(1)
        #expect(full.alpha == 0 && full.color == 0, "細かさ 1 で \(full)")
        try withKnownIssue("mokume#1638: 拡大段 (Catmull-Rom) の行き過ぎが α > 1・色 > α になる") {
            for density: Float in [0.5, 0.75] {
                let low = try broken(density)
                #expect(low.alpha == 0, "細かさ \(density): α > 1 が \(low.alpha) 画素")
                #expect(low.color == 0, "細かさ \(density): 色 > α が \(low.color) 画素")
            }
        }
    }

    @Test("利用者の効果の in.position は出す画素で、細かさを変えても模様の大きさが変わらない")
    func effectPositionIsOutputPixels() throws {
        let full = try run(Cases.mosaic(density: 1), name: "mosaic-1")
        #expect(full.lit > 1000)
        let low = try run(Cases.mosaic(density: 0.5), name: "mosaic-0.5")
        // 升の縁は拡大で滲むので、50% で白黒にして比べる
        let mismatch = zip(full.values, low.values).count { ($0.x > 0.5) != ($1.x > 0.5) }
        withKnownIssue("mokume#1639: 利用者の効果の Pixel.position / size が描く画素で、細かさ 0.5 で模様が倍になる") {
            #expect(mismatch == 0, "\(mismatch) 画素で白黒が違う")
        }
    }

    // MARK: - 切り抜き

    @Test("clip は矩形の外を描かない (小数の座標・細かさ 0.5)", arguments: [
        (Float(20), Float(30), Float(1), false), (20, 30, 0.5, false),
        (10.9, 10, 1, true), (51, 20, 0.5, true),
    ])
    func clipStaysInside(x: Float, width w: Float, density: Float, broken: Bool) throws {
        let clip = try run(Cases.clipped(x: x, width: w, density: density), name: "clip-\(x)-\(w)-\(density)")
        let rect = try run(Cases.filled(x: x, width: w, density: density), name: "rect-\(x)-\(w)-\(density)")
        #expect(rect.lit > 100)
        // 同じ矩形を塗った絵と、面積 (1 行あたり) と重心で比べる
        let area = (clip.light - rect.light) / Float(clip.height)
        let shift = clip.centroid.x - rect.centroid.x
        let check = {
            #expect(abs(area) < 0.25, "1 行あたり \(area) 画素ぶん多い")
            #expect(abs(shift) < 0.25, "重心が \(shift) 画素ずれた")
        }
        if broken {
            withKnownIssue("mokume#1641: clip の小数を切り捨て / 外向きに丸め、矩形の外を最大 1 画素描く") { check() }
        } else {
            check()
        }
    }

    // MARK: - fps

    /// `Float(1 / fps)` が 1 / fps より小さい fps。1 秒ぶんの刻みを足しても 1 に届かない。
    nonisolated static func stepFallsShort(_ fps: Int) -> Bool {
        Double(Float(1 / Double(fps))) * Double(fps) < 1
    }

    @Test("毎秒 fps 個の粒は、fps 枚回すと fps 個出ている", arguments: [24, 25, 30, 50, 60, 100, 120])
    func emitPerSecond(fps: Int) throws {
        let row = try run(Cases.emitRow(fps: fps), frames: fps, name: "emit-\(fps)")
        var count = 0
        var inside = false
        for x in 0..<row.width {
            let on = row[x, row.height / 2]!.x > 0.3
            if on && !inside { count += 1 }
            inside = on
        }
        withKnownIssue("mokume#1640: 刻みを Float(1/fps) で渡すので、fps 25・50・100 などで 1 個少ない") {
            #expect(count == fps, "\(fps) 枚で \(count) 個")
        } when: {
            Self.stepFallsShort(fps)
        }
    }

    @Test("frameRate が 0・負のランタイムは組み立てで断る (pixelDensity と同じく)", arguments: [0, -30])
    func badFrameRate(fps: Int) throws {
        // 対照: 範囲外の pixelDensity は組み立てで断る
        #expect(throws: RenderFailure.self) {
            _ = try SketchRuntime(sketch: Scene(SketchSettings(width: 10, height: 10, pixelDensity: 2)) { _ in }, gpu: gpu)
        }
        withKnownIssue("mokume#1642: frameRate 0・負を黙って 1 fps にする") {
            #expect(throws: (any Error).self) {
                let runtime = try SketchRuntime(
                    sketch: Scene(SketchSettings(width: 10, height: 10, frameRate: fps)) { _ in }, gpu: gpu)
                runtime.closePlugins()
            }
        }
    }
}
