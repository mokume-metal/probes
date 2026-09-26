import mokume

/// その場で書いた `setup()` と `draw()` だけのスケッチ。**1 条件 = 1 本のスケッチ**で、
/// 条件ごとに別の `SketchRuntime` で回す (面の大きさ・細かさ・fps は組み立てのときにしか
/// 決められない)。
final class Scene: Sketch {
    var settings: SketchSettings
    let prepare: ((Scene) -> Void)?
    let body: (Scene) -> Void
    init(_ settings: SketchSettings, setup prepare: ((Scene) -> Void)? = nil, _ body: @escaping (Scene) -> Void) {
        self.settings = settings
        self.prepare = prepare
        self.body = body
    }
    /// `Sketch` が求めるだけで、検査からは呼ばない。
    convenience init() { self.init(SketchSettings()) { _ in } }
    func setup() { prepare?(self) }
    func draw() { body(self) }
}

/// 関係を当てる図形。**塗りだけか線だけのどちらか**にする。
///
/// mokume は整数の座標を、塗りでは画素の角に、線・輪郭・点では画素の中心に置く
/// (mokume ADR-0039 決定 2)。だから鏡映や 90° 回転で絵が画素ごと写り合うのは、塗りなら
/// 画素の角、線なら画素の中心を軸にしたときだけで、両方を持つ図形はどちらの軸でも
/// 写り合わない。これは約束なので、図形の側で分けておく。
///
/// **座標は整数と半整数を避けた小数にする。** 三角形の経路には縁の AA が無く
/// (ADR-0039 決定 3)、画素の中心がちょうど縁に乗ると境界の規則 (左上の規則) がどちらかへ
/// 決める。この規則は鏡映で写り合わないので、同点を踏むと約束の破れと見分けられない。
nonisolated struct Figure: Sendable {
    let key: String
    /// 線で描くか。関係の軸 (画素の角か中心か) を決める。
    let stroke: Bool
    /// 三角形の経路で描くか。縁に AA が無く、浮動小数の丸めで縁の画素が 1 つ揺れうる。
    let triangles: Bool
    let draw: @MainActor @Sendable (Scene) -> Void
}

