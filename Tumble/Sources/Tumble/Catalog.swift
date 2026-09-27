import mokume

/// 引数の種類。**ふつうの値**の幅と、**端の値**の袋を持つ。
///
/// 端の値は、作品が計算の途中でうっかり渡しうるもの (0・負・とても大きい・とても小さい・
/// 数でない値・無限) に限る。mokume は描く口に投げさせず、注意して何もしないか締める約束
/// なので (mokume ADR-0020 決定 5)、どの値でも落ちず・汚れず・毎回同じ絵が出るはずである。
enum Kind: Sendable {
    /// 面の上の位置 (面は 160×120)。
    case coord
    /// 幅・高さ・半径。
    case size
    /// 角度 (ラジアン)。
    case angle
    /// 色の成分 (0–255)。
    case channel
    /// 線の太さ。
    case weight
    /// 0…1 の割合。
    case unit
    /// 倍率。
    case scale
    /// 個数・大きさの整数。
    case count
    /// 分割の細かさの整数。
    case detail
    /// 選択肢の番号。端の値は持たない。
    case choice(Int)

    var normal: ClosedRange<Double> {
        switch self {
        case .coord: -20...180
        case .size: 0...120
        case .angle: -7...7
        case .channel: 0...255
        case .weight: 0.5...12
        case .unit: 0...1
        case .scale: 0.2...3
        case .count: 1...96
        case .detail: 3...32
        case .choice(let n): 0...Double(n) - 0.001
        }
    }

    var extremes: [Double] {
        switch self {
        case .coord: [0, -1, 1e6, -1e6, 1e20, -1e30, .nan, .infinity, -.infinity, 1e-7]
        case .size: [0, -50, 1e-7, 1e6, 1e20, .nan, .infinity]
        case .angle: [0, 1e10, -1e10, .nan, .infinity, 1e-7]
        case .channel: [-255, 256, 1e9, .nan, .infinity, -.infinity]
        case .weight: [0, -3, 1e-5, 1e5, 1e20, .nan, .infinity]
        case .unit: [-1, 2, .nan, .infinity, 1e-9]
        case .scale: [0, -1, 1e-7, 1e6, .nan, .infinity, 1e-30]
        case .count: [0, -1, 1_048_576, 2_147_483_648, 9.3e18, -9.3e18]
        case .detail: [0, 1, -5, 10_000, 9.3e18]
        case .choice: []
        }
    }

    var isInteger: Bool {
        switch self {
        case .count, .detail, .choice: true
        default: false
        }
    }

    /// ふつうの値を 1 つ引く。
    func tame(_ rng: inout Rng) -> Double {
        let value = rng.uniform(normal)
        return isInteger ? value.rounded(.down) : (value * 100).rounded() / 100
    }

    /// 1 つ引く。`Catalog.extremeRate` の割合で端の値になる。
    func draw(_ rng: inout Rng) -> Double {
        let pool = extremes
        if !pool.isEmpty, rng.chance(Catalog.extremeRate) { return pool[rng.below(pool.count)] }
        return tame(&rng)
    }
}

/// 口録の 1 行。**呼ぶ closure と、Swift に書く綴りを隣に置く** — 離すと、縮めた列を
/// 再現に起こしたときに、走らせたものと違うコードが出る。
struct Entry {
    let name: String
    let kinds: [Kind]
    /// 引く重み。
    let weight: Int
    /// 描く先に効かせる。`stage` は資源と、いまの描く先を持つ。
    let apply: (Stage, Canvas, [Arg]) -> Void
    /// Swift の綴り。`nil` なら `name(引数, …)`。`receiver` は `""` か `"g."`。
    let swift: ((String, [Arg]) -> String)?

    init(
        _ name: String, _ kinds: [Kind], weight: Int = 3,
        swift: ((String, [Arg]) -> String)? = nil,
        _ apply: @escaping (Stage, Canvas, [Arg]) -> Void
    ) {
        self.name = name
        self.kinds = kinds
        self.weight = weight
        self.apply = apply
        self.swift = swift
    }
}

/// 口録。**作品がふつうに呼ぶ口**を、描く先 (本体の面か描き場所) に対して呼べる形で並べる。
///
/// 外してあるもの:
/// - ファイルを読み書きする口 (`loadImage`・`save`・`beginRecord`)。書き出しは Imprint が見る
/// - `noLoop` / `loop` / `redraw`。フレームの進み方そのものを変え、番兵のフレームが来なくなる
/// - `makeNumbers` の大きさ。落ちる数は v0.12.1 で直った (mokume#1589)
enum Catalog {
    /// 端の値を引く割合。
    static let extremeRate = 0.12

    // MARK: - 引数の袋

