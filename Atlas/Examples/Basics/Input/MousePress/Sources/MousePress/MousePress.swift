import mokume

/// Processing の [Mouse Press](https://processing.org/examples/mousepress/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。`v0.6.0` でも当たっている。歪みは 2 つのまま。**
/// 原典の `mousePressed` は**変数**なので `isMousePressed` に名前が変わり、
/// `noSmooth()` は書けない。
///
/// **[#723](https://github.com/mokume-metal/mokume/issues/723) は閉じたが、この例には効かない** —
/// あれが入れたのは出来事の口 (`mousePressed()`) で、この例が読むのは「いま押されているか」の
/// ほうである。同じ綴りが 2 つのものを指すので、閉じた Issue を見て直ったと読まないこと。
final class MousePress: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse Press")

    func setup() {
        // 原典はここで `noSmooth()` を呼ぶ。**書けない**
        fill(126)
        background(102)
    }

    func draw() {
        if isMousePressed {
            stroke(255)
        } else {
            stroke(0)
        }
        line(mouseX - 66, mouseY, mouseX + 66, mouseY)
        line(mouseX, mouseY - 66, mouseX, mouseY + 66)
    }
}
