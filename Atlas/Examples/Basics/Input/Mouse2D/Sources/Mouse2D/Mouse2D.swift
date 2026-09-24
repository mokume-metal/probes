import mokume

/// Processing の [Mouse 2D](https://processing.org/examples/mouse2d/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` (mokume の語彙だけで書ける) と言った。外れている。**
/// `background` も `fill` も名前は当たるが、原典が数を 1 つ (`background(51)`) と
/// 2 つ (`fill(255, 204)`) で渡すところに対応する形が無く、どちらも 3 つ + 透かしで
/// 書き下すことになる。**名前しか見ていない台帳には、この違いが写らない。**
/// Ring が `background(0)` で踏んだのと同じ場所である。
final class Mouse2D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse 2D")

    /// 原典の `background(51)`。**数値 1 つの灰色が書けない**
    private static let ground = LinearRGBA.display(red: 51 / 255, green: 51 / 255, blue: 51 / 255)

    /// 原典の `fill(255, 204)`。**数値 2 つ (明るさ + 透かし) も書けない**
    private static let ink = LinearRGBA.display(red: 1, green: 1, blue: 1, alpha: 204 / 255)

    func setup() {
        noStroke()
        rectMode(.center)
    }

    func draw() {
        background(Self.ground)
        fill(Self.ink)
        rect(mouseX, height / 2, mouseY / 2 + 10, mouseY / 2 + 10)
        fill(Self.ink)
        // **原典は int で受けるので、ここの割り算は端数が落ちる。** mokume の座標は
        // Float なので落ちない。Java の型の都合であって Processing の語彙ではないので、
        // 原典の `int` を写していない (Ring が WEBGL 由来の translate を落としたのと同じ判断)
        let inverseX = width - mouseX
        let inverseY = height - mouseY
        rect(inverseX, height / 2, inverseY / 2 + 10, inverseY / 2 + 10)
    }
}
