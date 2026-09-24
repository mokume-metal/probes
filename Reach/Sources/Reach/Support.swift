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
    /// 手本の `rect(x, y, w, h, r)` — 角の丸い矩形。4 隅を `quadraticVertex` で丸める。
    /// **手本の角は円弧**で、これは 2 次曲線なので、丸みの形がわずかに違う。
    func roundedRect(_ x: Float, _ y: Float, _ w: Float, _ h: Float, _ r: Float) {
        let r = min(r, w / 2, h / 2)
        beginShape()
        vertex(x + r, y)
        vertex(x + w - r, y)
        quadraticVertex(x + w, y, x + w, y + r)
        vertex(x + w, y + h - r)
        quadraticVertex(x + w, y + h, x + w - r, y + h)
        vertex(x + r, y + h)
        quadraticVertex(x, y + h, x, y + h - r)
        vertex(x, y + r)
        quadraticVertex(x, y, x + r, y)
        endShape(.close)
    }

    /// 手本の `bezier(x1, y1, cx1, cy1, cx2, cy2, x2, y2)` — 1 行で描く 3 次曲線。
    func bezier(_ x1: Float, _ y1: Float, _ cx1: Float, _ cy1: Float,
                _ cx2: Float, _ cy2: Float, _ x2: Float, _ y2: Float) {
        beginShape()
        vertex(x1, y1)
        bezierVertex(cx1, cy1, cx2, cy2, x2, y2)
        endShape()
    }

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

/// 手本の `bezierPoint(a, b, c, d, t)`。
func bezierPoint(_ a: Float, _ b: Float, _ c: Float, _ d: Float, _ t: Float) -> Float {
    let u = 1 - t
    return u * u * u * a + 3 * u * u * t * b + 3 * u * t * t * c + t * t * t * d
}

/// 手本の `curvePoint(a, b, c, d, t)` (張りは既定の 0)。
func curvePoint(_ a: Float, _ b: Float, _ c: Float, _ d: Float, _ t: Float) -> Float {
    let t2 = t * t, t3 = t2 * t
    return 0.5 * ((2 * b) + (-a + c) * t + (2 * a - 5 * b + 4 * c - d) * t2 + (-a + 3 * b - 3 * c + d) * t3)
}

// MARK: - 色

/// 手本の `lerpColor(a, b, t)`。**混ぜる空間が違う** — mokume の色は線形の値なので、
/// 手本 (表示値のまま混ぜる) とは中間の色が変わる (mokume ADR-0033 決定 7)。
///
/// **`LinearRGBA` の成分は乗算済み**なので、乗算済みのまま混ぜて乗算済みの口で戻す
/// (Atlas の `Processing.swift` は同じ成分を `straightRed:` へ渡していて、半透明の色で狂う)。
func lerpColor(_ from: LinearRGBA, _ to: LinearRGBA, _ amount: Float) -> LinearRGBA {
    LinearRGBA(
        premultipliedRed: from.red + (to.red - from.red) * amount,
        green: from.green + (to.green - from.green) * amount,
        blue: from.blue + (to.blue - from.blue) * amount,
        alpha: from.alpha + (to.alpha - from.alpha) * amount)
}

extension Canvas {
    /// 手本 (Processing) の `fill(rgb, alpha)` — 色の値 1 つに不透明度 (0–255) を添える。
    /// 手本と同じく**不透明度を置き換える** (元の不透明度には掛けない)。成分は乗算済みなので、
    /// いったん元の不透明度で割ってから新しい不透明度を掛ける。
    func fill(_ color: LinearRGBA, _ alpha: Float) {
        let a = min(max(alpha / 255, 0), 1)
        let k = color.alpha > 0 ? a / color.alpha : 0
        fill(LinearRGBA(premultipliedRed: color.red * k, green: color.green * k, blue: color.blue * k, alpha: a))
    }
}

// MARK: - 画像

/// 手本の `filter(THRESHOLD, level)`。効果 (`Effect`) に閾値が無いので、画素を 1 つずつ書く。
/// 手本と同じく**表示値の明るさ**で分ける (`red()` などは 0–255 の表示値を返す)。
func threshold(_ image: Image, _ level: Float = 0.5) {
    for y in 0..<image.height {
        for x in 0..<image.width {
            let c = image.get(x, y)
            let gray = 0.2126 * red(c) + 0.7152 * green(c) + 0.0722 * blue(c)
            image.set(x, y, color(gray >= level * 255 ? 255 : 0, alpha(c)))
        }
    }
}

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

// MARK: - 数

extension Sketch {
    /// 手本の `randomGaussian(mean, sd)`。`random()` の列から Box–Muller で作る。
    func randomGaussian(_ mean: Float = 0, _ sd: Float = 1) -> Float {
        let u1 = max(random(), .leastNormalMagnitude)
        let u2 = random()
        return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// 手本の `dist(x1, y1, x2, y2)`。
func dist(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> Float {
    ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)).squareRoot()
}

/// 手本の `mag(x, y)`。
func mag(_ x: Float, _ y: Float) -> Float { (x * x + y * y).squareRoot() }

/// 手本の `sq(n)`。
func sq(_ n: Float) -> Float { n * n }

/// 手本の `norm(value, start, stop)` — `map` の 0〜1 版。
func norm(_ value: Float, _ start: Float, _ stop: Float) -> Float { (value - start) / (stop - start) }

/// 手本の `PVector` のメソッドのうち、よく使うもの。**型は `SIMD2<Float>` で当たるが、
/// メソッドが 1 つも無い** (`simd_normalize` などは `import simd` を要し、アンブレラは通さない)。
extension SIMD2<Float> {
    static func fromAngle(_ angle: Float) -> Self { Self(cos(angle), sin(angle)) }
    var mag: Float { (x * x + y * y).squareRoot() }
    var heading: Float { atan2(y, x) }
    func normalized() -> Self { mag == 0 ? self : self / mag }
    func limited(_ max: Float) -> Self { mag > max ? normalized() * max : self }
    func withMag(_ length: Float) -> Self { normalized() * length }
    func rotated(_ angle: Float) -> Self {
        Self(x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle))
    }
}
