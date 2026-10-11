// repro: mokume#未起票
//
import Foundation
import mokume

/// `loadXML` は「文字は UTF-8 (ファイルも URL の本文も)」と約束し、UTF-8 として読めない
/// ものは `unreadable` で投げる。ところが UTF-8 として正しく解けたファイルでも、宣言に
/// `encoding="Shift_JIS"` などが書いてあると、XMLParser がその宣言で解き直して `malformed` で投げる。
@MainActor
enum XmlEncodingDecl {
    final class Host: Sketch {
        required init() {}
        func draw() {}
    }

    static func reproduce() throws -> String? {
        let host = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("XmlEnc-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func read(_ declaration: String, _ body: String) throws -> String {
            let path = dir.appendingPathComponent("v.xml").path
            // 中身は常に UTF-8 で書く
            try (declaration + body).write(toFile: path, atomically: true, encoding: .utf8)
            do {
                let root = try host.loadXML(path)
                return "read \(root.getChildren("星").count) <星>"
            } catch {
                return "threw \(error)".replacingOccurrences(of: path, with: "v.xml")
            }
        }
        let body = "<sky><星 x=\"1\"/></sky>"
        // 陰性対照: 宣言なし・UTF-8 の宣言は読める
        let none = try read("", body)
        let utf8 = try read("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", body)
        guard none == "read 1 <星>", utf8 == "read 1 <星>" else { return "control broke: \(none) / \(utf8)" }
        // 境界: ASCII だけなら他の宣言でも読める
        let sjis = try read("<?xml version=\"1.0\" encoding=\"Shift_JIS\"?>", body)
        let latin1 = try read("<?xml version=\"1.0\" encoding=\"ISO-8859-1\"?>", body)
        if sjis.hasPrefix("read") && latin1.hasPrefix("read") { return nil }
        return "valid UTF-8 file: no declaration -> \(none); encoding=\"Shift_JIS\" -> \(sjis); encoding=\"ISO-8859-1\" -> \(latin1)"
    }
}
