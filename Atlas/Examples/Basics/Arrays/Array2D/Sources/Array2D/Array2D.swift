import mokume
import Support

/// Processing の [Array 2D](https://processing.org/examples/array2d/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。当たっていた。`v0.9.0` で埋まった** — 進行を止める口が
/// 入った ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。原典の「1 度だけ走らせて止める」が
/// そのまま書ける (`draw()` が毎フレーム同じ絵を描き直すだけだったので、見た目は前から同じ)。
///
/// `dist()` も mokume に無いので面の外に書いてある (`Support/Processing.swift`)。
final class Array2D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Array 2D")

    private var distances: [[Float]] = []
    private var maxDistance: Float = 0
    private var spacer = 0

    func setup() {
        maxDistance = dist(width / 2, height / 2, width, height)
        distances = (0..<Int(width)).map { x in
            (0..<Int(height)).map { y in
                dist(width / 2, height / 2, Float(x), Float(y)) / maxDistance * 255
            }
        }
        spacer = 10
        strokeWeight(6)
        noLoop()
    }

    func draw() {
        background(0)
        // 飛ばしながら読むので、配列に入っている値より描く点のほうが少ない
        for y in stride(from: 0, to: Int(height), by: spacer) {
            for x in stride(from: 0, to: Int(width), by: spacer) {
                stroke(distances[x][y])
                point(Float(x + spacer / 2), Float(y + spacer / 2))
            }
        }
    }
}
