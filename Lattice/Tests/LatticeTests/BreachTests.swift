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
        // v0.12.0 では、三角形の経路の細い線が置く位置の偶奇で消えたり倍になったりした
        // (mokume#1637、v0.16.2 で直った)。基準は細かさ 1 の実測ではなく、面積 (周囲長 × 太さ)
        let expected = path.area
        let reference = try outlineLight(path, y: 10, density: 1)
        #expect(abs(reference - expected) < expected * 0.2, "細かさ 1 の総光量 \(reference) (面積 \(expected))")
        #expect(abs(try outlineLight(path, y: 11, density: 1) - reference) < 1, "細かさ 1 で位置により揺れる")
        var lights: [Float] = []
        for y: Float in [10, 11] {
            let light = try outlineLight(path, y: y, density: 0.5)
            lights.append(light)
            // 拡大段は総光量を少し増やす (upscaleRange) ので、許容は ±20%
            #expect(
                abs(light - expected) < expected * 0.2,
                "mokume#1637 で直った: 上辺 y = \(y) で総光量 \(light) (面積 \(expected))")
        }
        #expect(
            abs(lights[0] - lights[1]) < expected * 0.02,
            "mokume#1637 で直った: 上辺 y = 10 と 11 で総光量が違う \(lights)")
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
        // v0.12.0 では拡大段 (Catmull-Rom) の行き過ぎが α > 1・色 > α になった (mokume#1638、v0.15.0 で直った)
        for density: Float in [0.5, 0.75] {
            let low = try broken(density)
            #expect(low.alpha == 0, "mokume#1638 で直った: 細かさ \(density): α > 1 が \(low.alpha) 画素")
            #expect(low.color == 0, "mokume#1638 で直った: 細かさ \(density): 色 > α が \(low.color) 画素")
        }
    }

    @Test("利用者の効果の in.position は出す画素で、細かさを変えても模様の大きさが変わらない")
    func effectPositionIsOutputPixels() throws {
        let full = try run(Cases.mosaic(density: 1), name: "mosaic-1")
        #expect(full.lit > 1000)
        let low = try run(Cases.mosaic(density: 0.5), name: "mosaic-0.5")
        // 升の縁は拡大で滲むので、50% で白黒にして比べる
        let mismatch = zip(full.values, low.values).count { ($0.x > 0.5) != ($1.x > 0.5) }
        // v0.12.0 では Pixel.position / size が描く画素で届き、細かさ 0.5 で模様が倍になった (mokume#1639、v0.16.2 で直った)
        #expect(mismatch == 0, "mokume#1639 で直った: \(mismatch) 画素で白黒が違う")
    }

    // MARK: - 切り抜き

    /// 切り抜きは画素の中心が矩形の内 (縁の上を含む) にある画素を通す (mokume#1641、v0.16.2 で直った)。
    /// 細かさ 1 未満では**描く画素の格子**で同じ規則を使うので、縁は描く画素の半分までずれうる。
    /// mokume の `clip` の説明の例 — 細かさ 0.5 の `clip(51, 0, 20, 40)` は、奇数の縁が描く画素の
    /// 中心に乗って外へ倒れ、出す画素で 50…72 を通す — は、同じ矩形の `rect` より 1 行あたり 2 画素多い。
    @Test("clip は、画素の中心が矩形の内にある画素を通す (小数の座標・細かさ 0.5)", arguments: [
        (Float(20), Float(30), Float(1), Float(0)), (20, 30, 0.5, 0),
        (10.9, 10, 1, 0), (51, 20, 0.5, 2),
    ])
    func clipStaysInside(x: Float, width w: Float, density: Float, extra: Float) throws {
        let clip = try run(Cases.clipped(x: x, width: w, density: density), name: "clip-\(x)-\(w)-\(density)")
        let rect = try run(Cases.filled(x: x, width: w, density: density), name: "rect-\(x)-\(w)-\(density)")
        #expect(rect.lit > 100)
        // 同じ矩形を塗った絵と、面積 (1 行あたり) と重心で比べる
        let area = (clip.light - rect.light) / Float(clip.height)
        let shift = clip.centroid.x - rect.centroid.x
        #expect(abs(area - extra) < 0.25, "mokume#1641 で直った: 1 行あたり \(area) 画素ぶん多い (期待 \(extra))")
        #expect(abs(shift) < 0.25, "mokume#1641 で直った: 重心が \(shift) 画素ずれた")
    }

    // MARK: - fps

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
        // v0.12.0 では fps 25・50・100 で 1 個少なかった (刻みを Float(1/fps) で渡していた)
        #expect(count == fps, "mokume#1640 (v0.14.0 で直った): \(fps) 枚で \(count) 個")
    }

    @Test("frameRate が 0・負のランタイムは組み立てで断る (pixelDensity と同じく)", arguments: [0, -30])
    func badFrameRate(fps: Int) throws {
        // 対照: 範囲外の pixelDensity は組み立てで断る
        #expect(throws: RenderFailure.self) {
            _ = try SketchRuntime(sketch: Scene(SketchSettings(width: 10, height: 10, pixelDensity: 2)) { _ in }, gpu: gpu)
        }
        // v0.12.0 では黙って 1 fps で走った (mokume#1642、v0.14.0 で直った)
        #expect(throws: (any Error).self, "mokume#1642 (v0.14.0 で直った): frameRate \(fps) を断らない") {
            let runtime = try SketchRuntime(
                sketch: Scene(SketchSettings(width: 10, height: 10, frameRate: fps)) { _ in }, gpu: gpu)
            runtime.closePlugins()
        }
    }
}
