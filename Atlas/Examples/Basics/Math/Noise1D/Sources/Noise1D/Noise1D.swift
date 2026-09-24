import mokume

/// Processing の [Noise 1D](https://processing.org/examples/noise1d/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// 雑音の数列が原典と違うので、**画素では比べられない。**
final class Noise1D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Noise 1D")

    private var xoff: Float = 0.0
    private let xincrement: Float = 0.01

    func setup() {
        background(0)
        noStroke()
    }

    func draw() {
        // 半透明を重ねて背景を作る
        fill(0, 10)
        rect(0, 0, width, height)

        // xoff から雑音の値を取り、面の幅へ広げる
        let n = noise(xoff) * width

        // 1 周ごとに xoff を進める
        xoff += xincrement

        // パーリン雑音が出した位置へ円を描く
        fill(200)
        ellipse(n, height / 2, 64, 64)
    }
}
