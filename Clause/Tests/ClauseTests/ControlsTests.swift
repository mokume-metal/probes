import Foundation
import Testing
import mokume

/// 破れなかった約束の 1 文を、陰性対照として常に緑で置く。
///
/// 再現 (`Repros/`) の破れが「どこまで」なのかの境目を押さえ、mokume が別の所を壊したときにも
/// 赤くなって知らせる。突いて破れなかった仮説の全部は README の「破れなかったもの」にある。
@MainActor
@Suite(.serialized) struct ControlsTests {
    final class Host: Sketch {
        required init() {}
        func draw() {}
    }

    /// 一時ディレクトリに文字を書いて、そのパスを返す。
    func seed(_ name: String, _ text: String) throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ClauseControls-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let path = dir.appendingPathComponent(name).path
        try Data(text.utf8).write(to: URL(fileURLWithPath: path))
        return path
    }

    @Test("saveTable で書いた表は、カンマ・引用符・改行・前後の空白を含むセルでも、loadTable で同じ表に戻る")
    func tableRoundTrip() throws {
        let host = Host()
        let values = [",", "\"", "x\ny", "x\r\ny", " pad ", "", "雪,\"だるま\"", "=1+1"]
        let rows = String(repeating: "1,2\n", count: values.count)
        var table = try host.loadTable(try seed("in.csv", "a,b\n" + rows), header: true)
        for (index, value) in values.enumerated() {
            table.setString(index, 0, value)
            table.setString(index, 1, String(value.reversed()))
        }
        let out = try seed("out.csv", "")
        try host.saveTable(table, out)
        let back = try host.loadTable(out, header: true)
        #expect(back == table)
        #expect(back.rows.map { $0.getString(0) } == values)
    }

    @Test("loadJSONObject は最上位の下 512 段まで読み、513 段で投げる")
    func jsonNestingLimit() throws {
        let host = Host()
        func nested(_ depth: Int) -> String {
            "{\"a\":" + String(repeating: "[", count: depth) + String(repeating: "]", count: depth) + "}"
        }
        #expect(throws: Never.self) { try host.loadJSONObject(try seed("ok.json", nested(511))) }
        #expect(throws: (any Error).self) { try host.loadJSONObject(try seed("deep.json", nested(600))) }
    }

    @Test("loadJSONObject は Double に収まらない正の数 (1e400) を投げる")
    func jsonPositiveOverflow() throws {
        let host = Host()
        #expect(throws: (any Error).self) { try host.loadJSONObject(try seed("big.json", "{\"a\":1e400}")) }
    }
}
