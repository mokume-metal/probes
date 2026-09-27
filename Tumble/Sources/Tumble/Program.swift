import Foundation

/// 種から決まる乱数 (SplitMix64)。
///
/// **同じ種からは、どの機械でも同じ列が出る。** 破れた列は種 1 つで呼び戻せる。Swift の
/// `SystemRandomNumberGenerator` は種を持てないので使わない。
nonisolated struct Rng: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// `0..<n` の整数。
    mutating func below(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }

    /// `p` の割合で真。
    mutating func chance(_ p: Double) -> Bool { Double(next() >> 11) / Double(1 << 53) < p }

    /// `range` の中の実数。
    mutating func uniform(_ range: ClosedRange<Double>) -> Double {
        range.lowerBound + Double(next() >> 11) / Double(1 << 53) * (range.upperBound - range.lowerBound)
    }
}

/// 口に渡す数 1 つ。**数でない値と無限も運べる** — JSON は NaN と無限を書けないので、
/// その 3 つだけ文字列で書く。
nonisolated struct Arg: Codable, Hashable, Sendable {
    var value: Double

    init(_ value: Double) { self.value = value }

    init(from decoder: any Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Double.self) {
            value = number
            return
        }
        switch try container.decode(String.self) {
        case "nan": value = .nan
        case "inf": value = .infinity
        case "-inf": value = -.infinity
        case let other:
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "数でない: \(other)")
        }
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.singleValueContainer()
        if value.isNaN {
            try container.encode("nan")
        } else if value.isInfinite {
            try container.encode(value > 0 ? "inf" : "-inf")
        } else {
            try container.encode(value)
        }
    }

    var float: Float { Float(value) }

    /// 整数として読む。**数でない値や範囲の外で、こちらが落ちないように締める** — 落ちるのが
    /// 物差しの側だと、mokume の破れと区別できない。
    var int: Int {
        guard value.isFinite else { return 0 }
        if value >= 9.2e18 { return .max }
        if value <= -9.2e18 { return .min }
        return Int(value)
    }

    /// 選択肢の番号として読む (`0..<count` に畳む)。
    func choice(_ count: Int) -> Int {
        let n = int % count
        return n < 0 ? n + count : n
    }

    /// Swift のソースに書くときの綴り。
    var swift: String {
        if value == Double(Int.max) { return "Int.max" }
        if value == Double(Int.min) { return "Int.min" }
        if value.isNaN { return ".nan" }
        if value.isInfinite { return value > 0 ? ".infinity" : "-.infinity" }
        if value == value.rounded(), abs(value) < 1e15 { return String(Int(value)) }
        return String(value)
    }
}

/// 口を 1 回呼ぶこと。
///
/// `tame` は、同じ口に同じ種類の**ふつうの値**を引いたもの。縮小器は端の値を `tame` へ
/// 置き換えて、破れに端の値が要るかを確かめる。
nonisolated struct Op: Codable, Hashable, Sendable {
    var name: String
    var args: [Arg]
    var tame: [Arg]
}

/// 呼び出しの列。setup で 1 度呼ぶ列と、フレームごとの列を持つ。
///
/// **最後のフレームの後に、番兵のフレームが 1 枚続く** (`Played`)。番兵は列が触る状態を
/// 全部既定へ戻してから決まった絵を描くので、列の後でも、列を回さなかったときと同じ絵に
/// なるはずである。
nonisolated struct Program: Codable, Hashable, Sendable {
    var seed: UInt64
    var setup: [Op]
    var frames: [[Op]]

    /// 列の長さ (setup を含む口の数)。
    var count: Int { setup.count + frames.reduce(0) { $0 + $1.count } }

    /// 番兵だけを描く列。戻らない劣化の参照に使う。
    static let empty = Program(seed: 0, setup: [], frames: [])
}

extension Program {
    /// 種から列を作る。
    ///
    /// フレームは 1〜4 枚、1 枚に 1〜14 口。setup には資源を作る口を 0〜2 個置く。
    @MainActor static func generate(seed: UInt64) -> Program {
        var rng = Rng(seed: seed)
        let setupCount = rng.below(3)
        let setup = (0..<setupCount).map { _ in Catalog.draw(&rng, in: Catalog.setupEntries) }
        let frameCount = 1 + rng.below(4)
        let frames = (0..<frameCount).map { _ in
            (0..<(1 + rng.below(14))).map { _ in Catalog.draw(&rng, in: Catalog.frameEntries) }
        }
        return Program(seed: seed, setup: setup, frames: frames)
    }

    /// 列を Swift の `setup()` と `draw()` として書く。縮めた列を再現に起こすのに使う。
    ///
    /// 描き場所へ描いている間 (`beginDraw` から `endDraw` まで) の口は `g.` を付けて書く。
    /// 最後のフレームの後は `sentinel()` (番兵) を描く。
    @MainActor var swift: String {
        var receiver = ""
        func write(_ op: Op, indent: String) -> String {
            let line = indent + Catalog.swift(op, receiver: receiver)
            if op.name == "beginDraw" { receiver = "g." }
            if op.name == "endDraw" { receiver = "" }
            return line
        }
        var lines = ["// seed \(seed)", "func setup() {"]
        lines += setup.map { write($0, indent: "    ") }
        lines.append("}")
        lines.append("func draw() {")
        lines.append("    switch frameCount {")
        for (index, frame) in frames.enumerated() {
            receiver = ""
            lines.append("    case \(index + 1):")
            lines += frame.map { write($0, indent: "        ") }
            if frame.isEmpty { lines.append("        break") }
        }
        lines.append("    default: sentinel()")
        lines.append("    }")
        lines.append("}")
        return lines.joined(separator: "\n")
    }
}
