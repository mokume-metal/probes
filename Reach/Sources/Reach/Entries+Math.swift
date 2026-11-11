import Foundation
import mokume

extension Entries {
    static let math: [Entry] = [
        Entry(section: .math, reference: "random() / randomSeed()", verdict: .same, mokume: "random(low, high) / randomSeed",
              tile: .picture { c, r in
                  r.randomSeed(7)
                  c.strokeWeight(5)
                  for _ in 0..<40 { c.point(r.random(8, 88), r.random(8, 88)) }
              }),
        Entry(section: .math, reference: "random(array)", verdict: .same, mokume: "random(choices)",
              note: "Optional で返る (空なら nil)。randomSeed の列に乗る。v0.45.0 までに入った",
              tile: .value { r in r.random(["a", "b", "c"]) ?? "—" }),
        Entry(section: .math, reference: "randomGaussian()", verdict: .same, mokume: "randomGaussian() / randomGaussian(mean, sd)",
              note: "random() と同じ列から引き、randomSeed に乗る。v0.45.0 までに入った",
              tile: .picture { c, r in
                  r.randomSeed(3)
                  c.strokeWeight(4)
                  for _ in 0..<80 { c.point(m + r.randomGaussian(0, 14), m + r.randomGaussian(0, 14)) }
              }),
        Entry(section: .math, reference: "noise() / noiseSeed() / noiseDetail()", verdict: .same, mokume: "noise(x, y, z) / noiseSeed / noiseDetail",
              tile: .picture { c, _ in
                  c.noFill()
                  c.beginShape()
                  for i in 0...48 { c.vertex(Float(i) * 2, 16 + 64 * c.noise(Float(i) * 0.08)) }
                  c.endShape()
              }),
        Entry(section: .math, reference: "map() / constrain() / lerp()", verdict: .same, mokume: "map / constrain / lerp",
              note: "constrain / lerp は v0.11.0 で入った",
              tile: .picture { c, _ in
                  c.noStroke()
                  for i in 0..<8 {
                      let x = map(Float(i), 0, 7, 8, 80)
                      c.circle(x, constrain(lerp(20, 90, Float(i) / 7), 20, 76), 10)
                  }
              }),
        Entry(section: .math, reference: "dist() / mag()", verdict: .same, mokume: "dist / mag",
              note: "2D と 3D の両方。Vector2・Vector3 を渡す形もある。v0.45.0 までに入った",
              tile: .picture { c, _ in
                  c.noStroke()
                  for y in stride(from: Float(4), to: s, by: 8) {
                      for x in stride(from: Float(4), to: s, by: 8) where dist(x, y, m, m) < 40 {
                          c.circle(x, y, 5)
                      }
                  }
              }),
        Entry(section: .math, reference: "sq() / norm()", verdict: .same, mokume: "sq / norm",
              note: "norm は v0.14.0 で入った (smoothstep も)。sq も v0.45.0 までに入った",
              tile: .value { _ in "\(Int(sq(7))) \(norm(5, 0, 10))" }),
        Entry(section: .math, reference: "abs() / floor() / pow() / sqrt()", verdict: .same, mokume: "abs / floor / pow / sqrt",
              note: "pow・sqrt・exp・log・floor・ceil・round はアンブレラが通すので Foundation は要らない (sin / cos と同じ扱い)。abs は Swift の標準",
              tile: .value { _ in "\(abs(-3)) \(floor(2.7)) \(pow(2.0, 5.0))" }),
        Entry(section: .math, reference: "sin() / cos() / atan2()", verdict: .same, mokume: "sin / cos / tan / asin / acos / atan / atan2",
              note: "アンブレラが名指しで通す 7 本 (mokume ADR-0020 決定 7)",
              tile: .picture { c, _ in
                  c.noFill()
                  c.beginShape()
                  for i in 0...48 { c.vertex(Float(i) * 2, m + 30 * sin(Float(i) * 0.26)) }
                  c.endShape()
              }),
        Entry(section: .math, reference: "radians() / degrees()", verdict: .same, mokume: "radians / degrees",
              tile: .picture { c, _ in c.arc(m, m, 70, 70, 0, radians(270)) }),
        Entry(section: .math, reference: "PI / TWO_PI / HALF_PI", verdict: .same, mokume: "PI / TWO_PI / HALF_PI",
              note: "QUARTER_PI・TAU もある。v0.45.0 までに入った",
              tile: .value { _ in String(format: "%.4f", TWO_PI) }),
        Entry(section: .math, reference: "angleMode(DEGREES)", verdict: .drop, mokume: "—",
              note: "持たないと決めている。単位は呼んだ 1 行から読めるべき (mokume ADR-0020 決定 7 の改訂)",
              tile: .value { _ in "radians only" }),
        Entry(section: .math, reference: "createVector() / PVector", verdict: .renamed, mokume: "Vector2(x, y) / Vector3(x, y, z)",
              note: "Processing の PVector に当たる型。add / mult は演算子で書く。v0.45.0 までに入った",
              tile: .picture { c, _ in
                  var p = Vector2(m, m)
                  p += Vector2(angle: 0.6, length: 30)
                  c.line(m, m, p.x, p.y)
                  c.circle(p.x, p.y, 10)
              }),
        Entry(section: .math, reference: "PVector.normalize() / limit() / heading()", verdict: .renamed, mokume: "normalized() / limited(to:) / angle / rotated(by:) / length",
              note: "Vector2 のメソッド。setMag は無い (normalized() * n で書く)。v0.45.0 までに入った",
              tile: .picture { c, _ in
                  for i in 0..<6 {
                      let v = Vector2(1, 0).rotated(by: Float(i) * .pi / 3).normalized().limited(to: 36)
                      c.line(m, m, m + v.x * 36, m + v.y * 36)
                      _ = v.angle
                  }
              }),
        Entry(section: .math, reference: "nf() / str() / int()", verdict: .host, mokume: "String(format:) / String() / Int()",
              tile: .value { _ in String(format: "%03d", 7) }),
        Entry(section: .math, reference: "shuffle() / sort() / append()", verdict: .host, mokume: "Array の shuffled / sorted / append",
              note: "shuffle だけは mokume にも入った (randomSeed の列に乗る)。sort / append は Swift のまま",
              tile: .value { _ in "\([3, 1, 2].sorted())" }),
    ]
}
