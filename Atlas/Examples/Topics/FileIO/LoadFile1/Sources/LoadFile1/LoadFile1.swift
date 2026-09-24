import Foundation
import mokume
import Support

/// Processing の [Load File 1](https://processing.org/examples/loadfile1/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ファイル入出力が主題)。絵は出る。**
/// `loadStrings` も `split` も mokume には無いが、**Foundation が持っている**ので
/// 面の外に書けば届く (`host`)。`frameRate(12)` だけが走り出す前にしか決められない。
final class LoadFile1: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 12, title: "Load File 1")

    private var lines: [String] = []
    private var index = 0

    func setup() {
        background(0)
        stroke(255)
        // 原典はここで `frameRate(12)` を呼ぶ。settings へ移した
        // 原典は `loadStrings("positions.txt")`。**読む口は無いが Foundation で書ける**
        let path = asset("Topics/File IO/LoadFile1", "positions.txt")
        lines = ((try? String(contentsOfFile: path, encoding: .utf8)) ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    }

    func draw() {
        if index < lines.count {
            let pieces = lines[index].split(separator: "\t").map(String.init)
            if pieces.count == 2 {
                // 面の大きさに合わせて座標を伸ばす
                let x = map(Float(pieces[0]) ?? 0, 0, 100, 0, width)
                let y = map(Float(pieces[1]) ?? 0, 0, 100, 0, height)
                point(x, y)
            }
            index = index + 1
        }
    }
}
