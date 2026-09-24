import mokume

extension Entries {
    static let shape: [Entry] = [
        Entry(section: .shape, reference: "point()", verdict: .same, mokume: "point(x, y)",
              tile: .picture { c, _ in
                  c.strokeWeight(8)
                  for i in 0..<5 { c.point(16 + Float(i) * 16, m) }
              }),
        Entry(section: .shape, reference: "line()", verdict: .same, mokume: "line(x1, y1, x2, y2)",
              tile: .picture { c, _ in c.line(10, 10, s - 10, s - 10) }),
        Entry(section: .shape, reference: "rect()", verdict: .same, mokume: "rect(x, y, w, h)",
              tile: .picture { c, _ in c.rect(16, 24, 64, 48) }),
        Entry(section: .shape, reference: "rect(x, y, w, h, r)", verdict: .write, mokume: "roundedRect (Support)",
              note: "角を丸める 5〜8 番目の引数が無い。quadraticVertex で書けるが、角は円弧でなく 2 次曲線になる",
              tile: .picture { c, _ in c.roundedRect(16, 24, 64, 48, 14) }),
        Entry(section: .shape, reference: "square()", verdict: .same, mokume: "square(x, y, s)",
              tile: .picture { c, _ in c.square(24, 24, 48) }),
        Entry(section: .shape, reference: "ellipse() / circle()", verdict: .same, mokume: "ellipse / circle",
              tile: .picture { c, _ in
                  c.ellipse(34, m, 44, 64)
                  c.circle(70, m, 36)
              }),
        Entry(section: .shape, reference: "arc()", verdict: .same, mokume: "arc(x, y, w, h, start, stop)",
              tile: .picture { c, _ in c.arc(m, m, 70, 70, 0, 4) }),
        Entry(section: .shape, reference: "arc(…, PIE / CHORD / OPEN)", verdict: .none, mokume: "—",
              note: "閉じ方の 7 番目の引数が無い。扇 (PIE) の形しか描けない",
              tile: .absent),
        Entry(section: .shape, reference: "triangle()", verdict: .same, mokume: "triangle(…)",
              tile: .picture { c, _ in c.triangle(m, 12, s - 12, s - 16, 12, s - 16) }),
        Entry(section: .shape, reference: "quad()", verdict: .same, mokume: "quad(…)",
              tile: .picture { c, _ in c.quad(20, 16, s - 12, 28, s - 24, s - 16, 12, s - 30) }),
        Entry(section: .shape, reference: "bezier()", verdict: .write, mokume: "bezier (Support)",
              note: "1 行で曲線を描く口が無い。beginShape + bezierVertex の 4 行になる",
              tile: .picture { c, _ in
                  c.noFill()
                  c.bezier(10, 80, 20, 0, 76, 96, 86, 16)
              }),
        Entry(section: .shape, reference: "curve()", verdict: .write, mokume: "curve (Support)",
              note: "1 行で描く口が無い。curveVertex 4 つで書く",
              tile: .picture { c, _ in
                  c.noFill()
                  c.curve(0, 96, 16, 70, 80, 26, 96, 0)
              }),
        Entry(section: .shape, reference: "bezierPoint() / curvePoint()", verdict: .write, mokume: "bezierPoint (Support)",
              note: "曲線の上の点・接線を返す口が無い",
              tile: .picture { c, _ in
                  c.strokeWeight(6)
                  for i in 0...8 {
                      let t = Float(i) / 8
                      c.point(bezierPoint(10, 20, 76, 86, t), bezierPoint(80, 0, 96, 16, t))
                  }
              }),
        Entry(section: .shape, reference: "beginShape() / vertex()", verdict: .same, mokume: "beginShape / vertex / endShape(.close)",
              tile: .picture { c, _ in
                  c.beginShape()
                  for i in 0..<5 {
                      let a = Float(i) * 2 * .pi / 5 - .pi / 2
                      c.vertex(m + 38 * cos(a), m + 38 * sin(a))
                  }
                  c.endShape(.close)
              }),
        Entry(section: .shape, reference: "beginShape(TRIANGLE_STRIP)", verdict: .renamed, mokume: "beginShape(.triangleStrip)",
              note: "POINTS / LINES / TRIANGLES / TRIANGLE_FAN も同じ形",
              tile: .picture { c, _ in
                  c.beginShape(.triangleStrip)
                  for i in 0..<8 {
                      c.vertex(10 + Float(i) * 11, i % 2 == 0 ? 24 : 72)
                  }
                  c.endShape()
              }),
        Entry(section: .shape, reference: "beginShape(QUADS / QUAD_STRIP)", verdict: .bend, mokume: "beginShape(.triangles)",
              note: "四角の並べ方が無い。2 枚の三角形に割って並べ直す。works の 5 作品が同じ割り方を手で書いている (mokume#902 は実需待ちで閉じていた)", issue: "mokume#1551",
              tile: .picture { c, _ in
                  c.beginShape(.triangles)
                  for (x, y, w, h): (Float, Float, Float, Float) in [(12, 12, 30, 30), (54, 54, 30, 30)] {
                      c.vertex(x, y); c.vertex(x + w, y); c.vertex(x + w, y + h)
                      c.vertex(x, y); c.vertex(x + w, y + h); c.vertex(x, y + h)
                  }
                  c.endShape()
              }),
        Entry(section: .shape, reference: "beginContour()", verdict: .same, mokume: "beginContour / endContour",
              tile: .picture { c, _ in
                  c.beginShape()
                  c.vertex(12, 12); c.vertex(84, 12); c.vertex(84, 84); c.vertex(12, 84)
                  c.beginContour()
                  c.vertex(34, 34); c.vertex(34, 62); c.vertex(62, 62); c.vertex(62, 34)
                  c.endContour()
                  c.endShape(.close)
              }),
        Entry(section: .shape, reference: "bezierVertex() / quadraticVertex()", verdict: .same, mokume: "bezierVertex / quadraticVertex",
              tile: .picture { c, _ in
                  c.beginShape()
                  c.vertex(12, 80)
                  c.quadraticVertex(m, -20, 84, 80)
                  c.endShape(.close)
              }),
        Entry(section: .shape, reference: "curveVertex()", verdict: .same, mokume: "curveVertex",
              tile: .picture { c, _ in
                  c.noFill()
                  c.beginShape()
                  for (x, y): (Float, Float) in [(10, 80), (10, 80), (34, 20), (62, 70), (86, 16), (86, 16)] {
                      c.curveVertex(x, y)
                  }
                  c.endShape()
              }),
        Entry(section: .shape, reference: "rectMode(CENTER)", verdict: .renamed, mokume: "rectMode(.center)",
              note: "ellipseMode / imageMode も同じ ShapeMode",
              tile: .picture { c, _ in
                  c.rectMode(.center)
                  c.rect(m, m, 56, 40)
              }),
        Entry(section: .shape, reference: "strokeWeight()", verdict: .same, mokume: "strokeWeight",
              tile: .picture { c, _ in
                  for i in 0..<4 {
                      c.strokeWeight(Float(i * 3 + 1))
                      c.line(12, 16 + Float(i) * 20, s - 12, 16 + Float(i) * 20)
                  }
              }),
        Entry(section: .shape, reference: "strokeCap() / strokeJoin()", verdict: .renamed, mokume: "strokeCap(.round) / strokeJoin(.bevel)",
              tile: .picture { c, _ in
                  c.strokeWeight(12)
                  c.strokeCap(.round)
                  c.line(20, 24, 76, 24)
                  c.noFill()
                  c.strokeJoin(.bevel)
                  c.beginShape()
                  c.vertex(20, 84); c.vertex(m, 44); c.vertex(76, 84)
                  c.endShape()
              }),
        Entry(section: .shape, reference: "noSmooth()", verdict: .none, mokume: "—",
              note: "縁の均しを切る口が無い (Atlas の Pixelate ほかで踏んだ)",
              tile: .absent),
        Entry(section: .shape, reference: "createShape() / shape()", verdict: .renamed, mokume: "createShape { … } / shape(_:x:y:)",
              note: "形を組む手順を閉包で渡す。PShape の子 (getChild / addChild) や setFill は無い",
              tile: .picture { c, _ in
                  let star = c.createShape {
                      c.beginShape()
                      for i in 0..<10 {
                          let a = Float(i) * .pi / 5, rr: Float = i % 2 == 0 ? 36 : 16
                          c.vertex(rr * cos(a), rr * sin(a))
                      }
                      c.endShape(.close)
                  }
                  c.shape(star, m, m)
              }),
    ]
}
