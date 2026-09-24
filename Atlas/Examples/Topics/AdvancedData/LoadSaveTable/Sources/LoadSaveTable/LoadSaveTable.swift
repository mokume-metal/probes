import Foundation
import mokume
import Support

/// Processing の [Load Save Table](https://processing.org/examples/loadsavetable/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (データ構造が主題)。絵は出る。**
/// **`Table` に当たる型は mokume にも Foundation にも無い**ので、CSV を読むところは
/// 自分で書く (台帳の `write`)。`mousePressed()` の口は `v0.6.0` で入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた) ので、押して足せる。
final class LoadSaveTable: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Load Save Table")

    final class Bubble {
        let x: Float, y: Float, diameter: Float, name: String
        var over = false

        init(_ x: Float, _ y: Float, _ diameter: Float, _ s: String) {
            self.x = x; self.y = y; self.diameter = diameter; name = s
        }

        func rollover(_ px: Float, _ py: Float) {
            over = dist(px, py, x, y) < diameter / 2
        }

        func display(on sketch: any Sketch) {
            sketch.stroke(0)
            sketch.strokeWeight(2)
            sketch.noFill()
            sketch.ellipse(x, y, diameter, diameter)
            if over {
                sketch.fill(0)
                sketch.textAlign(.center)
                sketch.text(name, x, y + diameter / 2 + 20)
            }
        }
    }

    private var bubbles: [Bubble] = []

    func setup() {
        loadData()
    }

    func draw() {
        background(255)
        for b in bubbles {
            b.display(on: self)
            b.rollover(mouseX, mouseY)
        }
        textAlign(.left)
        fill(0)
        text("Click to add bubbles.", 10, height - 10)
    }

    private func loadData() {
        // 原典は `loadTable("data.csv", "header")` の 1 行。**表を読む型が無い**ので、
        // 見出しの行と値の行に自分で割る
        let path = asset("Topics/Advanced Data/LoadSaveTable", "data.csv")
        let text = (try? String(contentsOfFile: path, encoding: .utf8)) ?? ""
        var rows = text.split(separator: "\n").map { $0.split(separator: ",", omittingEmptySubsequences: false).map(String.init) }
        guard !rows.isEmpty else { return }
        let header = rows.removeFirst()
        let column = { (row: [String], name: String) -> String in
            guard let i = header.firstIndex(of: name), i < row.count else { return "" }
            return row[i]
        }
        bubbles = rows.compactMap { row in
            guard row.count == header.count else { return nil }
            return Bubble(Float(column(row, "x")) ?? 0, Float(column(row, "y")) ?? 0,
                          Float(column(row, "diameter")) ?? 0, column(row, "name"))
        }
    }

    /// 原典の `void mousePressed()` — 押した場所へ 1 つ足す。
    ///
    /// **書き戻すところは移していない。** 原典は `saveTable()` で `data/` の CSV を
    /// 上書きするが、資材は `upstream/` (gitignore 済み) にあり、works が上流の複製を
    /// 書き換える理由が無い。**足したものは走っている間だけ残る。**
    func mousePressed() {
        bubbles.append(Bubble(mouseX, mouseY, random(40, 80), "Blah"))
        // 原典はここで古い行を 1 つ落として 10 行に保ち、CSV へ書き戻す
        if bubbles.count > 10 {
            bubbles.removeFirst()
        }
    }
}
