import Foundation
import Testing

@testable import Tumble

/// 生成器の約束。**種 1 つで列が呼び戻せなければ、破れを起票できない。**
@MainActor
@Suite struct GeneratorTests {
    @Test("同じ種からは同じ列が出て、違う種からは違う列が出る")
    func sameSeedSameProgram() {
        #expect(Program.generate(seed: 17) == Program.generate(seed: 17))
        #expect(Program.generate(seed: 17) != Program.generate(seed: 18))
    }

    @Test("列は JSON を往復しても同じで、数でない値と無限も運べる")
    func roundTrip() throws {
        let program = Program(
            seed: 1, setup: [],
            frames: [[Op(name: "rect", args: [Arg(.nan), Arg(.infinity), Arg(-.infinity), Arg(4)], tame: [Arg(1), Arg(2), Arg(3), Arg(4)])]])
        let data = try JSONEncoder().encode(program)
        let back = try JSONDecoder().decode(Program.self, from: data)
        #expect(back.frames[0][0].args[0].value.isNaN)
        #expect(back.frames[0][0].args[1].value == .infinity)
        #expect(back.frames[0][0].args[2].value == -.infinity)
        #expect(back.frames[0][0].args[3].value == 4)
        for seed in 0..<50 {
            let generated = Program.generate(seed: UInt64(seed))
            let again = try JSONDecoder().decode(Program.self, from: JSONEncoder().encode(generated))
            // NaN は == で等しくならないので、Swift の綴りで比べる
            #expect(again.swift == generated.swift)
        }
    }

    @Test("口録の口は、どれも 2000 種のうちに引かれる")
    func everyEntryIsDrawn() {
        var seen = Set<String>()
        for seed in 0..<2000 {
            let program = Program.generate(seed: UInt64(seed))
            for op in program.setup + program.frames.flatMap({ $0 }) { seen.insert(op.name) }
        }
        let missing = Catalog.frameEntries.map(\.name).filter { !seen.contains($0) }
        #expect(missing.isEmpty, "引かれなかった口: \(missing)")
    }

    @Test("端の値は 1 割前後の引数に出て、`tame` はふつうの値に戻る")
    func extremesAreDrawn() {
        var total = 0
        var extreme = 0
        for seed in 0..<500 {
            for op in Program.generate(seed: UInt64(seed)).frames.flatMap({ $0 }) {
                for (arg, tame) in zip(op.args, op.tame) {
                    total += 1
                    if arg != tame { extreme += 1 }
                    #expect(tame.value.isFinite)
                }
            }
        }
        let rate = Double(extreme) / Double(total)
        #expect(rate > 0.04 && rate < 0.15, "端の値の割合 \(rate)")
    }

    @Test("起票済みの破れを踏む引数は引かない (Catalog.avoidKnown)")
    func avoidsKnown() {
        for seed in 0..<3000 {
            let program = Program.generate(seed: UInt64(seed))
            for op in program.setup + program.frames.flatMap({ $0 }) {
                if ["text", "textBox", "textOutline"].contains(op.name) {
                    #expect(op.args.dropFirst().allSatisfy { $0.value.isFinite && abs($0.value) <= 1e15 }, "種 \(seed): \(op)")
                }
                if op.name == "curveDetail" {
                    #expect(op.args[0].value <= 1000, "種 \(seed): \(op)")
                }
                if op.name == "textLeading" {
                    #expect(!op.args[0].value.isInfinite, "種 \(seed): \(op)")
                }
            }
        }
    }

    @Test("列の Swift の綴りは、どの口も知っている名前で書く")
    func swiftSpelling() {
        for seed in 0..<300 {
            let text = Program.generate(seed: UInt64(seed)).swift
            #expect(!text.contains("知らない口"))
            #expect(text.contains("default: sentinel()"))
        }
    }
}
