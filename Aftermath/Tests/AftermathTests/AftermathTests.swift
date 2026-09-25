import Foundation
import Testing
import mokume

@testable import Aftermath

/// 候補ごとの検査。**期待値は「失敗の後の絵は、失敗を起こさなかった参照と同じ」に置く。**
///
/// 各検査は、比べる前に**参照の側が描けていること**を押さえる。参照まで何も出ていないと、
/// 左右が一致しても何も言えないため。
@MainActor
@Suite struct AftermathTests {
    /// 同じ絵とみなす差。**同じ機械・同じフレーム番号ならバイト単位で同じ絵が出る**
    /// (mokume ADR-0001 原則 2) ので、表示の 1 段 (1/255) より小さく置く。
    static let exact: Float = 0.004

    /// 下地より明るい画素の数。参照が描けていることを押さえる。
    static func lit(_ picture: Picture) -> Int {
        picture.count { c, _, _ in max(c.red, c.green, c.blue) > 0.2 }
    }

    /// `frames` の各枚で、2 つの経路が同じ絵であること。
    func expectSame(
        _ a: [Int: Picture], _ b: [Int: Picture], frames: some Sequence<Int>,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        for frame in frames {
            let n = differing(a[frame]!, b[frame]!, threshold: Self.exact)
            #expect(n == 0, "\(frame) 枚目: \(n) 画素が違う", sourceLocation: sourceLocation)
        }
    }

    /// 候補を 2 経路で回し、参照が描けていることを押さえてから `frames` を比べる。
    func compare(_ key: MishapKey, frames: some Sequence<Int>, sourceLocation: SourceLocation = #_sourceLocation)
        throws
    {
        let a = try run(key, .suspect)
        let b = try run(key, .reference)
        let last = Mishaps.named(key).frames
        #expect(Self.lit(b[last]!) > 100, "参照の \(last) 枚目が描けていない", sourceLocation: sourceLocation)
        expectSame(a, b, frames: frames, sourceLocation: sourceLocation)
    }

    static let after = (Mishaps.fault + 1)...

    // MARK: - 資源の生成が投げる (陰性対照)

    @Test("描く途中で資源の生成が投げても、絵は 1 画素も変わらない", arguments: ResourceKind.allCases)
    func resourceThrows(kind: ResourceKind) throws {
        let suspect = ResourceThrows(route: .suspect, kinds: [kind])
        let a = try run(suspect, frames: 4, reading: Set(1...4), dump: "resourceThrows-\(kind)-suspect")
        let b = try run(
            ResourceThrows(route: .reference, kinds: [kind]), frames: 4, reading: Set(1...4),
            dump: "resourceThrows-\(kind)-reference")
        // 2 枚目と 3 枚目の、push の直後と塗りの直後で投げた (投げていなければ陰性対照にならない)
        #expect(suspect.thrown == 4, "\(kind) が投げたのは \(suspect.thrown) 回")
        #expect(Self.lit(b[4]!) > 1000)
        expectSame(a, b, frames: 1...4)
    }

    @Test("同じ RenderDevice でランタイムの組み立てが投げても、後で組んだランタイムの絵は変わらない")
    func runtimeThrows() throws {
        let device = try RenderDevice()
        let broken = [
            SketchSettings(width: 0, height: 160),
            SketchSettings(width: 20000, height: 20000),
            SketchSettings(width: 160, height: 160, pixelDensity: 2),
        ]
        for settings in broken {
            #expect(throws: RenderFailure.self, "\(settings.width)×\(settings.height) @\(settings.pixelDensity)") {
                _ = try SketchRuntime(sketch: Scene(settings) { _ in }, gpu: device)
            }
        }
        let a = try run(
            ResourceThrows(route: .reference, kinds: []), frames: 4, reading: Set(1...4),
            dump: "runtimeThrows-suspect", on: device)
        let b = try run(
            ResourceThrows(route: .reference, kinds: []), frames: 4, reading: Set(1...4),
            dump: "runtimeThrows-reference", on: try RenderDevice())
        #expect(Self.lit(b[4]!) > 1000)
        expectSame(a, b, frames: 1...4)
    }

