import mokume

extension Entries {
    static let images: [Entry] = [
        Entry(section: .image, reference: "loadImage()", verdict: .same, mokume: "try loadImage(path)",
              note: "失敗を throws で返す。資材を置かないので、タイルでは画素から作った絵を使う",
              tile: .value { r in
                  unreached { _ = try? r.loadImage("sample.png") }
                  return "loadImage"
              }),
        Entry(section: .image, reference: "image()", verdict: .same, mokume: "image(img, x, y, w, h)",
              tile: .picture { c, r in c.image(r.sample, 16, 16, 64, 64) }),
        Entry(section: .image, reference: "image(img, dx, dy, dw, dh, sx, sy, sw, sh)", verdict: .same, mokume: "同じ 9 引数",
              note: "Processing の copy() もこの形で当たる",
              tile: .picture { c, r in c.image(r.sample, 16, 16, 64, 64, 0, 0, 16, 16) }),
        Entry(section: .image, reference: "imageMode(CENTER)", verdict: .renamed, mokume: "imageMode(.center)",
              tile: .picture { c, r in
                  c.imageMode(.center)
                  c.image(r.sample, m, m, 48, 48)
              }),
        Entry(section: .image, reference: "tint() / noTint()", verdict: .same, mokume: "tint / noTint",
              tile: .picture { c, r in
                  c.tint(255, 80, 80)
                  c.image(r.sample, 8, 24, 40, 40)
                  c.noTint()
                  c.image(r.sample, 48, 24, 40, 40)
              }),
        Entry(section: .image, reference: "createImage()", verdict: .same, mokume: "try createImage(w, h)",
              note: "形式 (RGB / ARGB / ALPHA) の引数は取らない",
              tile: .picture { c, r in
                  let img = try! r.createImage(8, 8)
                  img.fill(color(90, 200, 120))
                  c.image(img, 16, 16, 64, 64)
              }),
        Entry(section: .image, reference: "get() / set()", verdict: .same, mokume: "get(x, y) / set(x, y, c)",
              note: "領域を切り出す get(x, y, w, h) は無い",
              tile: .picture { c, _ in
                  for x in 20..<76 { for y in 44..<52 { c.set(x, y, color(90, 200, 230)) } }
                  _ = c.get(10, 10)
              }),
        Entry(section: .image, reference: "pixels[] / loadPixels()", verdict: .bend, mokume: "pixels[x, y]",
              note: "1 次元の並び (pixels[y * width + x]) が無く、2 次元の添字で読む。Image には pixels 自体が無い",
              tile: .picture { c, _ in
                  c.loadPixels()
                  let p = c.pixels
                  for y in 0..<p.height where y % 6 == 0 {
                      for x in 0..<p.width { p[x, y] = color(Float(x) * 2.6, 80, 200) }
                  }
              }),
        Entry(section: .image, reference: "updatePixels()", verdict: .drop, mokume: "—",
              note: "pixels へ書いた時点で面へ届くので要らない",
              tile: .value { _ in "not needed" }),
        Entry(section: .image, reference: "filter(GRAY / INVERT / BLUR)", verdict: .renamed, mokume: "effects([.monochrome(), .invert(), .blur(radius:)])",
              note: "面ごとの効果として当たる。Image 1 枚に掛ける口ではない",
              tile: .picture { c, r in
                  c.image(r.sample, 16, 16, 64, 64)
                  c.effects([.invert()])
              }),
        Entry(section: .image, reference: "filter(THRESHOLD / POSTERIZE / ERODE / DILATE)", verdict: .write, mokume: "threshold (Support)",
              note: "効果に閾値・階調の削減・膨張収縮が無い。画素を 1 つずつ書く",
              tile: .picture { c, r in
                  let img = try! r.createImage(32, 32)
                  for y in 0..<32 { for x in 0..<32 { img.set(x, y, color(Float(x + y) * 4)) } }
                  threshold(img)
                  c.image(img, 16, 16, 64, 64)
              }),
        Entry(section: .image, reference: "img.mask()", verdict: .write, mokume: "mask (Support)",
              note: "get / set で画素を移し替えれば書ける",
              tile: .picture { c, r in
                  let img = try! r.createImage(32, 32), shape = try! r.createImage(32, 32)
                  img.fill(color(235, 120, 60))
                  for y in 0..<32 { for x in 0..<32 {
                      let d = dist(Float(x), Float(y), 16, 16)
                      shape.set(x, y, color(d < 14 ? 255 : 0))
                  } }
                  mask(img, by: shape)
                  c.image(img, 16, 16, 64, 64)
              }),
        Entry(section: .image, reference: "img.resize()", verdict: .none, mokume: "—",
              note: "絵そのものの大きさを変える口が無い。image() で置く大きさを変えるだけなら書ける",
              tile: .absent),
        Entry(section: .image, reference: "createGraphics()", verdict: .same, mokume: "try createGraphics(w, h) → beginDraw / endDraw",
              tile: .picture { c, r in
                  _ = r
                  c.fill(80, 170, 230)
                  c.circle(m, m, 60)
              }),
        Entry(section: .image, reference: "save() / saveCanvas()", verdict: .same, mokume: "save(path)",
              note: "本体の面だけ。createGraphics の面を書き出す口は無い",
              tile: .value { r in
                  unreached { r.save("out.png") }
                  return "save"
              }),
        Entry(section: .image, reference: "saveFrame(\"f-####.png\")", verdict: .renamed, mokume: "beginRecord(\"f-####.png\") / endRecord()",
              note: "連番と .mov を綴りで分ける",
              tile: .value { r in
                  unreached { r.beginRecord("f-####.png"); r.endRecord() }
                  return "beginRecord"
              }),
    ]

