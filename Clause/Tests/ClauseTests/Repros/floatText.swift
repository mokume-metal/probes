// repro: mokume#2330
//
import Foundation
import mokume

/// `JSONObject.getFloat` / `XML.getFloat` / `TableRow.getFloat` は「数でない文字」なら NaN を返して初回だけ
/// 知らせ、前後の空白は落とすと約束する。ところが文字 `"nan"` は知らせずに NaN を返し、`"inf"`・`"0x10"` は
/// 数 (inf・16) として読まれる。Swift の `Float(String)` が受ける綴りが、そのまま「数の文字」として通っている。
/// 逆に、表のセルの前後の改行 (`"3\n"`) は空白として落とさず NaN になる (Processing の `getFloat` は 3)。
@MainActor
enum FloatText {
    final class Host: Sketch {
        required init() {}
        func draw() {}
    }

    /// 標準エラーへ出た文字を拾いながら `body` を走らせる。
    static func capturingStandardError(_ body: () throws -> Void) rethrows -> String {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("stderr-\(UUID()).txt")
        FileManager.default.createFile(atPath: file.path, contents: nil)
        fflush(stderr)
        let saved = dup(fileno(stderr))
        let fd = open(file.path, O_WRONLY)
        dup2(fd, fileno(stderr))
        defer {
            fflush(stderr)
            dup2(saved, fileno(stderr))
            close(saved)
            close(fd)
        }
        try body()
        fflush(stderr)
        return (try? String(contentsOf: file, encoding: .utf8)) ?? ""
    }

    static func reproduce() throws -> String? {
        let host = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("FloatText-\(UUID())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let jsonPath = dir.appendingPathComponent("v.json").path
        try #"{"control": "N/A", "nanText": "nan", "infText": "inf", "hexText": "0x10"}"#
            .write(toFile: jsonPath, atomically: true, encoding: .utf8)
        let xmlPath = dir.appendingPathComponent("v.xml").path
        try #"<r control="N/A" nanText="nan" infText="inf" hexText="0x10"/>"#
            .write(toFile: xmlPath, atomically: true, encoding: .utf8)
        let csvPath = dir.appendingPathComponent("v.csv").path
        try "control,nanText,infText,hexText,newline\nN/A,nan,inf,0x10,\"3\n\"\n"
            .write(toFile: csvPath, atomically: true, encoding: .utf8)
        let json = try host.loadJSONObject(jsonPath)
        let row = try host.loadTable(csvPath, header: true).rows[0]
        let xml = try host.loadXML(xmlPath)

        // 種類ごとに、読んだ値と標準エラーへ出た知らせを拾う
        let readers: [(String, (String) -> Float)] = [
            ("json", { json.getFloat($0) }), ("xml", { xml.getFloat($0) }), ("table", { row.getFloat($0) }),
        ]
        var values: [String: Float] = [:]
        var said: [String: String] = [:]
        for (kind, read) in readers {
            said[kind] = try capturingStandardError {
                for key in ["control", "nanText", "infText", "hexText"] { values[kind + "." + key] = read(key) }
            }
        }
        values["table.newline"] = row.getFloat("newline")

        var broken: [String] = []
        for (kind, _) in readers {
            // 陰性対照: "N/A" は NaN で、知らせが出る
            guard values["\(kind).control"]!.isNaN, said[kind]!.contains("N/A") else {
                return "control broke: \(kind) N/A -> \(values["\(kind).control"]!), stderr=\(said[kind]!)"
            }
            let nan = values["\(kind).nanText"]!
            if nan.isNaN && !said[kind]!.contains("nanText") {
                broken.append("\(kind) \"nan\" -> NaN with no warning")
            }
            let inf = values["\(kind).infText"]!
            if !inf.isNaN { broken.append("\(kind) \"inf\" -> \(inf)") }
            let hex = values["\(kind).hexText"]!
            if !hex.isNaN { broken.append("\(kind) \"0x10\" -> \(hex)") }
        }
        let newline = values["table.newline"]!
        if newline != 3 { broken.append("table \"3\\n\" -> \(newline)") }
        return broken.isEmpty ? nil : broken.joined(separator: "; ")
    }
}
