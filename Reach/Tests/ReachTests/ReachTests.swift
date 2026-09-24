import Foundation
import Testing
import mokume

@testable import Reach

/// 一覧の検査。**期待値は「届くと判定した口は、実際に描ける」のほうに置く。**
@MainActor
@Suite struct ReachTests {
    /// 絵のタイルは、下地だけのタイルと違う画素を置く。**黙って捨てられる口を捕まえる** —
    /// コンパイルが通っても、描いて何も出ないなら「届く」とは言えない。
    @Test("絵のタイルは、どれも下地以外の画素を置く")
    func everyPictureDraws() throws {
        let blank = try Stage.render(Stage.blank)
        for entry in Entries.all {
            guard case .picture = entry.tile else { continue }
            let picture = try Stage.render(entry)
            #expect(picture.differing(from: blank) > 20, "\(entry.reference) が何も描かない")
        }
    }

    /// 窓の経路 (タイルごとの `createGraphics` の面を `image()` で貼る) でも同じことが言えるか。
    /// 本体の面へ直に描く上の検査とは描き先が違うので、面の側だけで捨てられる口を捕まえる。
    @Test("窓の格子でも、絵のタイルはどれも下地以外の画素を置く")
    func everyPictureDrawsOnGraphics() throws {
        let background = try Stage.render(Stage.blank)[0, 0]
        let grid = try Stage.renderGrid()
        for (index, entry) in Entries.all.enumerated() {
            guard case .picture = entry.tile else { continue }
            let x = Int(Reach.margin + Float(index % Reach.columns) * Reach.cellWidth)
            let y = Int(Reach.margin + Float(index / Reach.columns) * Reach.cellHeight)
            #expect(grid.differing(from: background, x: x, y: y, side: Int(Reach.shown)) > 20,
                    "\(entry.reference) が createGraphics の面で何も描かない")
        }
    }

    /// README の表は一覧から起こす。一覧だけを直して README を書き直し忘れると赤くなる。
    @Test("README の表が一覧と揃っている")
    func readmeMatches() throws {
        let text = try String(contentsOf: Ledger.readme, encoding: .utf8)
        let expected = try #require(Ledger.rendered(from: text), "README に <!-- reach:summary --> / <!-- reach:table --> の区間が無い")
        if ProcessInfo.processInfo.environment["REACH_WRITE_README"] != nil {
            try expected.write(to: Ledger.readme, atomically: true, encoding: .utf8)
            return
        }
        #expect(text == expected, "README の表が古い。REACH_WRITE_README=1 swift test で書き直す")
    }

    @Test("鍵 (手本の綴り) は重ならない")
    func referencesAreUnique() {
        let names = Entries.all.map(\.reference)
        #expect(Set(names).count == names.count)
    }

    /// 穴の判定には、何が無いか・何が歪むかの注が要る。README の表はこの注を写す。
    @Test("届かない判定には注がある")
    func gapsAreExplained() {
        for entry in Entries.all where !entry.verdict.reaches && entry.verdict != .write {
            #expect(!entry.note.isEmpty, "\(entry.reference) に注が無い")
        }
    }

    /// `none` のタイルは口を呼ばない (書けないものを書けたように作り替えない)。
    @Test("none の口は絵を持たない")
    func noneIsAbsent() {
        for entry in Entries.all where entry.verdict == .none {
            guard case .absent = entry.tile else {
                Issue.record("\(entry.reference) は none なのに描いている")
                continue
            }
        }
    }
}
