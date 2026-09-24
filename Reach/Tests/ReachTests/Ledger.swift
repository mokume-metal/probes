import Foundation

@testable import Reach

/// README の `<!-- reach:… -->` の区間を、一覧 (`Entries.all`) から起こす。
///
/// **手で書かない。** 一覧を直したら `REACH_WRITE_README=1 swift test` で書き直す。
/// 書き直さずに一覧だけを変えると、`ReachTests.readmeMatches` が赤くなる。
enum Ledger {
    static let readme = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("README.md")

    /// 区分ごとの件数。
    @MainActor static var summary: String {
        var lines = ["| 判定 | 件数 | |", "| --- | ---: | --- |"]
        let meaning: [Verdict: String] = [
            .same: "同名・同じ引数の形がある", .renamed: "口はあるが別名・別の形",
            .host: "Swift・Foundation の語彙で当たる", .drop: "mokume では要らない",
            .write: "面の外に書けば済む (`Support.swift`)", .bend: "書けるが歪む", .none: "口が無い",
        ]
        for verdict in Verdict.allCases {
            let count = Entries.all.filter { $0.verdict == verdict }.count
            lines.append("| `\(verdict.rawValue)` | \(count) | \(meaning[verdict]!) |")
        }
        lines.append("| **合計** | **\(Entries.all.count)** | |")
        return lines.joined(separator: "\n")
    }

    /// 全件の表。区分ごとに見出しを切る。
    @MainActor static var table: String {
        var out: [String] = []
        for section in Section.allCases {
            let rows = Entries.all.filter { $0.section == section }
            guard !rows.isEmpty else { continue }
            out.append("#### \(section.rawValue)\n")
            out.append("| 手本 | 判定 | mokume | 注 |")
            out.append("| --- | --- | --- | --- |")
            for e in rows {
                var note = e.note
                if let issue = e.issue {
                    let number = issue.replacingOccurrences(of: "mokume#", with: "")
                    note += (note.isEmpty ? "" : " — ") + "[\(issue)](https://github.com/mokume-metal/mokume/issues/\(number))"
                }
                out.append("| `\(cell(e.reference))` | `\(e.verdict.rawValue)` | \(cell(e.mokume)) | \(cell(note)) |")
            }
            out.append("")
        }
        return out.joined(separator: "\n").trimmingCharacters(in: .newlines)
    }

    static func cell(_ s: String) -> String { s.replacingOccurrences(of: "|", with: "\\|") }

    /// `text` の `<!-- reach:name -->` と `<!-- /reach:name -->` の間を `body` に置き換える。
    static func splice(_ text: String, _ name: String, _ body: String) -> String? {
        let open = "<!-- reach:\(name) -->", close = "<!-- /reach:\(name) -->"
        guard let a = text.range(of: open), let b = text.range(of: close), a.upperBound <= b.lowerBound else { return nil }
        return text.replacingCharacters(in: a.upperBound..<b.lowerBound, with: "\n" + body + "\n")
    }

    /// 一覧から起こした README。区間の印が無ければ nil。
    @MainActor static func rendered(from text: String) -> String? {
        guard let a = splice(text, "summary", summary) else { return nil }
        return splice(a, "table", table)
    }
}
