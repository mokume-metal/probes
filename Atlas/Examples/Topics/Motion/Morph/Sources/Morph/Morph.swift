import Foundation
import mokume
import Support

/// Processing の [Morph](https://processing.org/examples/morph/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている。** 原典は `PVector` を持ち回り、
/// `PVector.fromAngle` / `mult` / `lerp` / `PVector.dist` を呼ぶ。mokume に
/// `PVector` は無く `SIMD2<Float>` で書けるが、**その 4 つに当たるメソッドは
/// どれも無い**ので、演算子と面の外の関数で書き直すことになる。
/// 原典の「ベクトルに頼んで動かす」という書き味が、こちらでは消える。
final class Morph: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Morph")

    private var circle: [SIMD2<Float>] = []
    private var square: [SIMD2<Float>] = []
    private var morph: [SIMD2<Float>] = []
    private var state = false

    func setup() {
        // 中心から伸ばしたベクトルで円を作る
        for angle in stride(from: 0, to: 360, by: 9) {
            // 円の道すじに合わせるため 0 からは始めない
            let a = radians(Float(angle) - 135)
            // 原典は `PVector.fromAngle(a)` と `v.mult(100)` の 2 行
            circle.append(SIMD2(cos(a), sin(a)) * 100)
            morph.append(SIMD2(0, 0))
        }
        // 四角は直線に沿って並べた頂点の集まり
        for x in stride(from: Float(-50), to: 50, by: 10) { square.append(SIMD2(x, -50)) }
        for y in stride(from: Float(-50), to: 50, by: 10) { square.append(SIMD2(50, y)) }
        for x in stride(from: Float(50), to: -50, by: -10) { square.append(SIMD2(x, 50)) }
        for y in stride(from: Float(50), to: -50, by: -10) { square.append(SIMD2(-50, y)) }
    }

    func draw() {
        background(51)
        // 目標からどれだけ離れているか
        var totalDistance: Float = 0

        for i in circle.indices {
            let v1 = state ? circle[i] : square[i]
            // 原典は `v2.lerp(v1, 0.1)` の 1 行。**lerp を持つ型が無い**
            morph[i] += (v1 - morph[i]) * 0.1
            // 原典は `PVector.dist(v1, v2)`
            totalDistance += dist(v1.x, v1.y, morph[i].x, morph[i].y)
        }

        // 全部の頂点が近づいたら形を切り替える
        if totalDistance < 0.1 { state = !state }

        translate(width / 2, height / 2)
        strokeWeight(4)
        beginShape()
        noFill()
        stroke(255)
        for v in morph { vertex(v.x, v.y) }
        endShape(.close)
    }
}
