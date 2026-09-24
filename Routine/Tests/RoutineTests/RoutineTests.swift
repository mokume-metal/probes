import Foundation
import simd
import Testing
import mokume

@testable import Routine

/// 候補ごとの検査。**期待値は「正しい振る舞い」のほうに置く。**
///
/// 各検査は、疑いを確かめる前に**参照の側が動いていること**を押さえる (色が出る・
/// 動く・薄まる)。参照まで止まっていると、左右が一致しても何も言えないため。
@MainActor
@Suite struct RoutineTests {
    static func isBright(_ c: LinearRGBA) -> Bool { max(c.red, c.green, c.blue) > 0.3 }

    // MARK: - フレームの境目で描き方が残るか

    @Test("setup で 1 度決めた描き方は、次のフレームにも残る")
    func styleCarry() throws {
        let a = try run(.styleCarry, .suspect, frames: 3, reading: [1, 3])
        let b = try run(.styleCarry, .reference, frames: 3, reading: [1, 3])
        // 参照: rect の中は fill の橙、縁は stroke の緑、image は tint の青
        #expect(b[3]![40, 40].red > 0.5 && b[3]![40, 40].blue < 0.1)
        #expect(b[3]![40, 19].green > 0.4 && b[3]![40, 19].red < 0.2)
        #expect(b[3]![40, 120].blue > 0.4 && b[3]![40, 120].red < 0.1)
        for frame in [1, 3] {
            for region in StyleCarry.regions {
                let n = differing(a[frame]!, b[frame]!, columns: region.x, rows: region.y)
                #expect(n < 8, "\(frame) 枚目の \(region.name): \(n) 画素が違う")
            }
        }
    }

    @Test("draw() の中で戻さなかった変換は、次のフレームに持ち越さない")
    func transformReset() throws {
        let a = try run(.transformReset, .suspect, frames: 10, reading: [1, 10])
        let b = try run(.transformReset, .reference, frames: 10, reading: [1, 10])
        #expect(b[10]!.count { c, _, _ in Self.isBright(c) } > 1000)
        #expect(differing(a[10]!, b[10]!) == 0, "10 枚目: \(differing(a[10]!, b[10]!)) 画素が違う")
        #expect(differing(a[10]!, a[1]!) == 0)
    }

    // MARK: - 残像

