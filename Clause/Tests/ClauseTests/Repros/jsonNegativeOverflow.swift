// repro: mokume#2329
//
import Foundation
import mokume

/// `loadJSONObject` は `Double` に収まらない数 (`1e400`) を読めない (malformed で投げる) と約束する。
/// 正の側は投げるが、負の側 (`-1e400`) は黙って読めて -inf になる。
@MainActor
enum JsonNegativeOverflow {
    final class Host: Sketch {
        required init() {}
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let host = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("JsonNegativeOverflow-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func outcome(_ literal: String) throws -> String {
            let path = dir.appendingPathComponent("v.json").path
            try "{\"a\": \(literal)}".write(toFile: path, atomically: true, encoding: .utf8)
            do {
                return "read \(try host.loadJSONObject(path).getFloat("a"))"
            } catch {
                return "threw"
            }
        }
        // 陰性対照: 正の側は約束どおり投げる
        let positive = try outcome("1e400")
        guard positive == "threw" else { return "control broke: 1e400 -> \(positive)" }
        let negative = try outcome("-1e400")
        let negativeJustOver = try outcome("-1.8e308")
        if negative == "threw" && negativeJustOver == "threw" { return nil }
        return "1e400 -> \(positive), but -1e400 -> \(negative) and -1.8e308 -> \(negativeJustOver) "
            + "(Double に収まらない数は読めない、のはずが負の側だけ読めてしまう)"
    }
}
