import mokume

/// Processing の [No Loop](https://processing.org/examples/noloop/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言い、`v0.7.0` まではここで止まっていた。`v0.9.0` で動く。**
///
/// 原典は `setup()` で `noLoop()` を呼び、`draw()` を 1 度だけ走らせて 1 本の線を引く。
/// 進行を止める口が無かったので `draw()` は毎フレーム呼ばれ、**原典が見せようとしている
/// 「1 度だけ描く」がそのまま消えていた** — 線は上へ流れ、`y` が 0 を切ると下へ戻った。
/// いまは同じ綴りの `noLoop()` が書けるので、線は 1 本引かれたまま止まる
/// ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。
///
/// **`draw()` の中の `y` を減らす 2 行は原典にもある。** 1 度しか走らないので効かないが、
/// 原典がそう書いている以上そのまま残す — 止めるのをやめれば線が流れ出すことが、
/// この例の「1 度だけ」の意味でもある。
final class NoLoop: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "No Loop")

    /// 原典の `background(0)`
    private static let ground = LinearRGBA.display(red: 0, green: 0, blue: 0)

    /// 原典の `stroke(255)`
    private static let ink = LinearRGBA.display(red: 1, green: 1, blue: 1)

    private var y: Float = 180

    func setup() {
        stroke(Self.ink)
        noLoop()
    }

    func draw() {
        background(Self.ground)
        line(0, y, width, y)
        y -= 1
        if y < 0 { y = height }
    }
}
