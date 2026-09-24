import mokume

/// Processing の [Wolfram](https://processing.org/examples/wolfram/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` では押しても何も起きなかった。`v0.6.0` で動く** —
/// `mousePressed()` の出来事を受ける口が入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。押して規則を
/// 選び直すところが落ちる (面の下まで届いたときの作り直しは残る)。
///
/// 乱数で規則を選び直すので **画素では比べられない。**
final class Wolfram: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Wolfram")

    /// 原典の `class CA`。**描く口が面の上にある**ので `render(on:)` が面を受け取る。
    final class CA {
        var cells: [Int] = []      // 0 と 1 の並び
        var generation = 0         // 何代目か
        let scl = 1                // 1 つの升目の大きさ
        var rules: [Int]           // 規則 (たとえば {0,1,1,0,1,1,0,1})
        let width: Int
        let height: Int

        init(_ r: [Int], width: Int, height: Int) {
            rules = r
            self.width = width
            self.height = height
            cells = [Int](repeating: 0, count: width / scl)
            restart()
        }

        /// でたらめな規則にする
        func randomize(_ pick: (Float) -> Float) {
            for i in 0..<8 { rules[i] = Int(pick(2)) }
        }

        /// 0 代目へ戻す
        func restart() {
            cells = [Int](repeating: 0, count: cells.count)
            // ひとまず真ん中の 1 つだけを 1 にする
            cells[cells.count / 2] = 1
            generation = 0
        }

        /// 次の代を作る
        func generate() {
            var nextgen = [Int](repeating: 0, count: cells.count)
            // 端は隣が 1 つしか無いので飛ばす
            for i in 1..<(cells.count - 1) {
                nextgen[i] = executeRules(cells[i - 1], cells[i], cells[i + 1])
            }
            for i in 1..<(cells.count - 1) { cells[i] = nextgen[i] }
            generation += 1
        }

        func render(on sketch: any Sketch) {
            for i in cells.indices {
                sketch.fill(cells[i] == 1 ? color(255) : color(0))
                sketch.noStroke()
                sketch.rect(Float(i * scl), Float(generation * scl), Float(scl), Float(scl))
            }
        }

        /// Wolfram の規則
        func executeRules(_ a: Int, _ b: Int, _ c: Int) -> Int {
            if a == 1 && b == 1 && c == 1 { return rules[0] }
            if a == 1 && b == 1 && c == 0 { return rules[1] }
            if a == 1 && b == 0 && c == 1 { return rules[2] }
            if a == 1 && b == 0 && c == 0 { return rules[3] }
            if a == 0 && b == 1 && c == 1 { return rules[4] }
            if a == 0 && b == 1 && c == 0 { return rules[5] }
            if a == 0 && b == 0 && c == 1 { return rules[6] }
            if a == 0 && b == 0 && c == 0 { return rules[7] }
            return 0
        }

        /// 面の下まで届いたら 1 巡おわり
        func finished() -> Bool { generation > height / scl }
    }

    private var ca: CA?

    func setup() {
        let ruleset = [0, 1, 0, 1, 1, 0, 1, 0]   // はじめの規則
        ca = CA(ruleset, width: Int(width), height: Int(height))
        background(0)
    }

    func draw() {
        guard let ca else { return }
        ca.render(on: self)
        ca.generate()

        // 下まで届いたら消して、新しい規則で作り直す
        if ca.finished() {
            background(0)
            ca.randomize { self.random($0) }
            ca.restart()
        }
    }

    /// 原典の `void mousePressed()` — 押すたびに規則を選び直す。
    func mousePressed() {
        guard let ca else { return }
        background(0)
        ca.randomize { self.random($0) }
        ca.restart()
    }
}
