import mokume

/// Processing の [Keyboard Functions](https://processing.org/examples/keyboardfunctions/) を 1 行ずつ移したもの。
/// 原典は Martin Gomez 作。
///
/// **台帳は `bend` と言い、`v0.5.0` ではここで止まっていた。`v0.6.0` で動く。**
/// `Keyboard` と同じくキーの出来事を受ける口が入った ([#723](https://github.com/mokume-metal/mokume/issues/723))。
///
/// **残る歪みは `colorMode(HSB, numChars)` の目盛りである。** 色相・彩度・明度で色を作る口は
/// 入ったが ([#778](https://github.com/mokume-metal/mokume/issues/778))、目盛りは 360/100/100 に
/// 固定で、原典のように 0〜26 で数え直す口は無い。呼ぶ側で畳む。
///
/// **`background(numChars/2)` は色相ではなくグレースケールである** — Processing の
/// 1 引数の色は `colorMode` の第 1 引数で割った灰色になる (`13 / 26 = 0.5`)。
/// 移植は長らくこれを色相として読んでいて、面がシアンになっていた
/// ([works#16](https://github.com/mokume-metal/works/issues/16))。
final class KeyboardFunctions: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Keyboard Functions")

    private let maxHeight: Float = 40
    private let minHeight: Float = 20
    private var letterHeight: Float = 40    // 文字の高さ
    private let letterWidth: Float = 20     // 文字の幅
    private var x: Float = -20              // 文字の横の位置
    private var y: Float = 0                // 文字の縦の位置
    private var newletter = false
    private let numChars = 26               // アルファベットは 26 文字
    private var colors: [LinearRGBA] = []

    /// 原典の `colorMode(HSB, numChars)` のもとでの中間の灰 (`numChars / 2`)。
    /// **1 引数は色相ではなくグレースケール**なので、`13 / 26 = 0.5` を 0…255 へ畳む。
    private let midGray: Float = 255 / 2

    func setup() {
        noStroke()
        // 原典はここで `colorMode(HSB, numChars)` を呼ぶ。**目盛りを張り替える口は無い**
        background(midGray)
        // キーごとに色相を決める。原典の `color(i, numChars, numChars)` は
        // 目盛り 26 のもとでの (色相 i・彩度と明度は最大) なので、360/100/100 へ畳む
        colors = (0..<numChars).map {
            color(hue: Float($0) / Float(numChars) * 360, saturation: 100, brightness: 100)
        }
    }

    func draw() {
        if newletter == true {
            let yPos: Float
            if letterHeight == maxHeight {
                yPos = y
                rect(x, yPos, letterWidth, letterHeight)
            } else {
                yPos = y + minHeight
                rect(x, yPos, letterWidth, letterHeight)
                fill(midGray)
                rect(x, yPos - minHeight, letterWidth, letterHeight)
            }
            newletter = false
        }
    }

    /// 原典の `void keyPressed()`。**綴りも中身も原典と同じ。**
    func keyPressed() {
        // 大文字は背の高い文字、小文字は背の低い文字。それ以外は黒
        if let scalar = key.unicodeScalars.first, ("A"..."Z").contains(scalar) {
            letterHeight = maxHeight
            fill(colors[Int(scalar.value - UnicodeScalar("A").value)])
        } else if let scalar = key.unicodeScalars.first, ("a"..."z").contains(scalar) {
            letterHeight = minHeight
            fill(colors[Int(scalar.value - UnicodeScalar("a").value)])
        } else {
            fill(0)
            letterHeight = 10
        }

        newletter = true

        // 文字の位置を進める
        x = x + letterWidth

        // 横に折り返す
        if x > width - letterWidth {
            x = 0
            y += maxHeight
        }

        // 縦に折り返す
        if y > height - letterHeight {
            y = 0
        }
    }
}