    @Test("renderFrame(to:) の書き出しが投げても、次のフレームの絵は変わらない")
    func renderFrameThrows() throws {
        let runtime = try SketchRuntime(sketch: ResourceThrows(route: .reference, kinds: []), gpu: gpu)
        defer { runtime.closePlugins() }
        try runtime.advance()
        #expect(throws: (any Error).self) {
            try runtime.renderFrame(to: URL(fileURLWithPath: "/nonexistent-aftermath/frame.png"))
        }
        try runtime.advance()
        let pixels = try runtime.target.readPixels()
        try fingerprint(pixels, name: "renderFrameThrows-suspect", frame: 3)
        let a = Picture(pixels)
        let b = try run(ResourceThrows(route: .reference, kinds: []), frames: 3, dump: "renderFrameThrows-reference")[3]!
        #expect(Self.lit(b) > 1000)
        expectSame([3: a], [3: b], frames: [3])
    }

    @Test("書けない先へ毎フレーム save を頼んでも、本体の絵は変わらない")
    func saveUnwritable() throws { try compare(.saveUnwritable, frames: 1...6) }

    @Test("読み込んだ断片のファイルを壊しても、前の断片で描き続ける")
    func shaderReloadBroken() async throws {
        let reference = try await ReloadedShader.render(replacing: nil)
        let recolored = try await ReloadedShader.render(replacing: ReloadedShader.blue)
        let broken = try await ReloadedShader.render(replacing: "float4 paint(Fragment in, Values values) { return")
        // 対照: 組める中身へ書き換えると、窓を出さずに回しても拾い直される
        // (拾い直されないなら、壊した中身が無視されたのと区別できない)
        #expect(
            differing(recolored, reference, threshold: Self.exact) > 1000,
            "組める中身へ書き換えても絵が変わらない — 拾い直しが走っていない")
        #expect(Self.lit(reference) > 1000)
        expectSame([4: broken], [4: reference], frames: [4])
    }

    // MARK: - フレームの途中で放り出した状態

    @Test("閉じずに抜けた beginShape の点は、次のフレームの形へ持ち越さない")
    func openShape() throws { try compare(.openShape, frames: [1] + Array(Self.after.prefix(2))) }

    @Test("endDraw の無い描き場所の変換は、次のフレームの描き直しに積み上がらない")
    func openGraphicsDraw() throws {
        // 1 枚目と、閉じ直した後の 4 枚目は揃う (比べる舞台が効いている)
        try compare(.openGraphicsDraw, frames: [1, 4])
        try withKnownIssue("mokume#1622: 次の beginDraw() がフレームを始め直さず、変換が積み上がる") {
            try compare(.openGraphicsDraw, frames: [3])
        }
    }

    @Test("beginDraw の外で描き場所へ置いた図形は、描き直しに紛れ込まない")
    func offFrameGraphics() throws { try compare(.offFrameGraphics, frames: 1...4) }

    @Test("createShape の中で閉じなかった形は、本体のフレームへ漏れない")
    func shapeLeak() throws { try compare(.shapeLeak, frames: 1...3) }

    @Test("pop の無い push の後、描き方だけが越え、変換と切り抜きは戻る")
    func unpoppedState() throws {
        let b = try run(.unpoppedState, .reference)
        // 参照の 3 枚目: 赤で加算した矩形が、平行移動も切り抜きも受けずに (20, 20) から描かれる
        let inside = b[3]![30, 30]
        #expect(inside.red > 0.5 && inside.blue < 0.1, "参照の 3 枚目の矩形の色 \(inside)")
        #expect(b[3]![105, 110].red > 0.5, "参照の 3 枚目の円が切り抜かれている")
        try compare(.unpoppedState, frames: [1, 3, 4])
    }

    // MARK: - 検めずに通した値

    @Test("NaN の変換と視点を書いたフレームの後も、平面と立体は参照と同じ")
    func nanTransform() throws { try compare(.nanTransform, frames: [1, 3, 4]) }

    @Test("NaN の力を 1 度かけても、生きている粒は消えない")
    func particleNaNForce() throws {
        // かける前の 1 枚目は揃う
        try compare(.particleNaNForce, frames: [1])
        try withKnownIssue("mokume#1623: 数でない力を検めずに積み、生きている粒がすべて消える") {
            try compare(.particleNaNForce, frames: [3, 10, 40])
        }
    }

    @Test("残像の途中の NaN の効果は、次のフレームからの絵を汚さない")
    func effectNaN() throws { try compare(.effectNaN, frames: [1] + Array(3...8)) }

    @Test("字の焼き場をあふれさせた次のフレームで、字と図形は参照と同じ")
    func glyphOverflow() throws { try compare(.glyphOverflow, frames: [1, 3, 4]) }

    @Test("断片へ無い名前・違う形の値を渡しても、据え置いた値で塗る")
    func shaderSetUnknown() throws { try compare(.shaderSetUnknown, frames: 1...4) }

    @Test("無い書体を名指しても、字は前の書体のまま")
    func missingFont() throws { try compare(.missingFont, frames: 1...4) }
}

/// ファイルから読んだ断片で塗るスケッチ。**保存を拾って組み直す**口を突くのに使う。
final class ReloadedShader: Sketch {
    var settings = Mishaps.settings
    let path: String
    private var glow: Shader!
    private var frame = 0

    static let orange = """
        float4 paint(Fragment in, Values values) {
            return float4(0.95, 0.45, 0.1, 1.0);
        }
        """
    static let blue = """
        float4 paint(Fragment in, Values values) {
            return float4(0.1, 0.4, 0.95, 1.0);
        }
        """

    init(path: String) { self.path = path }
    convenience init() { self.init(path: "") }

    func setup() { glow = try! loadShader(path) }

    func draw() {
        frame += 1
        Mishaps.scenery(self, frame: frame)
        noStroke()
        shader(glow)
        rect(90, 60, 60, 60)
        resetShader()
    }

    /// 橙の断片を読んで 2 枚描き、ファイルを `replacing` で書き換え (nil なら触らない)、
    /// 拾い直しを待ってから 2 枚描いた 4 枚目の絵。
    static func render(replacing body: String?) async throws -> Picture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("aftermath-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("glow.metal")
        try orange.write(to: file, atomically: true, encoding: .utf8)

        let runtime = try SketchRuntime(sketch: ReloadedShader(path: file.path), gpu: gpu)
        defer { runtime.closePlugins() }
        try runtime.advance()
        try runtime.advance()
        if let body { try body.write(to: file, atomically: false, encoding: .utf8) }
        // 保存の知らせは別の列から届き、組み直しは main で走る。main を譲って待つ
        try await Task.sleep(for: .milliseconds(800))
        try runtime.advance()
        try runtime.advance()
        let pixels = try runtime.target.readPixels()
        let name = body == nil ? "reference" : body == blue ? "recolored" : "broken"
        try fingerprint(pixels, name: "shaderReloadBroken-\(name)", frame: 4)
        return Picture(pixels)
    }
}
