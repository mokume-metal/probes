import mokume

/// Processing の [Points and Lines](https://processing.org/examples/pointslines/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** 原典の主題は `noSmooth()` — 均さずに
/// 点と線を置くことで、**画素そのものを見せる**例である。mokume に均しを切る口が無いので、
/// その 1 行が落ちる。原典は静止形。
final class PointsLines: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Points and Lines")

    func setup() {
        let d: Float = 70
        let p1 = d
        let p2 = p1 + d
        let p3 = p2 + d
        let p4 = p3 + d

        // 原典はここで `noSmooth()` を呼ぶ。**書けない** — 均しを切る口が無い
        background(0)
        translate(140, 0)
        stroke(153)
        line(p3, p3, p2, p3)
        line(p2, p3, p2, p2)
        line(p2, p2, p3, p2)
        line(p3, p2, p3, p3)
        stroke(255)
        point(p1, p1)
        point(p1, p3)
        point(p2, p4)
        point(p3, p1)
        point(p4, p2)
        point(p4, p4)
    }
}
