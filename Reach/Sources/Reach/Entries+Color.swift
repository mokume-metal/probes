import mokume

extension Entries {
    static let colors: [Entry] = [
        Entry(section: .color, reference: "background() / fill() / stroke()", verdict: .same, mokume: "同名。1〜4 個の数",
              note: "目盛りは 0–255 で手本と同じ。混ぜる空間は線形なので、半透明の重ねは手本と色が違う",
              tile: .picture { c, _ in
                  c.background(40, 60, 90)
                  c.fill(255, 204)
                  c.stroke(20, 200, 120)
                  c.rect(16, 16, 64, 64)
              }),
        Entry(section: .color, reference: "noFill() / noStroke()", verdict: .same, mokume: "noFill() / noStroke()",
              tile: .picture { c, _ in
                  c.noFill()
                  c.circle(34, m, 40)
                  c.fill(235, 120, 60)
                  c.noStroke()
                  c.circle(66, m, 40)
              }),
        Entry(section: .color, reference: "color() / \"#ff8800\"", verdict: .renamed, mokume: "color(r, g, b) / color(hex: 0xff8800)",
              note: "文字列の色は受けない (mokume#745 で実需待ち)", issue: "mokume#745",
              tile: .picture { c, _ in
                  c.fill(color(hex: 0xff8800))
                  c.rect(12, 12, 36, 72)
                  c.fill(color(40, 200, 160))
                  c.rect(48, 12, 36, 72)
              }),
        Entry(section: .color, reference: "fill(rgb, alpha)", verdict: .write, mokume: "fill(color, alpha) (Support)",
              note: "Processing の、色の値 1 つに不透明度を添える形が無い (手本は色の不透明度に alpha / 255 を掛ける)。works の 2 作品が色を薄める口を手で書いている", issue: "mokume#1553",
              tile: .picture { c, _ in
                  c.noStroke()
                  let ink = color(235, 120, 60)
                  for i in 0..<4 {
                      c.fill(ink, Float(i + 1) * 60)
                      c.rect(8 + Float(i) * 20, 20, 20, 56)
                  }
              }),
        Entry(section: .color, reference: "red() / hue() / brightness()", verdict: .same, mokume: "red / green / blue / alpha / hue / saturation / brightness",
              tile: .value { _ in
                  let c = color(255, 136, 0)
                  return "r\(Int(red(c))) h\(Int(hue(c)))"
              }),
        Entry(section: .color, reference: "colorMode(HSB)", verdict: .bend, mokume: "color(hue:saturation:brightness:)",
              note: "目盛りを張り替える口は持たないと決めている (mokume ADR-0033 決定 4)。HSB で書く行ごとにラベルを付ける",
              tile: .picture { c, _ in
                  c.noStroke()
                  for i in 0..<8 {
                      c.fill(color(hue: Float(i) * 45, saturation: 80, brightness: 95))
                      c.rect(Float(i) * 12, 0, 12, s)
                  }
              }),
        Entry(section: .color, reference: "lerpColor()", verdict: .write, mokume: "lerpColor (Support)",
              note: "面に無い。混ぜる空間が違うので、書いても中間色は手本と変わる。works の 2 作品が手で書いている (mokume#745 は実需待ちで閉じていた)", issue: "mokume#1552",
              tile: .picture { c, _ in
                  c.noStroke()
                  let (a, b) = (color(230, 60, 40), color(40, 110, 230))
                  for i in 0..<8 {
                      c.fill(lerpColor(a, b, Float(i) / 7))
                      c.rect(Float(i) * 12, 0, 12, s)
                  }
              }),
        Entry(section: .color, reference: "clear()", verdict: .renamed, mokume: "background(LinearRGBA.transparent)",
              tile: .picture { c, _ in
                  c.background(LinearRGBA.transparent)
                  c.circle(m, m, 50)
              }),
        Entry(section: .color, reference: "erase() / noErase()", verdict: .none, mokume: "—",
              note: "描いたところを透明へ抜く口が無い。blendMode(.replace) の α 0 は mokume#1542 で不具合として扱われている",
              tile: .absent),
        Entry(section: .color, reference: "blendMode(ADD)", verdict: .renamed, mokume: "blendMode(.add)",
              note: "BLEND / ADD / MULTIPLY / SCREEN / DIFFERENCE ほか 10 種",
              tile: .picture { c, _ in
                  c.background(0)
                  c.noStroke()
                  c.blendMode(.add)
                  c.fill(200, 40, 40); c.circle(38, 40, 50)
                  c.fill(40, 200, 40); c.circle(58, 40, 50)
                  c.fill(40, 40, 200); c.circle(48, 60, 50)
              }),
    ]

    static let transform: [Entry] = [
        Entry(section: .transform, reference: "translate() / rotate()", verdict: .same, mokume: "translate / rotate",
              tile: .picture { c, _ in
                  c.translate(m, m)
                  c.rotate(0.5)
                  c.rectMode(.center)
                  c.rect(0, 0, 50, 30)
              }),
        Entry(section: .transform, reference: "scale(x, y)", verdict: .same, mokume: "scale(x, y)",
              tile: .picture { c, _ in
                  c.scale(2, 1)
                  c.circle(24, m, 30)
              }),
        Entry(section: .transform, reference: "scale(s)", verdict: .write, mokume: "scale(s, s)",
              note: "引数 1 つの一様な拡大が無い",
              tile: .picture { c, _ in
                  c.scale(2, 2)
                  c.circle(24, 24, 30)
              }),
        Entry(section: .transform, reference: "shearX() / shearY()", verdict: .same, mokume: "shearX / shearY",
              tile: .picture { c, _ in
                  c.shearX(0.5)
                  c.rect(8, 20, 40, 56)
              }),
        Entry(section: .transform, reference: "applyMatrix()", verdict: .renamed, mokume: "applyMatrix(Transform)",
              note: "6 つ / 16 個の数ではなく、Transform の値を組んで渡す",
              tile: .picture { c, _ in
                  var t = Transform.identity
                  t.translate(x: m, y: m)
                  t.rotate(by: 0.8)
                  c.applyMatrix(t)
                  c.rectMode(.center)
                  c.rect(0, 0, 50, 30)
              }),
        Entry(section: .transform, reference: "resetMatrix()", verdict: .same, mokume: "resetMatrix()",
              tile: .picture { c, _ in
                  c.translate(500, 500)
                  c.resetMatrix()
                  c.rect(20, 20, 56, 56)
              }),
    ]
}
