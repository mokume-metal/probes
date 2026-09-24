import mokume

/// Processing の [Color Variables](https://processing.org/examples/colorvariables/) を 1 行ずつ移したもの。
///
/// **台帳は `renamed` と言った (`color` → `LinearRGBA.display`)。当たっている。**
/// 原典が代わりに書ける `#CC6600` の形も、面の外に `hex()` を書けば届く。原典は静止形。
final class ColorVariables: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Color Variables")

    func setup() {
        noStroke()
        background(51, 0, 0)

        let inside = color(204, 102, 0)
        let middle = color(204, 153, 0)
        let outside = color(153, 51, 0)

        // 原典は下の書き方も等価だと言う (hex() で同じものが書ける)
        //   let inside = hex(0xCC6600)

        pushMatrix()
        translate(80, 80)
        fill(outside)
        rect(0, 0, 200, 200)
        fill(middle)
        rect(40, 60, 120, 120)
        fill(inside)
        rect(60, 90, 80, 80)
        popMatrix()

        pushMatrix()
        translate(360, 80)
        fill(inside)
        rect(0, 0, 200, 200)
        fill(outside)
        rect(40, 60, 120, 120)
        fill(middle)
        rect(60, 90, 80, 80)
        popMatrix()
    }
}