nonisolated enum Figures {
    /// 面の一辺。図形はどれも (0, 0)…(side, side) の中に収まる。
    static let side = 160

    static let fills: [Figure] = [
        Figure(key: "circle", stroke: false, triangles: false) { s in
            s.fill(255, 180, 60); s.noStroke(); s.circle(71.37, 83.61, 57.3)
        },
        Figure(key: "ellipse", stroke: false, triangles: false) { s in
            s.fill(255); s.noStroke(); s.ellipse(63.37, 90.61, 67.3, 31.9)
        },
        Figure(key: "rect", stroke: false, triangles: false) { s in
            s.fill(255); s.noStroke(); s.rect(33.37, 41.61, 47.3, 29.9)
        },
        Figure(key: "rotatedRect", stroke: false, triangles: false) { s in
            s.fill(255); s.noStroke(); s.push(); s.translate(70.37, 80.61); s.rotate(0.3)
            s.rect(-20.3, -12.1, 47.3, 29.9); s.pop()
        },
        Figure(key: "arc", stroke: false, triangles: false) { s in
            s.fill(255); s.noStroke(); s.arc(77.37, 83.61, 90.3, 70.1, 0.4, 2.9)
        },
        Figure(key: "triangle", stroke: false, triangles: true) { s in
            s.fill(255); s.noStroke(); s.triangle(30.37, 40.61, 110.13, 60.29, 55.71, 121.43)
        },
        Figure(key: "quad", stroke: false, triangles: true) { s in
            s.fill(255); s.noStroke(); s.quad(30.37, 40.61, 110.13, 50.29, 100.3, 110.8, 45.71, 121.43)
        },
        Figure(key: "heptagon", stroke: false, triangles: true) { s in
            s.fill(255); s.noStroke(); s.beginShape()
            for i in 0..<7 {
                let a = Float(i) * 2 * .pi / 7 + 0.21
                s.vertex(75.37 + 40.3 * cos(a), 81.61 + 33.1 * sin(a))
            }
            s.endShape(.close)
        },
        Figure(key: "contour", stroke: false, triangles: true) { s in
            s.fill(255); s.noStroke(); s.beginShape()
            s.vertex(30.37, 30.61); s.vertex(120.13, 35.29); s.vertex(115.3, 125.8); s.vertex(35.71, 120.43)
            s.beginContour()
            s.vertex(60.3, 60.2); s.vertex(60.7, 90.9); s.vertex(90.1, 90.4); s.vertex(90.6, 60.8)
            s.endContour()
            s.endShape(.close)
        },
        Figure(key: "bezier", stroke: false, triangles: true) { s in
            s.fill(255); s.noStroke(); s.beginShape(); s.vertex(30.37, 50.61)
            s.bezierVertex(60.3, 10.2, 110.7, 40.9, 120.1, 90.4)
            s.bezierVertex(90.3, 130.2, 40.7, 120.9, 30.37, 50.61)
            s.endShape(.close)
        },
        Figure(key: "text", stroke: false, triangles: false) { s in
            s.fill(255); s.textSize(37.3); s.text("Rg", 40.37, 100.61)
        },
    ]

    static let strokes: [Figure] = [
        Figure(key: "circleStroke", stroke: true, triangles: false) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(3.3); s.circle(71.37, 83.61, 57.3)
        },
        Figure(key: "ellipseStroke", stroke: true, triangles: false) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(2.3); s.ellipse(63.37, 90.61, 67.3, 31.9)
        },
        Figure(key: "rectStroke", stroke: true, triangles: false) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(4.3); s.rect(33.37, 41.61, 47.3, 29.9)
        },
        Figure(key: "rotatedRectStroke", stroke: true, triangles: false) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(4.3); s.push(); s.translate(70.37, 80.61); s.rotate(0.3)
            s.rect(-20.3, -12.1, 47.3, 29.9); s.pop()
        },
        Figure(key: "arcStroke", stroke: true, triangles: false) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(4.3); s.arc(77.37, 83.61, 90.3, 70.1, 0.4, 2.9)
        },
        Figure(key: "lineRound", stroke: true, triangles: false) { s in
            s.stroke(255); s.strokeWeight(6.3); s.strokeCap(.round); s.line(30.37, 40.61, 110.13, 100.29)
        },
        Figure(key: "lineSquare", stroke: true, triangles: false) { s in
            s.stroke(255); s.strokeWeight(6.3); s.strokeCap(.square); s.line(30.37, 40.61, 110.13, 100.29)
        },
        Figure(key: "lineProject", stroke: true, triangles: false) { s in
            s.stroke(255); s.strokeWeight(6.3); s.strokeCap(.project); s.line(30.37, 40.61, 110.13, 100.29)
        },
        Figure(key: "lineThin", stroke: true, triangles: false) { s in
            s.stroke(255); s.strokeWeight(1); s.line(30.37, 40.61, 110.13, 100.29)
        },
        Figure(key: "points", stroke: true, triangles: false) { s in
            s.stroke(255); s.strokeWeight(7.3); s.point(40.37, 50.61); s.point(90.13, 60.29)
            s.strokeWeight(1.7); s.point(70.3, 110.7)
        },
        Figure(key: "polylineMiter", stroke: true, triangles: true) { s in
            polyline(s, .miter, close: false)
        },
        Figure(key: "polylineRound", stroke: true, triangles: true) { s in
            polyline(s, .round, close: false)
        },
        Figure(key: "polygonBevel", stroke: true, triangles: true) { s in
            polyline(s, .bevel, close: true)
        },
        Figure(key: "curveStroke", stroke: true, triangles: true) { s in
            s.noFill(); s.stroke(255); s.strokeWeight(3.3); s.beginShape()
            s.curveVertex(30.37, 50.61); s.curveVertex(30.37, 50.61); s.curveVertex(60.3, 110.2)
            s.curveVertex(110.7, 40.9); s.curveVertex(120.1, 90.4); s.curveVertex(120.1, 90.4)
            s.endShape()
        },
    ]

    static let all = fills + strokes

    static func named(_ key: String) -> Figure { all.first { $0.key == key }! }

    @MainActor private static func polyline(_ s: Scene, _ join: StrokeJoin, close: Bool) {
        s.noFill(); s.stroke(255); s.strokeWeight(6.3); s.strokeJoin(join); s.beginShape()
        s.vertex(30.37, 40.61); s.vertex(110.13, 50.29); s.vertex(50.3, 120.8)
        if close { s.endShape(.close) } else { s.endShape() }
    }
}

/// 図形に掛ける変換。**どれも面の中心 (80, 80) を軸にする。** 絵の側では、同じ変換を
/// 画素の置き換えとして掛けたものと比べる (`Tests/LatticeTests/Mapping.swift`)。
nonisolated enum Relation: String, CaseIterable, Sendable {
    case mirrorX, mirrorY, rotate90, rotate180, rotate270, shift

    /// `shift` で動かす量 (整数の画素)。
    static let offset = (x: 13, y: 7)

    @MainActor func apply(_ s: Scene, center c: Float) {
        switch self {
        case .shift:
            s.translate(Float(Self.offset.x), Float(Self.offset.y))
            return
        default: break
        }
        s.translate(c, c)
        switch self {
        case .mirrorX: s.scale(-1, 1)
        case .mirrorY: s.scale(1, -1)
        case .rotate90: s.rotate(Float.pi / 2)
        case .rotate180: s.rotate(Float.pi)
        case .rotate270: s.rotate(3 * Float.pi / 2)
        case .shift: break
        }
        s.translate(-c, -c)
    }
}