    func trail(_ key: HabitKey) throws {
        let frames: Set<Int> = [2, 10, 30, 90]
        let a = try run(key, .suspect, frames: 90, reading: frames)
        let b = try run(key, .reference, frames: 90, reading: frames)
        for frame in frames.sorted() {
            let want = TrailFade.expected(frame: frame)
            let (got, ref) = (a[frame]![80, 80].red, b[frame]![80, 80].red)
            // 参照は解のとおりに薄まっている
            #expect(abs(ref - want) < 0.01 + want * 0.05, "\(frame) 枚目の参照 \(ref)、解 \(want)")
            #expect(
                abs(got - want) < 0.01 + want * 0.05,
                "\(frame) 枚目の白: 重ねた \(got)、解 \(want) (参照 \(ref))")
        }
        // 90 枚目 (解は 0.0007) で残像が消えきっている
        #expect(a[90]![80, 80].red < 0.005, "90 枚目の残像 \(a[90]![80, 80].red)")
        // 四角の外は黒のまま
        #expect(a[90]![10, 10].red < 0.005)
    }

    @Test("fill(0, a) の矩形を重ねた残像は、(1 − α)^n で薄まって消えきる")
    func trailFade() throws { try trail(.trailFade) }

    /// **p5 の残像の書き方は、mokume では残像にならない。** `background` は「このフレームを
    /// ここから描き直す」塗り直しで、不透明度つきで呼ぶと前の絵を捨て、面を半透明の色で
    /// 置き換える。原典 (Processing は不透明度を無視、p5 は重ねる) のどちらとも違い、
    /// 説明は 2 つ目を「不透明度」とだけ書いている。いまの振る舞いを押さえる。
    @Test("background(0, a) は重ねずに、面を半透明の黒で置き換える (いまの振る舞い)")
    func trailBackground() throws {
        let frames: Set<Int> = [1, 2, 30]
        let a = try run(.trailBackground, .suspect, frames: 30, reading: frames)
        let b = try run(.trailBackground, .reference, frames: 30, reading: frames)
        #expect(abs(b[2]![80, 80].red - TrailFade.expected(frame: 2)) < 0.01)
        #expect(a[1]![80, 80].red > 0.99)
        withKnownIssue("mokume#1550: background の不透明度が「重ねる」ではなく「置き換える」ことが説明に無い") {
            #expect(
                abs(a[2]![80, 80].red - b[2]![80, 80].red) < 0.02,
                "2 枚目の白: background(0, a) \(a[2]![80, 80].red)、重ねた解 \(b[2]![80, 80].red)")
        }
        // いまの振る舞い: 2 枚目から面全体が不透明度 a の黒になり、白い四角は残らない
        for frame in [2, 30] {
            for (x, y) in [(80, 80), (10, 10)] {
                let c = a[frame]![x, y]
                #expect(c.red == 0 && abs(c.alpha - TrailFade.alpha / 255) < 0.002, "\(frame) 枚目の (\(x), \(y)) \(c)")
            }
        }
    }

    // MARK: - 画素

    @Test("描いた直後の get / pixels は同じフレームの色を返し、書いた画素の上に後の図形が重なる")
    func midFrameRead() throws {
        let frames: Set<Int> = [1, 5, 20]
        let sketch = MidFrameRead(route: .suspect)
        var reads: [Int: (LinearRGBA, LinearRGBA)] = [:]
        let a = try run(sketch, frames: 20, reading: frames, dump: "midFrameRead-suspect") { frame, _ in
            if frame > 1 { reads[frame - 1] = (sketch.readByGet, sketch.readByPixels) }
        }
        reads[20] = (sketch.readByGet, sketch.readByPixels)
        let b = try run(.midFrameRead, .reference, frames: 20, reading: frames)
        // 参照: 赤い四角は動いている
        #expect(b[5]![Int(MidFrameRead.x(5)) + 1, 35].red > 0.5)
        #expect(b[20]![Int(MidFrameRead.x(5)) + 1, 35].red < 0.05)
        for frame in frames.sorted() {
            let (byGet, byPixels) = reads[frame]!
            #expect(gap(byGet, MidFrameRead.red) < 0.02, "\(frame) 枚目の get: \(byGet)")
            #expect(gap(byPixels, MidFrameRead.red) < 0.02, "\(frame) 枚目の pixels: \(byPixels)")
            let n = differing(a[frame]!, b[frame]!)
            #expect(n == 0, "\(frame) 枚目: \(n) 画素が違う")
        }
    }

    // MARK: - 重ねる

    @Test("透明に塗り直す描き場所に描いた半透明の円は、本体へ直に描いたのと同じに出る")
    func layerComposite() throws {
        let frames: Set<Int> = [1, 10, 30]
        let a = try run(.layerComposite, .suspect, frames: 30, reading: frames)
        let b = try run(.layerComposite, .reference, frames: 30, reading: frames)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!, threshold: 0.02)
            let x = Int(LayerComposite.center(frame))
            #expect(n < 20, "\(frame) 枚目: \(n) 画素が違う。重なり (\(x + 15), 82) は層 \(a[frame]![x + 15, 82])・直 \(b[frame]![x + 15, 82])")
        }
    }

    // MARK: - 揺れる大きさ

    @Test("scale で脈打たせた線は、座標と太さを同じ倍率にして直に描いたのと同じ")
    func pulseScale() throws {
        let frames: Set<Int> = [1, 8, 16, 24, 45]
        let a = try run(.pulseScale, .suspect, frames: 45, reading: frames)
        let b = try run(.pulseScale, .reference, frames: 45, reading: frames)
        func lit(_ p: Picture) -> Int { p.count { c, _, _ in Self.isBright(c) } }
        // 参照: 大きさが変わっている
        #expect(abs(lit(b[8]!) - lit(b[45]!)) > 300)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!, threshold: 0.25)
            #expect(n < 40, "\(frame) 枚目 (s = \(PulseScale.s(frame))): \(n) 画素が違う。光る画素 \(lit(a[frame]!)) / \(lit(b[frame]!))")
        }
    }

    /// **原典と違うが、約束どおり。** Processing は負の幅を反対側へ伸ばし、p5 の楕円は
    /// 絶対値を取るので、`circle(x, y, 50 * sin(t))` は脈打ち続ける。mokume の `rect` は
    /// 説明で「幅か高さが 0 以下なら何も描かない」と約束しており、`ellipse` / `circle` も
    /// 同じ規則で消える。いまの振る舞いを押さえる。
    @Test("負の幅・高さの rect / ellipse / circle は何も描かず、正のときは正規化した図形と同じ")
    func negativeSize() throws {
        let frames: Set<Int> = [8, 16, 38, 45, 52]
        let a = try run(.negativeSize, .suspect, frames: 52, reading: frames)
        let b = try run(.negativeSize, .reference, frames: 52, reading: frames)
        func lit(_ p: Picture) -> Int { p.count { c, _, _ in Self.isBright(c) } }
        #expect(lit(b[45]!) > 1000)
        for frame in frames.sorted() {
            let size = NegativeSize.size(frame)
            if size > 0 {
                let n = differing(a[frame]!, b[frame]!, threshold: 0.25)
                #expect(n < 10, "\(frame) 枚目 (大きさ \(size)): \(n) 画素が違う")
            } else {
                #expect(lit(a[frame]!) == 0, "\(frame) 枚目 (大きさ \(size)): 光る画素 \(lit(a[frame]!))")
            }
        }
    }

    @Test("回り続けて大きくなった角・負の角の arc は、2π で割った余りの角と同じ弧")
    func spinnerArc() throws {
        let frames: Set<Int> = [1, 10, 20, 40, 60]
        let a = try run(.spinnerArc, .suspect, frames: 60, reading: frames)
        let b = try run(.spinnerArc, .reference, frames: 60, reading: frames)
        #expect(differing(b[1]!, b[20]!, threshold: 0.25) > 50)
        for frame in frames.sorted() {
            let left = differing(a[frame]!, b[frame]!, columns: 0..<80, threshold: 0.25)
            let right = differing(a[frame]!, b[frame]!, columns: 80..<160, threshold: 0.25)
            #expect(left < 12, "\(frame) 枚目の大きな正の角: \(left) 画素が違う")
            #expect(right < 12, "\(frame) 枚目の負の角: \(right) 画素が違う")
        }
    }

    @Test("NaN の図形は、同じフレームの他の図形も次のフレームも巻き込まない")
    func nanShape() throws {
        let frames: Set<Int> = [1, 5, 10, 11, 15]
        let a = try run(.nanShape, .suspect, frames: 15, reading: frames)
        let b = try run(.nanShape, .reference, frames: 15, reading: frames)
        #expect(b[1]!.count { c, _, _ in Self.isBright(c) } > 3000)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!)
            #expect(n < 5, "\(frame) 枚目: \(n) 画素が違う")
        }
    }

    // MARK: - 数と量

    @Test("フレームごとに増えて減る図形は、置いた数だけ出る")
    func growingCount() throws {
        let a = try run(.growingCount, .suspect, frames: GrowingCount.frames, reading: [9, 16, 17, 20])
        let b = try run(.growingCount, .reference, frames: GrowingCount.frames, reading: [20])
        func lit(_ p: Picture) -> Int { p.count { c, _, _ in c.red > 0.5 } }
        #expect(lit(b[20]!) == GrowingCount.count(20))
        for frame in [9, 16, 17, 20] {
            #expect(lit(a[frame]!) == GrowingCount.count(frame), "\(frame) 枚目: 光る画素 \(lit(a[frame]!))、置いた数 \(GrowingCount.count(frame))")
        }
    }

    @Test("たくさんの字と大きさを回した後でも、同じ字は同じ形で出る")
    func glyphChurn() throws {
        let last = GlyphChurn.frames
        let a = try run(.glyphChurn, .suspect, frames: last, reading: [1, 20, last])
        let b = try run(.glyphChurn, .reference, frames: last, reading: [1, last])
        #expect(b[last]!.count { c, _, _ in Self.isBright(c) } > 200)
        // 途中は字で埋まっている
        #expect(a[20]!.count { c, _, _ in Self.isBright(c) } > 2000, "20 枚目の字の画素 \(a[20]!.count { c, _, _ in Self.isBright(c) })")
        #expect(differing(a[1]!, b[1]!) == 0)
        let n = differing(a[last]!, b[last]!)
        #expect(n == 0, "\(last) 枚目の Hello: \(n) 画素が違う")
    }

    // MARK: - 入力

    @Test("pmouse で描くお絵描きは、離していた間の移動を線にせず、書き始めも欠けない")
    func pmouseStroke() throws {
        let last = PmouseStroke.frames
        let a = try run(.pmouseStroke, .suspect, frames: last)[last]!
        let b = try run(.pmouseStroke, .reference, frames: last)[last]!
        #expect(b[60, 40].red > 0.5 && b[120, 120].red > 0.5)
        // 離していた間 (100, 40) → (100, 120) を線にしていない
        let jump = a.count(columns: 94..<107, rows: 52..<108) { c, _, _ in c.red > 0.2 }
        #expect(jump == 0, "離していた間の飛び線: \(jump) 画素")
        // 2 画とも書き始めから書き終わりまで引けている
        for (x, y) in [(21, 40), (60, 40), (99, 40), (101, 120), (139, 120)] {
            #expect(a[x, y].red > 0.5, "(\(x), \(y)) の白 \(a[x, y].red)")
        }
        let n = differing(a, b, threshold: 0.25)
        #expect(n < 30, "\(n) 画素が違う")
    }

    @Test("mouseDragged の量を足すと dragX の合計と一致し、押した瞬間の飛びは入らない")
    func dragDelta() throws {
        let last = DragDelta.frames
        let suspect = DragDelta(route: .suspect)
        let reference = DragDelta(route: .reference)
        let a = try run(suspect, frames: last, dump: "dragDelta-suspect", before: DragDelta.script)[last]!
        let b = try run(reference, frames: last, dump: "dragDelta-reference", before: DragDelta.script)[last]!
        // 参照: 引きずった量だけ回っている
        #expect(abs(reference.angle - DragDelta.travel) < 0.01, "dragX の合計 \(reference.angle)、動かした量 \(DragDelta.travel)")
        #expect(abs(suspect.angle - DragDelta.travel) < 0.01, "引数の合計 \(suspect.angle)、動かした量 \(DragDelta.travel)")
        #expect(differing(a, b) == 0)
    }

    @Test("押し続けたキーは、繰り返しが届いても毎フレーム同じだけ進め、離すと止まる")
    func keyHeld() throws {
        let frames: Set<Int> = [2, 5, 12, 19, 22, 26]
        let sketch = KeyHeld(route: .suspect)
        var xs: [Int: Float] = [:]
        let a = try run(sketch, frames: KeyHeld.frames, reading: frames, dump: "keyHeld-suspect") { frame, runtime in
            KeyHeld.script(frame, runtime)
            if frame > 1 { xs[frame - 1] = sketch.x }
        }
        xs[KeyHeld.frames] = sketch.x
        let b = try run(.keyHeld, .reference, frames: KeyHeld.frames, reading: frames)
        #expect(differing(b[2]!, b[26]!) > 100)
        for frame in frames.sorted() {
            let want = 10 + KeyHeld.step * Float(KeyHeld.held(through: frame))
            #expect(xs[frame] == want, "\(frame) 枚目の x: \(xs[frame]!)、押していたフレームから \(want)")
            #expect(differing(a[frame]!, b[frame]!) == 0)
        }
    }

    @Test("スペースで止めている間は絵が残り、再開すると frameCount の続きから動く")
    func pauseToggle() throws {
        let last = PauseToggle.frames
        let sketch = PauseToggle(route: .suspect)
        var drawn: [Int: Int] = [:]
        let a = try run(sketch, frames: last, reading: Set(1...last), dump: "pauseToggle-suspect") { frame, runtime in
            PauseToggle.script(frame, runtime)
            if frame > 1 { drawn[frame - 1] = sketch.drawn }
        }
        drawn[last] = sketch.drawn
        let b = try run(.pauseToggle, .reference, frames: last, reading: Set(1...last))
        let counts = (1...last).map { drawn[$0]! }
        // 止まった区間がある (同じ frameCount が続く) のに、最後は進んでいる
        let paused = zip(counts, counts.dropFirst()).filter { $0 == $1 }.count
        #expect(paused >= 5, "描いた frameCount の列 \(counts)")
        #expect(counts.last! > counts[9] + 5, "描いた frameCount の列 \(counts)")
        for step in 1...last {
            let n = differing(a[step]!, b[drawn[step]!]!)
            #expect(n == 0, "\(step) 回目の絵が、frameCount \(drawn[step]!) の絵と \(n) 画素違う")
        }
    }

    @Test("draw() の頭で種を撒き直すと、毎フレーム同じ配置になる")
    func seedPerFrame() throws {
        let frames: Set<Int> = [1, 2, 7, 30]
        let a = try run(.seedPerFrame, .suspect, frames: 30, reading: frames)
        let b = try run(.seedPerFrame, .reference, frames: 30, reading: [1])
        #expect(b[1]!.count { c, _, _ in Self.isBright(c) } > 1000)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[1]!)
            #expect(n == 0, "\(frame) 枚目: 1 枚目の配置と \(n) 画素が違う")
        }
    }

    @Test("戻さなかった blendMode(.add) は、次のフレームの background を足し算にしない")
    func blendCarry() throws {
        let frames: Set<Int> = [1, 2, 10, 30]
        let a = try run(.blendCarry, .suspect, frames: 30, reading: frames)
        let b = try run(.blendCarry, .reference, frames: 30, reading: frames)
        #expect(differing(b[2]!, b[10]!) > 100)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!)
            #expect(n == 0, "\(frame) 枚目: \(n) 画素違う。隅 \(a[frame]![2, 2])")
        }
    }

    @Test("createShape した形を毎フレーム動かして置いても、その場で頂点を並べたのと同じ")
    func shapeReuse() throws {
        let frames: Set<Int> = [1, 2, 9, 30]
        let a = try run(.shapeReuse, .suspect, frames: 30, reading: frames)
        let b = try run(.shapeReuse, .reference, frames: 30, reading: frames)
        #expect(differing(b[1]!, b[9]!) > 100)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!, threshold: 0.25)
            #expect(n < 10, "\(frame) 枚目: \(n) 画素違う")
        }
    }

    @Test("丸い折れ目・丸い端の折れ線は、丸い端の線分を 1 本ずつ引いたのと同じ位置・太さ")
    func polylineTrail() throws {
        let frames: Set<Int> = [5, 20, 40, 60]
        let a = try run(.polylineTrail, .suspect, frames: 60, reading: frames)
        let b = try run(.polylineTrail, .reference, frames: 60, reading: frames)
        #expect(differing(b[20]!, b[60]!) > 100)
        for frame in frames.sorted() {
            // 縁の AA は折れ線 (三角形の経路) には無い (mokume ADR-0039 決定 3)。比べるのは
            // 決定 1 の「幾何の一致」— 50% で白黒にした形と、被覆で重みを付けた重心
            let (sa, sb) = (a[frame]!.shape { $0.blue }, b[frame]!.shape { $0.blue })
            let n = a[frame]!.count { c, x, y in (c.blue > 0.5) != (b[frame]![x, y].blue > 0.5) }
            #expect(Float(n) < sb.area / 12, "\(frame) 枚目: 白黒で \(n) 画素違う (面積 \(sb.area))")
            #expect(abs(sa.area - sb.area) < sb.area / 40, "\(frame) 枚目の面積: 折れ線 \(sa.area)、線分 \(sb.area)")
            #expect(simd_length(sa.centroid - sb.centroid) < 0.3, "\(frame) 枚目の重心: 折れ線 \(sa.centroid)、線分 \(sb.centroid)")
        }
    }

    // MARK: - 層と画素をフレームをまたいで使う

    @Test("setup で 1 度だけ描いた描き場所は、後のフレームでも中身が残る")
    func setupLayer() throws {
        let frames: Set<Int> = [1, 2, 30]
        let a = try run(.setupLayer, .suspect, frames: 30, reading: frames)
        let b = try run(.setupLayer, .reference, frames: 30, reading: frames)
        #expect(b[30]![150, 60].blue > 0.1)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!)
            #expect(n == 0, "\(frame) 枚目: \(n) 画素違う。(150, 60) は \(a[frame]![150, 60])")
        }
    }

    @Test("pixels で前のフレームの絵を読んでずらして書くと、1 フレーム 1 px ずつ動く")
    func pixelFeedback() throws {
        let frames: Set<Int> = [1, 2, 3, 10, 40]
        let a = try run(.pixelFeedback, .suspect, frames: 40, reading: frames)
        let b = try run(.pixelFeedback, .reference, frames: 40, reading: frames)
        #expect(differing(b[1]!, b[10]!) > 50)
        for frame in frames.sorted() {
            let n = differing(a[frame]!, b[frame]!)
            let lit = a[frame]!.count { c, _, _ in Self.isBright(c) }
            #expect(n == 0, "\(frame) 枚目: \(n) 画素違う (光る画素 \(lit)、参照 \(b[frame]!.count { c, _, _ in Self.isBright(c) }))")
        }
    }

    @Test("中央揃えの字は、x − textWidth / 2 に左揃えで置いたのと同じ場所に出る")
    func textCenter() throws {
        let frames: Set<Int> = [1, 7, 23, 60]
        let a = try run(.textCenter, .suspect, frames: 60, reading: frames)
        let b = try run(.textCenter, .reference, frames: 60, reading: frames)
        for frame in frames.sorted() {
            let (sa, sb) = (a[frame]!.shape { $0.red }, b[frame]!.shape { $0.red })
            #expect(sb.area > 50)
            #expect(
                abs(sa.centroid.x - sb.centroid.x) < 0.3,
                "\(frame) 枚目 \"\(TextCenter.label(frame))\": 重心 x 中央揃え \(sa.centroid.x)、textWidth \(sb.centroid.x)")
        }
    }

    @Test("tint(255, a) で溶け込む絵は、fill(255, a) の四角と同じ濃さ")
    func tintFade() throws {
        let frames: Set<Int> = [1, 5, 20, 40, 60]
        let a = try run(.tintFade, .suspect, frames: 60, reading: frames)
        let b = try run(.tintFade, .reference, frames: 60, reading: frames)
        #expect(b[20]![80, 80].red > b[5]![80, 80].red + 0.1)
        for frame in frames.sorted() {
            let (got, want) = (a[frame]![80, 80], b[frame]![80, 80])
            #expect(gap(got, want) < 0.01, "\(frame) 枚目 (a = \(TintFade.alpha(frame))): tint \(got)、fill \(want)")
        }
    }

    // MARK: - 立体

    @Test("背景を塗らない 3D でも、奥行きはフレームごとに消え、新しい箱が前の絵の上に出る")
    func depthNoBackground() throws {
        let a = try run(.depthNoBackground, .suspect, frames: 10, reading: [1, 2, 10])
        let b = try run(.depthNoBackground, .reference, frames: 10, reading: [2, 10])
        func isBlue(_ c: LinearRGBA) -> Bool { c.blue > c.red * 2 && c.blue > 0.05 }
        // 1 枚目は赤い箱、参照の中心は青い箱
        #expect(a[1]![80, 80].red > a[1]![80, 80].blue * 2)
        #expect(isBlue(b[2]![80, 80]))
        for frame in [2, 10] {
            let blue = (a[frame]!.count { c, _, _ in isBlue(c) }, b[frame]!.count { c, _, _ in isBlue(c) })
            #expect(isBlue(a[frame]![80, 80]), "\(frame) 枚目の中心 \(a[frame]![80, 80])")
            #expect(blue.0 > blue.1 * 9 / 10, "\(frame) 枚目の青い画素: 背景なし \(blue.0)、参照 \(blue.1)")
        }
    }
}

