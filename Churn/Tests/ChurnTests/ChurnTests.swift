import Foundation
import Testing
import mokume

@testable import Churn

/// 候補ごとの検査。**期待値は「1 つのことだけが違う 2 つの経路は、比べるフレーム・比べる領域で同じ絵」に置く。**
///
/// 各検査は、比べる前に**参照の側が描けていること**を押さえる。参照まで何も出ていないと、
/// 左右が一致しても何も言えないため。
@MainActor
@Suite struct ChurnTests {
    /// 同じ絵とみなす差。**同じ機械・同じフレーム番号ならバイト単位で同じ絵が出る**
    /// (mokume ADR-0001 原則 2) ので、表示の 1 段 (1/255) より小さく置く。
    static let exact: Float = 0.004

    /// 種を変えて回す。場面の列とがらくたは種から作る。
    nonisolated static let seeds: [UInt64] = [1, 2, 3]

    /// 下地より明るい画素の数。
    static func lit(_ picture: Picture, columns: Range<Int>? = nil, rows: Range<Int>? = nil) -> Int {
        picture.count(columns: columns, rows: rows) { c, _, _ in max(c.red, c.green, c.blue) > 0.2 }
    }

    /// 候補を 2 経路で回し、参照が描けていることを押さえる。**比べるのは `expectSame`** —
    /// 破れを `withKnownIssue` で包むとき、参照が描けていないことまで既知の問題に数えない
    /// ように分ける。
    func render(_ key: ChurnKey, seed: UInt64 = Scenes.seed, sourceLocation: SourceLocation = #_sourceLocation) throws
        -> (suspect: [Int: Picture], reference: [Int: Picture], sketch: Stir)
    {
        let (a, sketch) = try run(key, .suspect, seed: seed)
        let (b, _) = try run(key, .reference, seed: seed)
        let churn = Scenes.named(key)
        let last = churn.comparedFrames.upperBound
        #expect(
            Self.lit(b[last]!, columns: churn.columns) > 100, "参照の \(last) 枚目が描けていない",
            sourceLocation: sourceLocation)
        return (a, b, sketch)
    }

    /// 比べるフレームの全部で、2 つの経路が比べる領域で同じ絵であること。
    ///
    /// **食い違ったフレームを 1 つの期待にまとめる。** 既知の問題の件数を、フレームの数ではなく候補の数で
    /// 数えるためである (README「既知の問題」)。
    func expectSame(
        _ key: ChurnKey, _ pair: (suspect: [Int: Picture], reference: [Int: Picture], sketch: Stir),
        note: String = "", sourceLocation: SourceLocation = #_sourceLocation
    ) {
        let columns = Scenes.named(key).columns
        let broken = pair.suspect.keys.sorted().compactMap { frame -> String? in
            let n = differing(pair.suspect[frame]!, pair.reference[frame]!, columns: columns, threshold: Self.exact)
            return n == 0 ? nil : "\(frame) 枚目 \(n) 画素"
        }
        #expect(broken.isEmpty, "\(note)\(key): \(broken.joined(separator: "・")) が違う", sourceLocation: sourceLocation)
    }

    /// 参照が描けていることを押さえてから、全部のフレームを比べる (陰性対照・直った約束)。
    /// 直った約束は `note` に `"mokume#N で直った: "` を渡し、戻れば赤くなって番号を言う。
    func compare(
        _ key: ChurnKey, seed: UInt64 = Scenes.seed, note: String = "", sourceLocation: SourceLocation = #_sourceLocation
    ) throws {
        expectSame(key, try render(key, seed: seed, sourceLocation: sourceLocation), note: note, sourceLocation: sourceLocation)
    }

    /// 参照が描けていることを押さえてから、破れを `issue` で名指しして比べる。
    func compareKnown(_ key: ChurnKey, _ issue: Comment, sourceLocation: SourceLocation = #_sourceLocation) throws {
        let pair = try render(key, sourceLocation: sourceLocation)
        withKnownIssue(issue) { expectSame(key, pair, sourceLocation: sourceLocation) }
    }

    // MARK: - 履歴

    @Test(
        "前置きの履歴だけが違う 2 経路は、前置きの後に同じ絵を描く",
        arguments: [ChurnKey.historyBlank, .historyMixed2D, .historyParticles, .history3DShadows], seeds)
    func history(_ key: ChurnKey, seed: UInt64) throws {
        try compare(key, seed: seed)
    }