    /// 色の袋。**成分に数でない値を持つ色は入れない** — 0–1 の口 (`LinearRGBA(straightRed:…)`)
    /// で直に作った色は受け口で弾かれず、そのまま絵に届く。mokume は数値の口 (0–255) の手前で
    /// 弾くと決め、直に作った値の扱いは変えないとしている (mokume ADR-0033 決定 3・9)。入れると、
    /// 利用者が自分で作った NaN が絵に出ただけのものが `nonfinite` を埋める (2026-09-27 に 400 種の
    /// 26 種がそれだった)。
    static let colors: [(value: LinearRGBA, swift: String)] = [
        (color(230, 60, 40), "color(230, 60, 40)"),
        (color(40, 200, 120, 128), "color(40, 200, 120, 128)"),
        (.transparent, ".transparent"),
        (LinearRGBA(straightRed: 4, green: 2, blue: 0.5, alpha: 1), "LinearRGBA(straightRed: 4, green: 2, blue: 0.5, alpha: 1)"),
        (LinearRGBA(premultipliedRed: 1, green: 1, blue: 1, alpha: 0), "LinearRGBA(premultipliedRed: 1, green: 1, blue: 1, alpha: 0)"),
    ]

    static let texts: [(value: String, swift: String)] = [
        ("", "\"\""),
        ("Tumble", "\"Tumble\""),
        ("日本語の字", "\"日本語の字\""),
        ("a\nb\nc", "\"a\\nb\\nc\""),
        ("🙂👍🏽", "\"🙂👍🏽\""),
        (String(repeating: "W", count: 300), "String(repeating: \"W\", count: 300)"),
        ("10\u{00A0}km \t x", "\"10\\u{00A0}km \\t x\""),
        ("ﷺ", "\"ﷺ\""),
    ]

    static let fonts = ["Helvetica", "Menlo", "NoSuchFont-Tumble", ""]

    static func effect(_ which: Arg, _ amount: Arg) -> (value: Effect, swift: String) {
        let a = amount.float
        switch which.choice(7) {
        case 0: return (.blur(radius: a * 8), ".blur(radius: \(amount.swift) * 8)")
        case 1: return (.invert(amount: a), ".invert(amount: \(amount.swift))")
        case 2: return (.bloom(amount: a), ".bloom(amount: \(amount.swift))")
        case 3: return (.vignette(amount: a), ".vignette(amount: \(amount.swift))")
        case 4: return (.fringe(amount: a), ".fringe(amount: \(amount.swift))")
        case 5: return (.monochrome(amount: a), ".monochrome(amount: \(amount.swift))")
        default: return (.adjust(brightness: a, contrast: a), ".adjust(brightness: \(amount.swift), contrast: \(amount.swift))")
        }
    }

    static let blendModes: [BlendMode] = [.blend, .add, .subtract, .darkest, .lightest, .difference, .exclusion, .multiply, .screen, .replace]
    static let shapeModes: [ShapeMode] = [.corner, .corners, .center, .radius]
    static let caps: [StrokeCap] = [.round, .square, .project]
    static let joins: [StrokeJoin] = [.miter, .bevel, .round]
    static let kinds: [VertexKind] = [.polygon, .points, .lines, .triangles, .triangleFan, .triangleStrip]
    static let horizontal: [HorizontalTextAlign] = [.left, .center, .right]
    static let vertical: [VerticalTextAlign] = [.baseline, .top, .center, .bottom]
    static let styles: [TextStyle] = [.normal, .bold, .italic, .boldItalic]
    static let wraps: [TextWrap] = [.word, .character]
    static let tones: [ToneMapping] = [.clip, .roll]

    /// 列挙の値を Swift に書く (`.round` など)。
    static func dot<T>(_ values: [T], _ arg: Arg) -> String { ".\(values[arg.choice(values.count)])" }
    static func pick<T>(_ values: [T], _ arg: Arg) -> T { values[arg.choice(values.count)] }

    // MARK: - 口

    static let frameEntries: [Entry] = style + transform + flat + solid + typography + pictures + pixels
        + layers + effectsAndParticles + resources

    static let setupEntries: [Entry] = resources + style.filter { $0.weight > 0 }

    static let all: [Entry] = frameEntries

