import Foundation
import mokume

// 手本にあって mokume の面に無い口のうち、**面の外に書けば済むもの** (`write`)。
//
// **1 箇所にまとめたのは、数えるため** (Atlas の `Sources/Support/Processing.swift` と同じ)。
// このファイルの長さが、そのまま「よく使う口を書くのに mokume の外へどれだけ書き足すか」の
// 答えになる。**面に足りないものを面へ足しているわけではない** — 書けないもの (`none`) は
// ここに入れず、タイルに「無い」と刷って止まった形で残す。

// MARK: - 時計

/// 手本の `second()` / `minute()` / `hour()` / `day()` / `month()` / `year()`。
/// 壁時計の値は Foundation が持っている。mokume に無いのは読む口だけ。
func clockField(_ component: Calendar.Component) -> Int {
    Calendar.current.component(component, from: Date())
}

// MARK: - 形

extension Canvas {
    /// 手本の `curve(x1, y1, x2, y2, x3, y3, x4, y4)` — 1 行で描く Catmull-Rom の区間。
    func curve(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float,
               _ x3: Float, _ y3: Float, _ x4: Float, _ y4: Float) {
        beginShape()
        curveVertex(x1, y1)
        curveVertex(x2, y2)
        curveVertex(x3, y3)
        curveVertex(x4, y4)
        endShape()
    }
}

/// 手本の `curvePoint(a, b, c, d, t)` (張りは既定の 0)。
func curvePoint(_ a: Float, _ b: Float, _ c: Float, _ d: Float, _ t: Float) -> Float {
    let t2 = t * t, t3 = t2 * t
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
}

// MARK: - 画像

/// 手本の `img.mask(other)` (Processing の形 — 覆いの青の表示値を不透明度にする)。
/// **`get` / `set` で画素を移し替えれば書ける** (Atlas と同じ判定)。成分は乗算済みなので、
/// α だけでなく 4 成分を同じ割合で縮める。
func mask(_ image: Image, by other: Image) {
    for y in 0..<min(image.height, other.height) {
        for x in 0..<min(image.width, other.width) {
            let c = image.get(x, y), k = blue(other.get(x, y)) / 255
            image.set(x, y, LinearRGBA(premultipliedRed: c.red * k, green: c.green * k, blue: c.blue * k, alpha: c.alpha * k))
        }
    }
}