    /// 前置きで 2 経路が違う絵を描いていること。描いていなければ、履歴の関係は何も突いていない。
    @Test("前置きでは、suspect だけががらくたを描いている", arguments: [ChurnKey.historyMixed2D, .historyParticles, .history3DShadows])
    func preludeDiffers(_ key: ChurnKey) throws {
        let churn = Scenes.named(key)
        let frame = Scenes.prelude
        let a = try run(churn.make(.suspect), frames: frame, dump: "\(key)-prelude-suspect")[frame]!
        let b = try run(churn.make(.reference), frames: frame, dump: "\(key)-prelude-reference")[frame]!
        #expect(differing(a, b, threshold: Self.exact) > 1000, "前置きの \(frame) 枚目で、2 経路の絵が違わない")
    }

    /// 前置きの後の場面で、粒が描けていること (粒が消えても左右が一致してしまわないように)。
    @Test("前置きの後の場面で、粒が描けている")
    func settledParticles() throws {
        let (pictures, _) = try run(.historyParticles, .reference)
        let last = Scenes.named(.historyParticles).comparedFrames.upperBound
        #expect(Self.lit(pictures[last]!, columns: 120..<200, rows: 125..<185) > 50, "粒が描けていない")
    }

    // MARK: - runtime の積み重ね

    @Test("増減と移動を回した k 枚目は、同じ場面を新しい runtime の 1 枚目に描いたものと同じ", arguments: [ChurnKey.fresh2D, .fresh3D], seeds)
    func fresh(_ key: ChurnKey, seed: UInt64) throws {
        try compare(key, seed: seed)
    }

    // MARK: - 数

    @Test(
        "右に足す数をフレームごとに変えても、左の絵は変わらない",
        arguments: [ChurnKey.localityForms, .localityFolding, .localityInstanceCap, .localitySweep, .localityShadow])
    func locality(_ key: ChurnKey) throws {
        let pair = try render(key)
        // 右に足した物体が描けていること (足していなければ、数の関係は何も突いていない)
        let columns = Scenes.named(key).columns!
        let busiest = pair.suspect.keys.max { a, b in
            Self.lit(pair.suspect[a]!, columns: columns.upperBound..<Scenes.side)
                < Self.lit(pair.suspect[b]!, columns: columns.upperBound..<Scenes.side)
        }!
        #expect(
            Self.lit(pair.suspect[busiest]!, columns: columns.upperBound..<Scenes.side) > 100, "右に足した物体が描けていない")
        expectSame(key, pair)
    }

    // MARK: - 置き方

    @Test("2 領域の形を shape(at:) でまとめて置く = 1 つずつ置く")
    func shapeAtRegions() throws {
        try compareKnown(
            .shapeAtRegions, "mokume#未起票: shape(_:at:) が記録した領域ごとに置き場所を回し、重なる置き場所の前後が入れ替わる")
    }

    @Test("置き場所の色を半透明にして、まとめて置く = 1 つずつ置く")
    func shapeAtTranslucent() throws {
        try compareKnown(
            .shapeAtTranslucent, "mokume#未起票: shape(_:at:) が記録した領域ごとに置き場所を回し、重なる置き場所の前後が入れ替わる")
    }

    @Test("陰性対照: 1 領域の形・3D の立体は、まとめて置いても 1 つずつと同じ", arguments: [ChurnKey.shapeAtSingleRegion, .shapeAt3D])
    func shapeAtControls(_ key: ChurnKey) throws {
        try compare(key)
    }

    @Test("捨てた描き場所の ObjectIdentifier を引き継いだ描き場所も、置いた時点の絵が出る")
    func graphicsReuse() throws {
        let pair = try render(.graphicsReuse)
        // 引き継ぎが起きていなければ、破れの条件が立っていない (アドレスの使い回しに頼るため)
        #expect(pair.sketch.reused > 0, "ObjectIdentifier の引き継ぎが 1 度も起きなかった")
        withKnownIssue("mokume#未起票: 捨てた描き場所の ObjectIdentifier を引き継ぐと、置いた時点の絵が保たれない") {
            expectSame(.graphicsReuse, pair)
        }
    }

    @Test("陰性対照: 前の描き場所を生かしたままなら、置いた時点の絵が出る")
    func graphicsKeptAlive() throws {
        let pair = try render(.graphicsKeptAlive)
        #expect(pair.sketch.reused == 0, "生かしているのに ObjectIdentifier を引き継いだ")
        expectSame(.graphicsKeptAlive, pair)
    }
}
