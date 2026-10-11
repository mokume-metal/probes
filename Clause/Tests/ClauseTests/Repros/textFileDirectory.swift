// repro: mokume#2341
//
import Foundation
import mokume

/// loadTable / loadStrings にディレクトリや読む権利の無いファイルを渡すと、
/// 「UTF-8 として読めない。UTF-8 で保存されているか確かめよ」という的外れな失敗になる。
@MainActor
enum TextFileDirectory {
    final class Host: Sketch { required init() {} }

    static func reproduce() throws -> String? {
        let sketch = Host()
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("mokume-dir-\(getpid())")
        let folder = dir.appendingPathComponent("data.csv")   // .csv という名前のディレクトリ
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let locked = dir.appendingPathComponent("locked.csv")
        try Data("a,b\n1,2\n".utf8).write(to: locked)
        chmod(locked.path, 0)
        defer {
            chmod(locked.path, 0o644)
            try? FileManager.default.removeItem(at: dir)
        }
        var broken: [String] = []
        func probe(_ label: String, _ body: () throws(DataFailure) -> Void) {
            do {
                try body()
                broken.append("\(label): 投げなかった")
            } catch {
                if case .unreadable = error, error.description.contains("UTF-8") {
                    broken.append("\(label): .unreadable (\"…saved as UTF-8\")")
                }
            }
        }
        probe("loadTable(ディレクトリ)") { () throws(DataFailure) in _ = try sketch.loadTable(folder.path) }
        probe("loadStrings(ディレクトリ)") { () throws(DataFailure) in _ = try sketch.loadStrings(folder.path) }
        probe("loadTable(権利なし)") { () throws(DataFailure) in _ = try sketch.loadTable(locked.path) }
        return broken.isEmpty ? nil : "\(broken.count) 件が UTF-8 の問題と名乗った: " + broken.joined(separator: " / ")
    }
}
