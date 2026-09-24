import mokume

/// Processing の [Save One Image](https://processing.org/examples/saveoneimage/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (ファイル入出力が主題)。絵は出る。**
/// `v0.6.0` で `mousePressed()` の口が入った
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた) ので、
/// 「押して書き出す」という主題がそのまま移った (`save()` は `save(_:)` で当たる)。
final class SaveOneImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Save One Image")

    func draw() {
        background(204)
        line(0, 0, mouseX, height)
        line(width, 0, 0, mouseY)
    }

    /// 原典の `void mousePressed()` — 押したら 1 枚書き出す。
    ///
    /// **綴りは `.tif` ではなく `.png`。** 原典は TIFF を書くが、mokume が書けるのは
    /// PNG である (`save(_:)`)。
    func mousePressed() {
        save("line.png")
    }
}
