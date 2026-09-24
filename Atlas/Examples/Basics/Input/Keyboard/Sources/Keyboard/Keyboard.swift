import mokume
import Support

/// Processing の [Keyboard](https://processing.org/examples/keyboard/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` ではここで止まっていた。`v0.6.0` で動く。**
/// 原典は `draw()` を空にしておき、**中身をすべて `keyPressed()` に書く**例である。
/// キーの出来事を受ける口が無かったので ([#723](https://github.com/mokume-metal/mokume/issues/723))、
/// 面は背景の黒のまま残していた。`v0.6.0` が同じ綴りの `keyPressed()` を入れたので、
/// 原典の形のまま移せるようになった。
///
/// 押しっぱなしのキーは、原典と同じく連射する。
final class Keyboard: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Keyboard")

    private var rectWidth: Float = 0

    func setup() {
        noStroke()
        background(0)
        rectWidth = width / 4
    }

    func draw() {
        // 原典もここは空。キーを待つあいだ回し続けるためだけに置かれている
    }

    /// 原典の `void keyPressed()`。**綴りも中身も原典と同じ。**
    func keyPressed() {
        // 原典の `key >= 'A' && key <= 'Z'`。**`key` は文字 1 つではなく `String`** なので、
        // 先頭のスカラを取ってから比べる (押されていなければ空になる)
        var keyIndex = -1
        if let scalar = key.unicodeScalars.first {
            switch scalar {
            case "A"..."Z": keyIndex = Int(scalar.value - UnicodeScalar("A").value)
            case "a"..."z": keyIndex = Int(scalar.value - UnicodeScalar("a").value)
            default: break
            }
        }

        if keyIndex == -1 {
            // 文字のキーでなければ面を消す
            background(0)
        } else {
            // 文字のキーなら矩形を 1 つ塗る。
            // **壁時計は面に無い**ので `millis()` は面の外に書いてある (`Support/Processing.swift`)
            fill(millis().truncatingRemainder(dividingBy: 255))
            let x = map(Float(keyIndex), 0, 25, 0, width - rectWidth)
            rect(x, 0, rectWidth, height)
        }
    }
}