    static let type: [Entry] = [
        Entry(section: .type, reference: "text() / textSize()", verdict: .same, mokume: "text / textSize",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(28)
                  c.text("Aa", 16, 60)
              }),
        Entry(section: .type, reference: "textAlign(CENTER, CENTER)", verdict: .renamed, mokume: "textAlign(.center, .center)",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(24)
                  c.textAlign(.center, .center)
                  c.text("中", m, m)
              }),
        Entry(section: .type, reference: "text(s, x, y, w, h)", verdict: .same, mokume: "text(s, x, y, w, h) → TextFlow",
              note: "textWrap(WORD / CHAR) も同名",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(12)
                  c.textWrap(.word)
                  c.text("the quick brown fox jumps over", 8, 8, 80, 80)
              }),
        Entry(section: .type, reference: "textWidth() / textAscent()", verdict: .same, mokume: "textWidth / textAscent / textDescent / textLeading",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(20)
                  let w = c.textWidth("width")
                  c.text("width", 8, 50)
                  c.fill(80, 170, 230)
                  c.rect(8, 56, w, 4)
              }),
        Entry(section: .type, reference: "textStyle(BOLD)", verdict: .renamed, mokume: "textStyle(.bold)",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(22)
                  c.textStyle(.bold)
                  c.text("Bold", 12, 56)
              }),
        Entry(section: .type, reference: "textFont(\"Helvetica\")", verdict: .same, mokume: "textFont(name)",
              note: "この環境にある書体の名前で引く",
              tile: .picture { c, _ in
                  c.noStroke()
                  c.textSize(22)
                  c.textFont("Menlo")
                  c.text("Menlo", 8, 56)
              }),
        Entry(section: .type, reference: "loadFont(\"x.ttf\")", verdict: .none, mokume: "—",
              note: "書体ファイルを読む口が無い。字形が環境で決まる (Atlas で 6 本を止める)",
              tile: .absent),
        Entry(section: .type, reference: "font.textToPoints()", verdict: .renamed, mokume: "textOutline(s, x, y) → [TextContour]",
              note: "点の間隔 (sampleFactor) は取らない", issue: "mokume#1556",
              tile: .picture { c, _ in
                  c.textSize(48)
                  c.strokeWeight(3)
                  for contour in c.textOutline("S", 28, 72) {
                      for p in contour.points { c.point(p.x, p.y) }
                  }
              }),
    ]
}
