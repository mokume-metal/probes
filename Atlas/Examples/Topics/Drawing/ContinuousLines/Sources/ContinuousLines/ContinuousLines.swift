import mokume

/// Processing の [Continuous Lines](https://processing.org/examples/continuouslines/) を移したもの。
///
/// **台帳は `clean` と言った。外れている。** 原典の `mousePressed` は関数ではなく
/// **変数**で、呼び出しの形をしていないので語彙の抽出に乗らなかった。mokume では
/// `isMousePressed` — 口はあるが名前が違う (`renamed`)。
///
/// **そしてこの例は、前のフレームの絵が残ることに賭けている。** 原典は `setup()` で
/// 一度だけ背景を塗り、`draw()` では塗らないので、引いた線がそのまま溜まっていく。
final class ContinuousLines: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Continuous Lines")

    /// 原典の `background(102)`
    private static let ground = LinearRGBA.display(red: 102 / 255, green: 102 / 255, blue: 102 / 255)

    /// 原典の `stroke(255)`
    private static let ink = LinearRGBA.display(red: 1, green: 1, blue: 1)

    func setup() {
        background(Self.ground)
    }

    func draw() {
        stroke(Self.ink)
        if isMousePressed {
            line(mouseX, mouseY, pmouseX, pmouseY)
        }
    }
}
