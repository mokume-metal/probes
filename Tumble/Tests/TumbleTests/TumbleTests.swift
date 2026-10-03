import Foundation
import Testing
import mokume

@testable import Tumble

/// 判定の検査。**判定そのものが効いていること** (陰性対照) と、固定の種の束が破れないこと
/// を押さえる。破れを探すのは `scripts/tumble.py run` で、ここは数十種だけを回す。
@MainActor
@Suite(.serialized) struct TumbleTests {
    /// 番兵が描けていること。参照まで何も出ていないと、一致しても何も言えない。
    @Test("番兵の参照が描けている")
    func referenceIsDrawn() {
        let picture = Examine.reference
        var lit = 0
        for y in 0..<picture.height {
            for x in 0..<picture.width where max(picture[x, y].red, picture[x, y].green, picture[x, y].blue) > 0.2 {
                lit += 1
            }
        }
        #expect(lit > 2000, "番兵の明るい画素 \(lit)")
    }

    /// **番兵が、フレームを越える状態を全部戻していること** (陰性対照)。口録のうち状態を変える
    /// 口をふつうの値で並べた列は、番兵で破れないはず。番兵から戻す行を 1 つ抜くと、ここが赤く
    /// なる (`blendMode(.blend)` を抜いて確かめた)。
    @Test("状態を変える口を並べても、番兵は列を回さなかった番兵と同じ")
    func sentinelResetsState() throws {
        func op(_ name: String, _ args: [Double]) -> Op { Op(name: name, args: args.map(Arg.init), tame: args.map(Arg.init)) }
        let program = Program(
            seed: 0,
            setup: [],
            frames: [[
                op("fill", [30, 128]), op("stroke", [255, 0, 0, 90]), op("strokeWeight", [9]), op("strokeCap", [1]),
                op("strokeJoin", [2]), op("blendMode", [5]), op("rectMode", [2]), op("ellipseMode", [3]),
                op("imageMode", [2]), op("tint", [255, 0, 0, 128]), op("texture", [0]), op("shader", [30]),
                op("textFont", [1]), op("textSize", [40]), op("textStyle", [3]), op("textAlign", [2, 1]),
                op("textWrap", [1]), op("curveDetail", [3]), op("curveTightness", [0.8]), op("exposure", [2.5]),
                op("toneMapping", [1]), op("clip", [0, 0, 40, 40]), op("translate", [30, 20]), op("rotate", [1]),
                op("lights", []), op("effects", [1, 1]), op("camera", [0, 0, 300, 80, 60, 0, 0, 1, 0]),
                op("rect", [10, 10, 50, 50]),
            ]])
        let outcome = try examine(program, name: "sentinelResetsState")
        #expect(outcome.breaks.isEmpty, "\(outcome)")
    }

    /// **決定論の判定が、食い違いを捕まえること** (陰性対照)。同じ列を 2 回回した指紋は揃い、
    /// 違う列の指紋とは揃わない。
    @Test("同じ列の指紋は揃い、違う列の指紋は揃わない")
    func hashesSeparate() throws {
        let a = try examine(Program.generate(seed: 3), name: "seed-3")
        let b = try examine(Program.generate(seed: 3), name: "seed-3-again")
        let c = try examine(Program.generate(seed: 4), name: "seed-4")
        #expect(a.hashes == b.hashes)
        #expect(a.hashes.first != c.hashes.first)
    }

    // MARK: - 縮めた列

    /// 探して見つけた破れを、縮めた列 (`Findings/<鍵>.json`) で押さえる。再現 (`Repros/`) は
    /// mokume だけで閉じた最小の形で、こちらは生成器が実際に出した列である。
    @Test("縮めた列: background(1e9, α) の絵に数でない画素が出ない")
    func backgroundOverflow() throws {
        let outcome = try examine(try finding("backgroundOverflow"), name: "backgroundOverflow")
        #expect(outcome.hashes.count == 2, "番兵まで回っていない: \(outcome)")
        // v0.12.1 では面が +inf を持った (mokume#1691、v0.15.0 で直った)
        #expect(!outcome.breaks.contains("nonfinite"), "mokume#1691 で直った: 数でない画素 \(outcome.nonfinitePixels)")
        // 番兵は background(24) で塗り直すので、汚れは次のフレームへ持ち越さない
        #expect(!outcome.breaks.contains("sentinel"))
    }

    /// 固定の種の束。**ここに破れが出たら、新しい破れか判定の誤りである。** 起票した破れを
    /// 踏む種は `Findings/` の縮めた列で押さえるので、ここでは踏まない種の束を選んである。
    @Test("種 0..<48 は、どれも破れない", arguments: 0..<48)
    func sweep(seed: Int) throws {
        let outcome = try examine(Program.generate(seed: UInt64(seed)), name: "seed-\(seed)")
        #expect(outcome.breaks.isEmpty, "種 \(seed): \(outcome.breaks) \(outcome)")
    }
}
