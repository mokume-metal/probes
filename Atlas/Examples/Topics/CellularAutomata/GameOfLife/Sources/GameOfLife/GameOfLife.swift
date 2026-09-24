import mokume
import Support

/// Processing の [Game of Life](https://processing.org/examples/gameoflife/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言い、`v0.5.0` では半分止まっていた。`v0.6.0` で動く。**
/// キーで「やり直す・止める・消す」の 3 つを操るところが `keyPressed()` で戻った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
/// 止めている間に升目を手で塗る `pause && mousePressed` も戻っている。
///
/// **残る歪みは `noSmooth()` (均しを切る口が無い) だけ。**
///
/// 乱数で初期の生死を決めるので **画素では比べられない。**
final class GameOfLife: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Game of Life")

    private let cellSize = 5
    private let probabilityOfAliveAtStart: Float = 15
    private var alive = LinearRGBA.transparent
    private var dead = LinearRGBA.transparent
    private var cells: [[Int]] = []
    private var cellsBuffer: [[Int]] = []
    /// 原典の `pause`。空白キーで止める。
    private var pause = false

    private var cols: Int { Int(width) / cellSize }
    private var rows: Int { Int(height) / cellSize }

    func setup() {
        alive = color(0, 200, 0)
        dead = color(0)
        // 背景の格子を描く線
        stroke(48)
        // 原典はここで `noSmooth()` を呼ぶ。**書けない**

        cells = (0..<cols).map { _ in
            (0..<rows).map { _ in random(100) > probabilityOfAliveAtStart ? 0 : 1 }
        }
        cellsBuffer = cells

        // 升目が面を覆いきらないときのために黒で埋める
        background(0)
    }

    func draw() {
        // 格子を描く
        for x in 0..<cols {
            for y in 0..<rows {
                fill(cells[x][y] == 1 ? alive : dead)
                rect(Float(x * cellSize), Float(y * cellSize), Float(cellSize), Float(cellSize))
            }
        }

        // 止めている間は、押した升目を手で生かしたり殺したりできる
        if pause && isMousePressed {
            let xCellOver = Int(constrain(map(mouseX, 0, width, 0, Float(cols)), 0, Float(cols - 1)))
            let yCellOver = Int(constrain(map(mouseY, 0, height, 0, Float(rows)), 0, Float(rows - 1)))
            if cellsBuffer[xCellOver][yCellOver] == 1 {
                cells[xCellOver][yCellOver] = 0
                fill(dead)
            } else {
                cells[xCellOver][yCellOver] = 1
                fill(alive)
            }
        }

        // 止めている間は世代を進めない
        guard !pause else { return }

        cellsBuffer = cells

        // 升目ごとに、まわりの 8 つを数える
        for x in 0..<cols {
            for y in 0..<rows {
                var neighbours = 0
                for xx in (x - 1)...(x + 1) {
                    for yy in (y - 1)...(y + 1) {
                        guard xx >= 0, xx < cols, yy >= 0, yy < rows else { continue }
                        guard !(xx == x && yy == y) else { continue }
                        if cellsBuffer[xx][yy] == 1 { neighbours += 1 }
                    }
                }
                if cellsBuffer[x][y] == 1 {
                    // 生きている升目。2 つか 3 つでなければ死ぬ
                    if neighbours < 2 || neighbours > 3 { cells[x][y] = 0 }
                } else {
                    // 死んでいる升目。3 つのときだけ生まれる
                    if neighbours == 3 { cells[x][y] = 1 }
                }
            }
        }
    }

    /// 原典の `void keyPressed()` — r で作り直し・空白で止め・c で消す。
    ///
    /// **`key` は文字 1 つではなく `String`。** 押しっぱなしのキーは原典と同じく連射する。
    func keyPressed() {
        if key == "r" || key == "R" {
            // 作り直す
            cells = (0..<cols).map { _ in
                (0..<rows).map { _ in random(100) > probabilityOfAliveAtStart ? 0 : 1 }
            }
        }
        if key == " " {
            // 止める / 動かす
            pause = !pause
        }
        if key == "c" || key == "C" {
            // 全部消す
            cells = (0..<cols).map { _ in [Int](repeating: 0, count: rows) }
        }
    }
}
