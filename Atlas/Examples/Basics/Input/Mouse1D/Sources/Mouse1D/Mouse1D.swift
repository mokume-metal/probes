import mokume

/// Processing の [Mouse 1D](https://processing.org/examples/mouse1d/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。**`colorMode(RGB, height, height, height)` で
/// 目盛りを 0〜360 に張り替える 1 行が書けないので、書く側で 255 へ畳む。
final class Mouse1D: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Mouse 1D")

    func setup() {
        noStroke()
        // 原典はここで `colorMode(RGB, height, height, height)` を呼ぶ。**書けない**
        rectMode(.center)
    }

    func draw() {
        background(0)
        let r1 = map(mouseX, 0, width, 0, height)
        let r2 = height - r1

        fill(r1 / height * 255)
        rect(width / 2 + r1 / 2, height / 2, r1, r1)

        fill(r2 / height * 255)
        rect(width / 2 - r2 / 2, height / 2, r2, r2)
    }
}
