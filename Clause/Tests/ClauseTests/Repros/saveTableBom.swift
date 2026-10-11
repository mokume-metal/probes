// repro: mokume#未起票
//
import Foundation
import mokume

/// saveTable → loadTable の往復で、最初のセルの頭の U+FEFF が BOM として落とされ、
/// 1 列の表ではその行ごと消える。
@MainActor
enum SaveTableBom {
    final class Host: Sketch { required init() {} }

    static func reproduce() throws -> String? {
        let sketch = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mokume-bom-\(getpid())")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        func seed(_ name: String, _ text: String) throws -> String {
            let path = dir.appendingPathComponent(name).path
            try Data(text.utf8).write(to: URL(fileURLWithPath: path))
            return path
        }
        var broken: [String] = []

        // 2 列: 最初のセルを "\u{FEFF}z" にして書いて読む
        var wide = try sketch.loadTable(try seed("wide.csv", "a,b\n1,2\n"))
        wide.setString(0, 0, "\u{FEFF}z")
        let widePath = dir.appendingPathComponent("wide-out.csv").path
        try sketch.saveTable(wide, widePath)
        let wideBack = try sketch.loadTable(widePath)
        if wideBack != wide {
            let before = wide.rows[0].getString(0).unicodeScalars.count
            let after = wideBack.rows[0].getString(0).unicodeScalars.count
            broken.append("2 列: 最初のセルが \(before) スカラーから \(after) スカラーに縮んだ")
        }

        // 1 列: 最初のセルを "\u{FEFF}" だけにすると、行が消える
        var narrow = try sketch.loadTable(try seed("narrow.csv", "\"\"\n\"\"\n"))
        narrow.setString(0, 0, "\u{FEFF}")
        let narrowPath = dir.appendingPathComponent("narrow-out.csv").path
        try sketch.saveTable(narrow, narrowPath)
        let narrowBack = try sketch.loadTable(narrowPath)
        if narrowBack.rowCount != narrow.rowCount {
            broken.append("1 列: 行の数が \(narrow.rowCount) から \(narrowBack.rowCount) に減った")
        }
        return broken.isEmpty ? nil : broken.joined(separator: " / ")
    }
}
