import mokume

/// Processing の [Characters Strings](https://processing.org/examples/charactersstrings/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言い、`v0.5.0` では半分止まっていた。`v0.6.0` で主題が動く。**
/// `keyTyped()` に当たる出来事の口が入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
/// 残る歪みは `createFont` の口が無いことだけで、システムの書体へ置き換えている。
///
/// **`keyTyped()` は文字を生むキーでだけ呼ばれる** (矢印・F キー・Escape・Delete・Tab
/// では呼ばれない)。原典と同じ規則である。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class CharactersStrings: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Characters Strings")

    private var letter = ""
    private var words = "Begin..."

    func setup() {
        // 原典は `textFont(createFont("SourceCodePro-Regular.ttf", 36))`。**書体を読めない**
        textFont("Menlo")
    }

    func draw() {
        background(0)
        textSize(14)
        text("Click on the program, then type to add to the String", 50, 50)
        text("Current key: \(letter)", 50, 70)
        text("The String is \(words.count) characters long", 50, 90)

        textSize(36)
        text(words, 50, 120, 540, 300)
    }

    /// 原典の `void keyTyped()` — 打たれた文字を words へ足す。
    ///
    /// **`key` は文字 1 つではなく `String`** なので、先頭のスカラを取ってから比べる。
    func keyTyped() {
        guard let scalar = key.unicodeScalars.first else { return }
        if ("A"..."z").contains(scalar) || scalar == " " {
            letter = key
            words = words + key
            // 原典はここで `println(key)` を呼ぶ
            print(key)
        }
    }
}
