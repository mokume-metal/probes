import Foundation
import mokume

/// mokume を長く回したときの「メモリ・重さ・落ちる」を突く物差し。
///
/// **作品ではない。** Probe・Drift・Routine が絵の約束を比べたのに対し、こちらは
/// **資源**を見る — 1 枚ごとに増えて減らないメモリ、仕事の量に見合わない時間、
/// プロセスごと止まる口。数で押さえるのは `Tests/SoakTests` の側で、窓はそれを目で
/// 確かめるためにある (README「確かめ方」)。
///
/// **1 度に 1 候補の 1 経路だけ回す。** footprint も GPU の確保量もプロセス全体の値
/// なので、2 つを同時に回すとどちらの増え方か分からない。経路ごとに自前の
/// `SketchRuntime` を持ち、その絵を本体へ貼る (Routine と同じ作り)。落ちる候補
/// (`CrashKey`) は窓ごと落ちるので並べない。
@main
final class Soak: Sketch {
    static let zoom: Float = 2
    static let margin: Float = 16
    static let header: Float = 56
    static let graphWidth: Float = 420
    static let stage = Float(Loads.side) * zoom
    /// 折れ線に残す枚数。
    static let history = 300

    var settings = SketchSettings(
        width: Int(margin * 3 + stage + graphWidth),
        height: Int(header + stage + margin),
        frameRate: Loads.frameRate,
        title: "soak — mokume v0.11.1")

    /// いま回している候補と経路。
    private var index = 0
    private var route = Route.suspect
    private var rig: Rig?
    /// 回し始めてからの目盛り。
    private var samples: [Sample] = []

    struct Sample {
        var footprint: Double
        var gpu: Double
        var milliseconds: Double
    }

    func setup() { show(0, .suspect) }

    func show(_ next: Int, _ nextRoute: Route) {
        // **古い舞台を先に手放す。** 新しい舞台の基準線に、前の候補の残りを混ぜない
        rig = nil
        index = (next + Loads.all.count) % Loads.all.count
        route = nextRoute
        samples = []
        rig = Rig(Loads.all[index], route)
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(index + 1, route) }
        if keyCode == .arrowLeft { show(index - 1, route) }
        if key == " " { show(index, route == .suspect ? .reference : .suspect) }
        if key == "r" { show(index, route) }
    }

    func draw() {
        background(12)
        let load = Loads.all[index]
        noStroke()
        fill(230)
        textAlign(.left, .top)
        textSize(16)
        text("\(index + 1) / \(Loads.all.count)  \(load.key.rawValue) — \(load.title)  [\(route)]", Self.margin, 12)
        textSize(12)
        fill(150)
        text("← → で候補、スペースで経路 (suspect / reference)、r で回し直す", Self.margin, 34)

        let started = Date()
        let picture = rig?.step(in: self)
        let elapsed = Date().timeIntervalSince(started) * 1000
        samples.append(
            Sample(
                footprint: Double(Meter.footprint()) / 1_048_576, gpu: Double(Meter.gpu()) / 1_048_576,
                milliseconds: elapsed))
        if let picture { image(picture, Self.margin, Self.header, Self.stage, Self.stage) }
        graph(load)
    }

    /// 右の欄: いまの値と、回し始めてからの折れ線。
    func graph(_ load: LoadCase) {
        guard let first = samples.first, let last = samples.last else { return }
        let x = Self.margin * 2 + Self.stage
        let recent = samples.suffix(60)
        let slope = recent.count > 1
            ? (recent.last!.footprint - recent.first!.footprint) * 1024 / Double(recent.count - 1) : 0
        let lines = [
            "回した枚数  \(samples.count)",
            String(format: "footprint  %.1f MB (+%.1f)", last.footprint, last.footprint - first.footprint),
            String(format: "GPU        %.1f MB (+%.1f)", last.gpu, last.gpu - first.gpu),
            String(format: "直近 60 枚の増え方  %.1f KB/枚", slope),
            String(format: "1 枚        %.1f ms", recent.map(\.milliseconds).reduce(0, +) / Double(recent.count)),
            load.measure == .memory ? "見るもの: 増え続けないこと" : "見るもの: 仕事の量に見合う時間",
        ]
        fill(220)
        textSize(13)
        for (row, line) in lines.enumerated() {
            text(line, x, Self.header + Float(row) * 20)
        }

        let top = Self.header + 140
        let height = Self.stage - 140
        stroke(60)
        noFill()
        rect(x, top, Self.graphWidth, height)
        let shown = Array(samples.suffix(Self.history))
        plot(shown.map { $0.footprint - first.footprint }, x: x, top: top, height: height, color: (240, 170, 80))
        plot(shown.map { $0.gpu - first.gpu }, x: x, top: top, height: height, color: (90, 170, 240))
        noStroke()
        fill(240, 170, 80)
        text("footprint の増分", x + 8, top + 8)
        fill(90, 170, 240)
        text("GPU の増分", x + 8, top + 26)
    }

    /// 0 を下端に、最大値を上端に合わせた折れ線。
    func plot(_ values: [Double], x: Float, top: Float, height: Float, color: (Float, Float, Float)) {
        guard values.count > 1 else { return }
        let peak = max(1, values.max() ?? 1)
        stroke(color.0, color.1, color.2)
        noFill()
        beginShape()
        for (i, value) in values.enumerated() {
            let px = x + Float(i) / Float(Self.history - 1) * Self.graphWidth
            let py = top + height - Float(max(0, value) / peak) * height
            vertex(px, py)
        }
        endShape()
    }
}

/// 候補 1 件の 1 経路を回し続ける舞台。
final class Rig {
    let runtime: SketchRuntime?
    private var picture: Image?

    init(_ load: LoadCase, _ route: Route) {
        runtime = try? SketchRuntime(sketch: load.make(route), gpu: Rig.gpu)
    }

    /// 1 枚進めて、その絵を返す。組めなかったら `nil`。
    func step(in host: some Sketch) -> Image? {
        guard let runtime else { return nil }
        do {
            try runtime.advance()
            let shown = try runtime.target.encodeForDisplay()
            if picture?.width != shown.width || picture?.height != shown.height {
                picture = try host.createImage(shown.width, shown.height)
            }
            picture!.write(shown)
            return picture
        } catch {
            return nil
        }
    }

    /// 目盛りと同じ装置で組む (`Meter`)。
    static let gpu = try! Meter.renderDevice()
}