    static let byName: [String: Entry] = Dictionary(frameEntries.map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })

    static let style: [Entry] = [
        Entry("fill", [.channel, .channel]) { _, c, a in c.fill(a[0].float, a[1].float) },
        Entry("fillRGBA", [.channel, .channel, .channel, .channel], swift: call("fill")) { _, c, a in
            c.fill(a[0].float, a[1].float, a[2].float, a[3].float)
        },
        Entry("fillColor", [.choice(colors.count), .channel], swift: { r, a in "\(r)fill(\(colors[a[0].choice(colors.count)].swift), \(a[1].swift))" }) { _, c, a in
            c.fill(colors[a[0].choice(colors.count)].value, a[1].float)
        },
        Entry("fillLerp", [.choice(colors.count), .choice(colors.count), .unit], swift: { r, a in
            "\(r)fill(lerpColor(\(colors[a[0].choice(colors.count)].swift), \(colors[a[1].choice(colors.count)].swift), \(a[2].swift)))"
        }) { _, c, a in
            c.fill(lerpColor(colors[a[0].choice(colors.count)].value, colors[a[1].choice(colors.count)].value, a[2].float))
        },
        Entry("noFill", []) { _, c, _ in c.noFill() },
        Entry("stroke", [.channel, .channel, .channel, .channel]) { _, c, a in
            c.stroke(a[0].float, a[1].float, a[2].float, a[3].float)
        },
        Entry("strokeColor", [.choice(colors.count), .channel], swift: { r, a in "\(r)stroke(\(colors[a[0].choice(colors.count)].swift), \(a[1].swift))" }) { _, c, a in
            c.stroke(colors[a[0].choice(colors.count)].value, a[1].float)
        },
        Entry("noStroke", []) { _, c, _ in c.noStroke() },
        Entry("strokeWeight", [.weight], weight: 4) { _, c, a in c.strokeWeight(a[0].float) },
        Entry("strokeCap", [.choice(3)], swift: enumCall("strokeCap", caps)) { _, c, a in c.strokeCap(pick(caps, a[0])) },
        Entry("strokeJoin", [.choice(3)], swift: enumCall("strokeJoin", joins)) { _, c, a in c.strokeJoin(pick(joins, a[0])) },
        Entry("blendMode", [.choice(10)], weight: 4, swift: enumCall("blendMode", blendModes)) { _, c, a in
            c.blendMode(pick(blendModes, a[0]))
        },
        Entry("rectMode", [.choice(4)], swift: enumCall("rectMode", shapeModes)) { _, c, a in c.rectMode(pick(shapeModes, a[0])) },
        Entry("ellipseMode", [.choice(4)], swift: enumCall("ellipseMode", shapeModes)) { _, c, a in c.ellipseMode(pick(shapeModes, a[0])) },
        Entry("imageMode", [.choice(4)], swift: enumCall("imageMode", shapeModes)) { _, c, a in c.imageMode(pick(shapeModes, a[0])) },
        Entry("tint", [.channel, .channel, .channel, .channel]) { _, c, a in c.tint(a[0].float, a[1].float, a[2].float, a[3].float) },
        Entry("noTint", []) { _, c, _ in c.noTint() },
        Entry("clip", [.coord, .coord, .size, .size]) { _, c, a in c.clip(a[0].float, a[1].float, a[2].float, a[3].float) },
        Entry("noClip", []) { _, c, _ in c.noClip() },
        Entry("textSize", [.size]) { _, c, a in c.textSize(a[0].float) },
        Entry("textAlign", [.choice(3), .choice(4)], swift: { r, a in "\(r)textAlign(\(dot(horizontal, a[0])), \(dot(vertical, a[1])))" }) { _, c, a in
            c.textAlign(pick(horizontal, a[0]), pick(vertical, a[1]))
        },
        Entry("textLeading", [.size], weight: 1) { _, c, a in c.textLeading(a[0].float) },
        Entry("textStyle", [.choice(4)], weight: 1, swift: enumCall("textStyle", styles)) { _, c, a in c.textStyle(pick(styles, a[0])) },
        Entry("textWrap", [.choice(2)], weight: 1, swift: enumCall("textWrap", wraps)) { _, c, a in c.textWrap(pick(wraps, a[0])) },
        Entry("textFont", [.choice(fonts.count)], weight: 1, swift: { r, a in "\(r)textFont(\"\(fonts[a[0].choice(fonts.count)])\")" }) { _, c, a in
            c.textFont(fonts[a[0].choice(fonts.count)])
        },
        Entry("noTextFont", [], weight: 1) { _, c, _ in c.noTextFont() },
        Entry("curveDetail", [.detail], weight: 1) { _, c, a in c.curveDetail(a[0].int) },
        Entry("curveTightness", [.unit], weight: 1) { _, c, a in c.curveTightness(a[0].float) },
        Entry("exposure", [.scale], weight: 1) { _, c, a in c.exposure(a[0].float) },
        Entry("toneMapping", [.choice(2)], weight: 1, swift: enumCall("toneMapping", tones)) { _, c, a in c.toneMapping(pick(tones, a[0])) },
        Entry("push", []) { _, c, _ in c.push() },
        Entry("pop", []) { _, c, _ in c.pop() },
        Entry("pushStyle", [], weight: 1) { _, c, _ in c.pushStyle() },
        Entry("popStyle", [], weight: 1) { _, c, _ in c.popStyle() },
    ]

    static let transform: [Entry] = [
        Entry("translate", [.coord, .coord]) { _, c, a in c.translate(a[0].float, a[1].float) },
        Entry("translate3", [.coord, .coord, .coord], weight: 1, swift: call("translate")) { _, c, a in
            c.translate(a[0].float, a[1].float, a[2].float)
        },
        Entry("rotate", [.angle]) { _, c, a in c.rotate(a[0].float) },
        Entry("rotateX", [.angle], weight: 1) { _, c, a in c.rotateX(a[0].float) },
        Entry("rotateY", [.angle], weight: 1) { _, c, a in c.rotateY(a[0].float) },
        Entry("scale", [.scale, .scale]) { _, c, a in c.scale(a[0].float, a[1].float) },
        Entry("scale3", [.scale, .scale, .scale], weight: 1, swift: call("scale")) { _, c, a in
            c.scale(a[0].float, a[1].float, a[2].float)
        },
        Entry("shearX", [.angle], weight: 1) { _, c, a in c.shearX(a[0].float) },
        Entry("resetMatrix", [], weight: 1) { _, c, _ in c.resetMatrix() },
        Entry("pushMatrix", [], weight: 1) { _, c, _ in c.pushMatrix() },
        Entry("popMatrix", [], weight: 1) { _, c, _ in c.popMatrix() },
    ]

    static let flat: [Entry] = [
        Entry("background", [.channel, .channel], weight: 2) { _, c, a in c.background(a[0].float, a[1].float) },
        Entry("point", [.coord, .coord]) { _, c, a in c.point(a[0].float, a[1].float) },
        Entry("line", [.coord, .coord, .coord, .coord], weight: 4) { _, c, a in c.line(a[0].float, a[1].float, a[2].float, a[3].float) },
        Entry("rect", [.coord, .coord, .size, .size], weight: 5) { _, c, a in c.rect(a[0].float, a[1].float, a[2].float, a[3].float) },
        Entry("square", [.coord, .coord, .size]) { _, c, a in c.square(a[0].float, a[1].float, a[2].float) },
        Entry("ellipse", [.coord, .coord, .size, .size], weight: 4) { _, c, a in c.ellipse(a[0].float, a[1].float, a[2].float, a[3].float) },
        Entry("circle", [.coord, .coord, .size]) { _, c, a in c.circle(a[0].float, a[1].float, a[2].float) },
        Entry("arc", [.coord, .coord, .size, .size, .angle, .angle]) { _, c, a in
            c.arc(a[0].float, a[1].float, a[2].float, a[3].float, a[4].float, a[5].float)
        },
        Entry("triangle", Array(repeating: .coord, count: 6)) { _, c, a in
            c.triangle(a[0].float, a[1].float, a[2].float, a[3].float, a[4].float, a[5].float)
        },
        Entry("quad", Array(repeating: .coord, count: 8)) { _, c, a in
            c.quad(a[0].float, a[1].float, a[2].float, a[3].float, a[4].float, a[5].float, a[6].float, a[7].float)
        },
        // 形を並べる口は、開いたまま残すと mokume#1591 (開いた形がフレームを越える) を踏むので、
        // 開いて閉じるまでを 1 口にする
        Entry("polygon", [.choice(6)] + Array(repeating: .coord, count: 10) + [.choice(2)], weight: 4, swift: { r, a in
            var lines = ["\(r)beginShape(\(dot(kinds, a[0])))"]
            for i in 0..<5 { lines.append("\(r)vertex(\(a[1 + 2 * i].swift), \(a[2 + 2 * i].swift))") }
            lines.append("\(r)endShape(\(a[11].choice(2) == 0 ? ".open" : ".close"))")
            return lines.joined(separator: "; ")
        }) { _, c, a in
            c.beginShape(pick(kinds, a[0]))
            for i in 0..<5 { c.vertex(a[1 + 2 * i].float, a[2 + 2 * i].float) }
            c.endShape(a[11].choice(2) == 0 ? .open : .close)
        },
        Entry("curve", Array(repeating: .coord, count: 12) + [.choice(2)], weight: 2, swift: { r, a in
            var lines = ["\(r)beginShape()"]
            for i in 0..<6 { lines.append("\(r)curveVertex(\(a[2 * i].swift), \(a[2 * i + 1].swift))") }
            lines.append("\(r)endShape(\(a[12].choice(2) == 0 ? ".open" : ".close"))")
            return lines.joined(separator: "; ")
        }) { _, c, a in
            c.beginShape()
            for i in 0..<6 { c.curveVertex(a[2 * i].float, a[2 * i + 1].float) }
            c.endShape(a[12].choice(2) == 0 ? .open : .close)
        },
        Entry("bezier", Array(repeating: .coord, count: 12) + [.choice(2)], weight: 2, swift: { r, a in
            let s = a.map(\.swift)
            return "\(r)beginShape(); \(r)vertex(\(s[0]), \(s[1])); "
                + "\(r)bezierVertex(\(s[2]), \(s[3]), \(s[4]), \(s[5]), \(s[6]), \(s[7])); "
                + "\(r)quadraticVertex(\(s[8]), \(s[9]), \(s[10]), \(s[11])); "
                + "\(r)endShape(\(a[12].choice(2) == 0 ? ".open" : ".close"))"
        }) { _, c, a in
            let f = a.map(\.float)
            c.beginShape()
            c.vertex(f[0], f[1])
            c.bezierVertex(f[2], f[3], f[4], f[5], f[6], f[7])
            c.quadraticVertex(f[8], f[9], f[10], f[11])
            c.endShape(a[12].choice(2) == 0 ? .open : .close)
        },
        Entry("contour", [.coord, .coord, .size, .size, .coord, .coord, .size, .size], weight: 2, swift: { r, a in
            let s = a.map(\.swift)
            return "\(r)beginShape(); "
                + "\(r)vertex(\(s[0]), \(s[1])); \(r)vertex(\(s[0]) + \(s[2]), \(s[1])); "
                + "\(r)vertex(\(s[0]) + \(s[2]), \(s[1]) + \(s[3])); \(r)vertex(\(s[0]), \(s[1]) + \(s[3])); "
                + "\(r)beginContour(); "
                + "\(r)vertex(\(s[4]), \(s[5])); \(r)vertex(\(s[4]), \(s[5]) + \(s[7])); "
                + "\(r)vertex(\(s[4]) + \(s[6]), \(s[5]) + \(s[7])); \(r)vertex(\(s[4]) + \(s[6]), \(s[5])); "
                + "\(r)endContour(); \(r)endShape(.close)"
        }) { _, c, a in
            let f = a.map(\.float)
            c.beginShape()
            c.vertex(f[0], f[1])
            c.vertex(f[0] + f[2], f[1])
            c.vertex(f[0] + f[2], f[1] + f[3])
            c.vertex(f[0], f[1] + f[3])
            c.beginContour()
            c.vertex(f[4], f[5])
            c.vertex(f[4], f[5] + f[7])
            c.vertex(f[4] + f[6], f[5] + f[7])
            c.vertex(f[4] + f[6], f[5])
            c.endContour()
            c.endShape(.close)
        },
        Entry("normRect", [.coord, .coord, .coord, .coord, .coord, .coord], weight: 1, swift: { r, a in
            let s = a.map(\.swift)
            return "\(r)rect(norm(\(s[0]), \(s[1]), \(s[2])) * 160, smoothstep(\(s[3]), \(s[4]), \(s[5])) * 120, 20, 20)"
        }) { _, c, a in
            let f = a.map(\.float)
            c.rect(norm(f[0], f[1], f[2]) * 160, smoothstep(f[3], f[4], f[5]) * 120, 20, 20)
        },
    ]

    static let solid: [Entry] = [
        Entry("box", [.size], weight: 2) { _, c, a in c.box(a[0].float) },
        Entry("sphere", [.size, .detail], weight: 2, swift: { r, a in "\(r)sphere(\(a[0].swift), detail: \(a[1].swift))" }) { _, c, a in
            c.sphere(a[0].float, detail: a[1].int)
        },
        Entry("torus", [.size, .size, .detail], weight: 1, swift: { r, a in "\(r)torus(\(a[0].swift), \(a[1].swift), detail: \(a[2].swift))" }) { _, c, a in
            c.torus(a[0].float, a[1].float, detail: a[2].int)
        },
        Entry("cylinder", [.size, .size, .detail], weight: 1, swift: { r, a in "\(r)cylinder(\(a[0].swift), \(a[1].swift), detail: \(a[2].swift))" }) { _, c, a in
            c.cylinder(a[0].float, a[1].float, detail: a[2].int)
        },
        Entry("cone", [.size, .size, .detail], weight: 1, swift: { r, a in "\(r)cone(\(a[0].swift), \(a[1].swift), detail: \(a[2].swift))" }) { _, c, a in
            c.cone(a[0].float, a[1].float, detail: a[2].int)
        },
        Entry("plane", [.size, .size], weight: 1) { _, c, a in c.plane(a[0].float, a[1].float) },
        Entry("lights", [], weight: 2) { _, c, _ in c.lights() },
        Entry("noLights", [], weight: 1) { _, c, _ in c.noLights() },
        Entry("ambientLight", [.channel, .channel, .channel], weight: 1) { _, c, a in c.ambientLight(a[0].float, a[1].float, a[2].float) },
        Entry("directionalLight", [.channel, .channel, .channel, .coord, .coord, .coord], weight: 1) { _, c, a in
            c.directionalLight(a[0].float, a[1].float, a[2].float, a[3].float, a[4].float, a[5].float)
        },
        Entry("pointLight", [.channel, .channel, .channel, .coord, .coord, .coord], weight: 1) { _, c, a in
            c.pointLight(a[0].float, a[1].float, a[2].float, a[3].float, a[4].float, a[5].float)
        },
        Entry("camera", Array(repeating: .coord, count: 9), weight: 1) { _, c, a in
            let f = a.map(\.float)
            c.camera(f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7], f[8])
        },
        Entry("perspective", [.angle, .scale, .size, .size], weight: 1) { _, c, a in
            c.perspective(a[0].float, a[1].float, a[2].float, a[3].float)
        },
        Entry("ortho", [], weight: 1) { _, c, _ in c.ortho() },
        Entry("emissive", [.channel, .channel, .channel], weight: 1) { _, c, a in c.emissive(a[0].float, a[1].float, a[2].float) },
        Entry("shininess", [.size], weight: 1) { _, c, a in c.shininess(a[0].float) },
        Entry("metalness", [.unit], weight: 1) { _, c, a in c.metalness(a[0].float) },
        Entry("shadows", [.choice(2)], weight: 1, swift: { r, a in "\(r)shadows(\(a[0].choice(2) == 1))" }) { _, c, a in
            c.shadows(a[0].choice(2) == 1)
        },
    ]

    static let typography: [Entry] = [
        Entry("text", [.choice(texts.count), .coord, .coord], weight: 4, swift: { r, a in
            "\(r)text(\(texts[a[0].choice(texts.count)].swift), \(a[1].swift), \(a[2].swift))"
        }) { _, c, a in
            c.text(texts[a[0].choice(texts.count)].value, a[1].float, a[2].float)
        },
        Entry("textBox", [.choice(texts.count), .coord, .coord, .size, .size], weight: 2, swift: { r, a in
            "\(r)text(\(texts[a[0].choice(texts.count)].swift), \(a[1].swift), \(a[2].swift), \(a[3].swift), \(a[4].swift))"
        }) { _, c, a in
            c.text(texts[a[0].choice(texts.count)].value, a[1].float, a[2].float, a[3].float, a[4].float)
        },
        Entry("textWidth", [.choice(texts.count)], weight: 1, swift: { r, a in
            "rect(0, 0, \(r)textWidth(\(texts[a[0].choice(texts.count)].swift)), 4)"
        }) { stage, c, a in
            // 測った値で描いて、値が絵に出るようにする (数でない幅が出れば、番兵より前の絵で見える)
            stage.main.rect(0, 0, c.textWidth(texts[a[0].choice(texts.count)].value), 4)
        },
        Entry("textOutline", [.choice(texts.count), .coord, .coord], weight: 1, swift: { r, a in
            "_ = \(r)textOutline(\(texts[a[0].choice(texts.count)].swift), \(a[1].swift), \(a[2].swift))"
        }) { _, c, a in
            _ = c.textOutline(texts[a[0].choice(texts.count)].value, a[1].float, a[2].float)
        },
    ]

    static let pictures: [Entry] = [
        Entry("image", [.coord, .coord], weight: 2, swift: { r, a in "\(r)image(img, \(a[0].swift), \(a[1].swift))" }) { stage, c, a in
            c.image(stage.picture, a[0].float, a[1].float)
        },
        Entry("imageBox", [.coord, .coord, .size, .size], weight: 2, swift: { r, a in
            "\(r)image(img, \(a.map(\.swift).joined(separator: ", ")))"
        }) { stage, c, a in
            c.image(stage.picture, a[0].float, a[1].float, a[2].float, a[3].float)
        },
        Entry("imageCrop", [.coord, .coord, .size, .size, .coord, .coord, .size, .size], weight: 2, swift: { r, a in
            "\(r)image(img, \(a.map(\.swift).joined(separator: ", ")))"
        }) { stage, c, a in
            let f = a.map(\.float)
            c.image(stage.picture, f[0], f[1], f[2], f[3], f[4], f[5], f[6], f[7])
        },
        Entry("imageLayer", [.coord, .coord, .size, .size], weight: 2, swift: { r, a in
            "\(r)image(g, \(a.map(\.swift).joined(separator: ", ")))"
        }) { stage, c, a in
            c.image(stage.layer, a[0].float, a[1].float, a[2].float, a[3].float)
        },
        Entry("texture", [.choice(2)], weight: 2, swift: { r, a in "\(r)texture(\(a[0].choice(2) == 0 ? "img" : "g"))" }) { stage, c, a in
            if a[0].choice(2) == 0 { c.texture(stage.picture) } else { c.texture(stage.layer) }
        },
        Entry("noTexture", [], weight: 1) { _, c, _ in c.noTexture() },
        Entry("imageSet", [.count, .count, .choice(colors.count)], weight: 1, swift: { _, a in
            "img.set(\(a[0].swift), \(a[1].swift), \(colors[a[2].choice(colors.count)].swift))"
        }) { stage, _, a in
            stage.picture.set(a[0].int, a[1].int, colors[a[2].choice(colors.count)].value)
        },
        Entry("shader", [.choice(101)], weight: 1, swift: { r, a in "paint.set(\"k\", \(Arg(Double(a[0].choice(101)) / 100).swift)); \(r)shader(paint)" }) { stage, c, a in
            // 断片へ渡す値は 0…1 に限る。断片が返す色は利用者のコードの値で、NaN を返せばそのまま出る
            stage.paint.set("k", .number(Float(a[0].choice(101)) / 100))
            c.shader(stage.paint)
        },
        Entry("resetShader", [], weight: 1) { _, c, _ in c.resetShader() },
        Entry("shape", [.coord, .coord], weight: 2, swift: { r, a in "\(r)shape(form, \(a[0].swift), \(a[1].swift))" }) { stage, c, a in
            c.shape(stage.form, a[0].float, a[1].float)
        },
        Entry("shapeAt", [.count, .coord, .scale], weight: 1, swift: { r, a in
            "\(r)shape(form, at: (0..<min(\(a[0].swift), 4096)).map { Placement(x: Float($0 % 16) * 10, y: \(a[1].swift), scale: \(a[2].swift)) })"
        }) { stage, c, a in
            let n = min(a[0].int, 4096)
            let placements = n > 0 ? (0..<n).map { Placement(x: Float($0 % 16) * 10, y: a[1].float, scale: a[2].float) } : []
            c.shape(stage.form, at: placements)
        },
    ]

    static let pixels: [Entry] = [
        Entry("get", [.coord, .coord], weight: 1, swift: { r, a in
            "\(r)fill(\(r)get(\(Arg(Double(a[0].int)).swift), \(Arg(Double(a[1].int)).swift)))"
        }) { _, c, a in
            c.fill(c.get(a[0].int, a[1].int))
        },
        Entry("set", [.coord, .coord, .choice(colors.count)], weight: 1, swift: { r, a in
            "\(r)set(\(Arg(Double(a[0].int)).swift), \(Arg(Double(a[1].int)).swift), \(colors[a[2].choice(colors.count)].swift))"
        }) { _, c, a in
            c.set(a[0].int, a[1].int, colors[a[2].choice(colors.count)].value)
        },
        Entry("loadPixels", [], weight: 1) { _, c, _ in c.loadPixels() },
        Entry("pixelsSet", [.coord, .coord, .choice(colors.count)], weight: 1, swift: { r, a in
            "\(r)pixels[\(Arg(Double(a[0].int)).swift), \(Arg(Double(a[1].int)).swift)] = \(colors[a[2].choice(colors.count)].swift)"
        }) { _, c, a in
            c.pixels[a[0].int, a[1].int] = colors[a[2].choice(colors.count)].value
        },
    ]

    static let layers: [Entry] = [
        Entry("beginDraw", [], weight: 2, swift: { _, _ in "g.beginDraw()" }) { stage, _, _ in
            stage.layer.beginDraw()
            stage.current = stage.layer
        },
        Entry("endDraw", [], weight: 2, swift: { _, _ in "g.endDraw()" }) { stage, _, _ in
            stage.layer.endDraw()
            stage.current = stage.main
        },
    ]

    static let effectsAndParticles: [Entry] = [
        Entry("effects", [.choice(7), .unit], weight: 2, swift: { r, a in "\(r)effects([\(effect(a[0], a[1]).swift)])" }) { _, c, a in
            c.effects([effect(a[0], a[1]).value])
        },
        Entry("effects2", [.choice(7), .unit, .choice(7), .unit], weight: 1, swift: { r, a in
            "\(r)effects([\(effect(a[0], a[1]).swift), \(effect(a[2], a[3]).swift)])"
        }) { _, c, a in
            c.effects([effect(a[0], a[1]).value, effect(a[2], a[3]).value])
        },
        Entry("emit", [.coord, .coord, .size, .size], weight: 2, swift: { _, a in
            "emit(dots, from: .circle(\(a[0].swift), \(a[1].swift), radius: \(a[2].swift)), rate: \(a[3].swift))"
        }) { stage, _, a in
            // `emit` は本体の口にしかない
            stage.sketch.emit(stage.dots, from: .circle(a[0].float, a[1].float, radius: a[2].float), rate: a[3].float)
        },
        Entry("force", [.coord, .coord, .size, .size], weight: 1, swift: { r, a in
            "\(r)force(dots, [.attract(\(a[0].swift), \(a[1].swift), strength: \(a[2].swift), weakeningBeyond: \(a[3].swift)), .drag(1.2)])"
        }) { stage, c, a in
            c.force(stage.dots, [.attract(a[0].float, a[1].float, strength: a[2].float, weakeningBeyond: a[3].float), .drag(1.2)])
        },
        Entry("particles", [], weight: 2, swift: { r, _ in "\(r)particles(dots)" }) { stage, c, _ in c.particles(stage.dots) },
    ]

    /// 資源を作り直す口。**作れなければ前の資源を使い続ける** (投げるのは約束どおり)。
    static let resources: [Entry] = [
        Entry("createGraphics", [.count, .count], weight: 1, swift: { _, a in
            "if let made = try? createGraphics(\(a[0].swift), \(a[1].swift)) { g = made }"
        }) { stage, _, a in
            if stage.current === stage.layer { return }  // 描いている最中の描き場所は取り替えない
            if let made = try? stage.main.createGraphics(a[0].int, a[1].int) { stage.layer = made }
        },
        Entry("createImage", [.count, .count], weight: 1, swift: { _, a in
            "if let made = try? createImage(\(a[0].swift), \(a[1].swift)) { img = made }"
        }) { stage, _, a in
            if let made = try? stage.main.createImage(a[0].int, a[1].int) { stage.picture = made }
        },
        Entry("makeParticles", [.count], weight: 1, swift: { _, a in
            "if let made = try? makeParticles(count: \(a[0].swift)) { dots = made }"
        }) { stage, _, a in
            if let made = try? stage.main.makeParticles(count: a[0].int) { stage.dots = made }
        },
        Entry("createShape", [.coord, .coord, .size, .weight], weight: 1, swift: { _, a in
            "form = createShape { strokeWeight(\(a[3].swift)); rect(\(a[0].swift), \(a[1].swift), \(a[2].swift), \(a[2].swift)); ellipse(\(a[0].swift), \(a[1].swift), \(a[2].swift), \(a[2].swift)) }"
        }) { stage, _, a in
            let f = a.map(\.float)
            stage.form = stage.main.createShape {
                stage.main.strokeWeight(f[3])
                stage.main.rect(f[0], f[1], f[2], f[2])
                stage.main.ellipse(f[0], f[1], f[2], f[2])
            }
        },
        Entry("noiseSeed", [.count], weight: 1) { _, c, a in c.noiseSeed(a[0].int) },
        Entry("noiseDetail", [.detail, .unit], weight: 1) { _, c, a in c.noiseDetail(a[0].int, a[1].float) },
        Entry("noisePoint", [.coord, .coord], weight: 1, swift: { r, a in
            "\(r)circle(\(r)noise(\(a[0].swift), \(a[1].swift)) * 160, 60, 8)"
        }) { _, c, a in
            c.circle(c.noise(a[0].float, a[1].float) * 160, 60, 8)
        },
    ]

    // MARK: - 既知の破れを避ける

    /// **起票済みの破れを踏む引数を、ふつうの値に引き直す。** 踏むたびに落ちると、その先の
    /// 列が回らず、同じ既知の破れで結果が埋まる。直ったら、ここから外して見張りに戻す。
    ///
    /// - mokume#1587: `text` / `textOutline` に数でない座標や巨大な座標を渡すと、Int への変換で落ちる。
    ///   巨大な `textSize` (1e20) の後の字も同じ所で落ちる
    /// - mokume#未起票: `curveDetail` に上限が無く、巨大な値の後の `bezierVertex` などが止まる
    ///   (種 3161 は 130 秒で 21 GB を確保した)
    static func avoidKnown(_ name: String, _ args: inout [Arg], _ kinds: [Kind], _ rng: inout Rng) {
        switch name {
        case "text", "textBox", "textOutline":
            for i in 1..<args.count where !args[i].value.isFinite || abs(args[i].value) > 1e15 {
                args[i] = Arg(kinds[i].tame(&rng))
            }
        case "textSize":
            if !(abs(args[0].value) < 1e15) { args[0] = Arg(kinds[0].tame(&rng)) }
        case "curveDetail":
            if args[0].value > 100_000 { args[0] = Arg(kinds[0].tame(&rng)) }
        default: break
        }
    }

    // MARK: - 引く・書く

    static let frameTotal = frameEntries.reduce(0) { $0 + $1.weight }
    static let setupTotal = setupEntries.reduce(0) { $0 + $1.weight }

    /// 重みに従って口を 1 つ引き、引数を引く。
    static func draw(_ rng: inout Rng, in entries: [Entry]) -> Op {
        let total = entries.reduce(0) { $0 + $1.weight }
        var roll = rng.below(total)
        var chosen = entries[0]
        for entry in entries {
            if roll < entry.weight {
                chosen = entry
                break
            }
            roll -= entry.weight
        }
        var args = chosen.kinds.map { Arg($0.draw(&rng)) }
        avoidKnown(chosen.name, &args, chosen.kinds, &rng)
        var tame: [Arg] = []
        for (kind, arg) in zip(chosen.kinds, args) {
            let value = arg.value
            // ふつうの値ならそのまま、端の値なら同じ種類のふつうの値を控える
            tame.append(Arg(kind.extremes.contains { $0 == value || ($0.isNaN && value.isNaN) } ? kind.tame(&rng) : value))
        }
        return Op(name: chosen.name, args: args, tame: tame)
    }

    /// 1 口を Swift で書く。`receiver` は描き場所に描いているとき `"g."`。
    static func swift(_ op: Op, receiver: String = "") -> String {
        guard let entry = byName[op.name] else { return "// 知らない口: \(op.name)" }
        // 整数の引数は、呼ぶときと同じく `Arg.int` で締めてから書く (`9.3e+18` は Int の口に渡せない)
        let args = zip(entry.kinds, op.args).map { kind, arg in kind.isInteger ? Arg(Double(arg.int)) : arg }
        if let swift = entry.swift { return swift(receiver, args) }
        return "\(receiver)\(op.name)(\(args.map(\.swift).joined(separator: ", ")))"
    }

    static func call(_ name: String) -> (String, [Arg]) -> String {
        { r, a in "\(r)\(name)(\(a.map(\.swift).joined(separator: ", ")))" }
    }

    static func enumCall<T>(_ name: String, _ values: [T]) -> (String, [Arg]) -> String {
        { r, a in "\(r)\(name)(\(dot(values, a[0])))" }
    }
}
