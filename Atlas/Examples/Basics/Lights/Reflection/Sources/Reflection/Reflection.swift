import mokume

/// Processing の [Reflection](https://processing.org/examples/reflection/) を 1 行ずつ移したもの。
/// 原典は Simon Greenwold 作。
///
/// **台帳は `bend` と言った。実際にはもっと止まっている。** 原典の主題である
/// **鏡のような反射 (`lightSpecular` / `specular`) を書く口が無い。** mokume が持つのは
/// `shininess` と `metalness` で、光の側に色を持たせられない。`colorMode(RGB, 1)` で
/// 目盛りを 0〜1 に張り替える 1 行も書けない。
///
/// **動くように書き替えていない** — 反射の 2 行は落とし、何が無いかをここに残す。
final class Reflection: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Reflection")

    func setup() {
        noStroke()
        // 原典はここで `colorMode(RGB, 1)` を呼ぶ。**書けない**ので 0.4 を 255 段へ畳む
        fill(0.4 * 255)
    }

    func draw() {
        background(0)
        translate(width / 2, height / 2)
        // 原典はここで `lightSpecular(1, 1, 1)` を呼ぶ。**書けない** — 光に鏡の色を持たせられない
        directionalLight(0.8 * 255, 0.8 * 255, 0.8 * 255, 0, 0, -1)
        let s = mouseX / width
        // 原典はここで `specular(s, s, s)` を呼ぶ。**書けない** — 近いのは shininess だが別物
        _ = s
        sphere(120)
    }
}
