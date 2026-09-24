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
        Entry(section: .math, reference: "random(array)", verdict: .host, mokume: "array.randomElement()",
              note: "手本の乱数列 (randomSeed) には乗らない",
              tile: .value { _ in ["a", "b", "c"].randomElement()! }),
        Entry(section: .math, reference: "randomGaussian()", verdict: .write, mokume: "randomGaussian (Support)",
              note: "正規分布の乱数が無い。random() から Box–Muller で書く",
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
        Entry(section: .math, reference: "dist() / mag()", verdict: .write, mokume: "dist / mag (Support)",
              note: "面に無い。simd_distance は import simd を要し、アンブレラは通さない",
              tile: .picture { c, _ in
                  c.noStroke()
                  for y in stride(from: Float(4), to: s, by: 8) {
                      for x in stride(from: Float(4), to: s, by: 8) where dist(x, y, m, m) < 40 {
                          c.circle(x, y, 5)
                      }
                  }
              }),
        Entry(section: .math, reference: "sq() / norm()", verdict: .write, mokume: "sq / norm (Support)",
              tile: .value { _ in "\(Int(sq(7))) \(norm(5, 0, 10))" }),
        Entry(section: .math, reference: "abs() / floor() / pow() / sqrt()", verdict: .host, mokume: "Swift の abs / floor / pow / squareRoot",
              note: "floor / pow は Foundation を import する",
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
        Entry(section: .math, reference: "PI / TWO_PI / HALF_PI", verdict: .host, mokume: "Float.pi",
              tile: .value { _ in String(format: "%.4f", Float.pi * 2) }),
        Entry(section: .math, reference: "angleMode(DEGREES)", verdict: .drop, mokume: "—",
              note: "持たないと決めている。単位は呼んだ 1 行から読めるべき (mokume ADR-0020 決定 7 の改訂)",
              tile: .value { _ in "radians only" }),
        Entry(section: .math, reference: "createVector() / PVector", verdict: .bend, mokume: "SIMD2<Float> / SIMD3<Float>",
              note: "型は当たるが、add / mult は演算子で書き、normalize / limit / setMag / heading / fromAngle / rotate は 1 つも無い",
              tile: .picture { c, _ in
                  var p = SIMD2<Float>(m, m)
                  let v = SIMD2<Float>.fromAngle(0.6).withMag(30)
                  p += v
                  c.line(m, m, p.x, p.y)
                  c.circle(p.x, p.y, 10)
              }),
        Entry(section: .math, reference: "PVector.normalize() / limit() / heading()", verdict: .write, mokume: "extension SIMD2 (Support)",
              tile: .picture { c, _ in
                  for i in 0..<6 {
                      let v = SIMD2<Float>(1, 0).rotated(Float(i) * .pi / 3).normalized().limited(36)
                      c.line(m, m, m + v.x * 36, m + v.y * 36)
                      _ = v.heading
                  }
              }),
        Entry(section: .math, reference: "nf() / str() / int()", verdict: .host, mokume: "String(format:) / String() / Int()",
              tile: .value { _ in String(format: "%03d", 7) }),
        Entry(section: .math, reference: "shuffle() / sort() / append()", verdict: .host, mokume: "Array の shuffled / sorted / append",
              tile: .value { _ in "\([3, 1, 2].sorted())" }),
    ]
}
