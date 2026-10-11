// repro: mokume#未起票
//
import Foundation
import mokume

/// 壊れた XML は「壊れていた行」を添えて投げると約束する。行の数え方は LF・CRLF・CR のどれでもよい
/// (``TextFile/lines(of:)``。JSON は同じ数え方に揃えてある)。ところが CR だけで改行した XML では、
/// 3 行目で壊れていても line 1 と名乗る。
@MainActor
enum XmlCarriageReturn {
    final class Host: Sketch {
        required init() {}
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let host = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("XmlCR-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func line(_ text: String, _ ext: String) throws -> Int? {
            let path = dir.appendingPathComponent("v.\(ext)").path
            try text.write(toFile: path, atomically: true, encoding: .utf8)
            do {
                if ext == "xml" { _ = try host.loadXML(path) } else { _ = try host.loadJSONObject(path) }
                return nil
            } catch {
                if case .malformed(_, let line, _) = error { return line }
                return nil
            }
        }
        // 4 行目 (</c>) で閉じる名前が食い違う
        let lf = try line("<a>\n<b>\n<x/>\n</c>\n</a>", "xml")
        let crlf = try line("<a>\r\n<b>\r\n<x/>\r\n</c>\r\n</a>", "xml")
        let cr = try line("<a>\r<b>\r<x/>\r</c>\r</a>", "xml")
        // 対照: 同じ CR の文字で、JSON は 4 行目と名乗る
        let jsonCR = try line("{\r\"a\":1,\r\"b\":2,\r\"c\":,\r\"d\":3\r}", "json")
        guard lf == 4, crlf == 4, jsonCR == 4 else {
            return "control broke: LF=\(String(describing: lf)) CRLF=\(String(describing: crlf)) JSON CR=\(String(describing: jsonCR))"
        }
        if cr == 4 { return nil }
        return "XML broken at line 4: LF -> line \(lf!), CRLF -> line \(crlf!), CR only -> line \(String(describing: cr)) (JSON with CR -> line \(jsonCR!))"
    }
}