/// 窓で見る絵を、候補ごとに窓を出さずに 1 枚ずつ書き出す。**`ROUTINE_FRAMES` を渡したときだけ走る。**
///
/// PR に載せる動きの証跡 (アニメーション WebP) の素材で、検査ではない。候補ごとに
/// `<鍵>/frame.NNNN.png` へ 1 巡ぶんを書く。窓の中の舞台はフレーム番号の時計なので、
/// 書き出した列は同じ機械なら毎回同じになる。`ROUTINE_ONLY` で候補を絞れる。
@MainActor
@Test(
    "窓で見る絵を候補ごとに 1 枚ずつ書き出す",
    .enabled(if: ProcessInfo.processInfo.environment["ROUTINE_FRAMES"] != nil))
func writeFrames() throws {
    let environment = ProcessInfo.processInfo.environment
    let root = URL(fileURLWithPath: environment["ROUTINE_FRAMES"]!)
    let only = environment["ROUTINE_ONLY"].map { Set($0.split(separator: ",").map(String.init)) }
    for (index, habit) in Habits.all.enumerated() where only?.contains(habit.key.rawValue) ?? true {
        let directory = root.appendingPathComponent(habit.key.rawValue)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let window = Routine()
        let runtime = try SketchRuntime(sketch: window, gpu: gpu)
        defer { runtime.closePlugins() }
        for _ in 0..<index {
            runtime.input.enqueue(.keyDown(code: .arrowRight, characters: "", isRepeat: false))
            runtime.input.enqueue(.keyUp(code: .arrowRight))
        }
        for frame in 1...habit.frames {
            try runtime.advance()
            let name = String(format: "frame.%04d.png", frame)
            try runtime.target.writePNG(to: directory.appendingPathComponent(name))
        }
    }
}
