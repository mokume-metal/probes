import Foundation
import mokume

/// どちらの経路で描くか。
///
/// **1 つの候補を、同じ絵になるはずの 2 つの経路で描く。** `suspect` は途中のフレームで
/// 失敗を起こし、`reference` は同じフレームで失敗を起こさない (失敗の行を抜くか、正しい
/// 行に置き換える)。失敗した後のフレームは、どちらも同じものを描く。**失敗の後の絵が
/// 食い違えば、失敗が状態を汚して次のフレームへ持ち越している。**
enum Route: CaseIterable, Sendable {
    case suspect
    case reference
}

/// 候補の名前。**隔離の外に置く** — テストの引数は main actor の外で組み立てられる。
nonisolated enum MishapKey: String, CaseIterable, Sendable {
    case resourceThrows, saveUnwritable
    case openShape, openGraphicsDraw, offFrameGraphics, shapeLeak, unpoppedState
    case nanTransform, particleNaNForce, effectNaN, glyphOverflow, shaderSetUnknown, missingFont
}

/// 候補 1 件。**1 経路 = 1 本のスケッチ**で、経路ごとに別の `SketchRuntime` で回す
/// (Routine と同じ形)。面を分け合うと、片方の失敗が隣の経路に漏れて疑いに混ざる。
struct MishapCase {
    let key: MishapKey
    /// 窓のタイルに出す見出し。
    let title: String
    /// 1 巡のフレーム数。
    let frames: Int
    let make: @MainActor (Route) -> any Sketch
}

enum Mishaps {
    /// 1 経路ぶんの一辺 (論理の大きさ)。
    static let side = 160
    static let frameRate = 30
    /// **失敗を起こすフレーム** (1 始まり)。1 枚目は失敗の前の絵として残す。
    static let fault = 2

    static let all: [MishapCase] = [
        MishapCase(key: .resourceThrows, title: "資源の生成が投げる (8 通り)", frames: 4) {
            ResourceThrows(route: $0, kinds: ResourceKind.allCases)
        },
        MishapCase(key: .saveUnwritable, title: "書けない先へ毎フレーム save", frames: 6) { SaveUnwritable(route: $0) },
        MishapCase(key: .openShape, title: "閉じない beginShape", frames: 4) { OpenShape(route: $0) },
        MishapCase(key: .openGraphicsDraw, title: "endDraw の無い描き場所", frames: 4) { OpenGraphicsDraw(route: $0) },
        MishapCase(key: .offFrameGraphics, title: "beginDraw の外で描き場所へ描く", frames: 4) {
            OffFrameGraphics(route: $0)
        },
        MishapCase(key: .shapeLeak, title: "createShape の中で閉じない形", frames: 3) { ShapeLeak(route: $0) },
        MishapCase(key: .unpoppedState, title: "pop の無い push", frames: 4) { UnpoppedState(route: $0) },
        MishapCase(key: .nanTransform, title: "NaN の変換と視点", frames: 4) { NanTransform(route: $0) },
        MishapCase(key: .particleNaNForce, title: "NaN の力を 1 度だけ", frames: 40) { ParticleNaNForce(route: $0) },
        MishapCase(key: .effectNaN, title: "NaN の効果を 1 度だけ (残像)", frames: 8) { EffectNaN(route: $0) },
        MishapCase(key: .glyphOverflow, title: "字の焼き場をあふれさせる", frames: 4) { GlyphOverflow(route: $0) },
        MishapCase(key: .shaderSetUnknown, title: "断片へ無い名前・違う形の値", frames: 4) {
            ShaderSetUnknown(route: $0)
        },
        MishapCase(key: .missingFont, title: "無い書体を名指す", frames: 4) { MissingFont(route: $0) },
    ]

    static func named(_ key: MishapKey) -> MishapCase {
        all.first { $0.key == key }!
    }

    static var settings: SketchSettings {
        SketchSettings(width: side, height: side, frameRate: frameRate, title: "aftermath")
    }

    static let orange = display(240, 140, 40)
    static let blue = display(60, 150, 240)
    static let red = display(220, 40, 40)

    /// 失敗の後に描く、ふつうの絵。**平面・線・字・動くものを 1 枚に揃える** — どの
    /// 状態が汚れても、どこかの画素に出るようにするため。`frame` で右下の四角が動くので、
    /// 番号や時刻がずれても出る。
    ///
    /// `midway` は `push()` の直後と、塗りを決めた直後に呼ぶ。失敗を**描き方を積み上げる
    /// 途中**に起こすためである。
    static func scenery(_ s: some Sketch, frame: Int, midway: () -> Void = {}) {
        s.background(24)
        s.push()
        midway()
        s.noStroke()
        s.fill(orange)
        midway()
        s.rect(16, 16, 56, 56)
        s.fill(blue)
        s.circle(112, 44, 44)
        s.stroke(235)
        s.strokeWeight(3)
        s.line(16, 96, 144, 96)
        s.noStroke()
        s.fill(235)
        s.textSize(24)
        s.text("Aa", 16, 136)
        s.fill(red)
        s.rect(Float(80 + (frame * 9) % 60), 118, 14, 14)
        s.pop()
    }
}

/// 表示の値 (0…255) の色。
func display(_ r: Float, _ g: Float, _ b: Float, _ a: Float = 255) -> LinearRGBA {
    .display(red: r / 255, green: g / 255, blue: b / 255, alpha: a / 255)
}

// MARK: - 資源の生成が投げる (陰性対照)

/// 型のついたエラーを投げる、資源の生成の口。
nonisolated enum ResourceKind: String, CaseIterable, Sendable {
    case loadImage, makeShader, makeEffect, makeComputation, createGraphics, createImage, makeNumbers, loadModel
}

/// 描く途中で資源の生成を失敗させる。
///
/// [ADR-0020] 決定 5 は「資源の生成・初期化は型のついたエラーを投げる」と決めている。
/// 投げた口は何も作らずに返るはずなので、**行を抜いた参照と 1 画素も違わない**はずである
/// (陰性対照)。失敗を `push()` と塗りの間に挟み、描き方を積む途中で投げさせる。
///
/// [ADR-0020]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0020-api-naming-and-surface.md
final class ResourceThrows: Sketch {
    var settings = Mishaps.settings
    let route: Route
    let kinds: [ResourceKind]
    private var frame = 0
    /// 投げた回数。投げていなければ、陰性対照として何も言えない。
    private(set) var thrown = 0

    init(route: Route, kinds: [ResourceKind]) {
        self.route = route
        self.kinds = kinds
    }
    convenience init() { self.init(route: .reference, kinds: []) }

    func draw() {
        frame += 1
        let failing = route == .suspect && frame >= Mishaps.fault && frame <= Mishaps.fault + 1
        Mishaps.scenery(self, frame: frame) {
            guard failing else { return }
            for kind in kinds where fail(kind) { thrown += 1 }
        }
    }

    /// `kind` の口を投げる引数で呼ぶ。投げたら `true`。
    func fail(_ kind: ResourceKind) -> Bool {
        let nowhere = "/nonexistent-aftermath"
        do {
            switch kind {
            case .loadImage: _ = try loadImage("\(nowhere)/a.png")
            case .makeShader: _ = try makeShader("not a fragment", name: "broken")
            case .makeEffect: _ = try makeEffect("not an effect", name: "broken")
            case .makeComputation: _ = try makeComputation("not a computation", name: "broken")
            case .createGraphics: _ = try createGraphics(20000, 10)
            case .createImage: _ = try createImage(20000, 1)
            case .makeNumbers: _ = try makeNumbers(count: 1 << 40)
            case .loadModel: _ = try loadModel("\(nowhere)/a.obj")
            }
            return false
        } catch {
            return true
        }
    }
}

/// 書けない先へ毎フレーム `save()` を頼む。
///
/// `save` は投げず、書けなければ警告して撮る係の健康状態に数えるだけ、と読める。撮る係は
/// 出口と同じ 1 枚を受け取る ([ADR-0023] 決定 2) ので、**書き出しに失敗しても本体の絵は
/// 変わらない**はずである。
///
/// [ADR-0023]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0023-frame-stages-and-outputs.md
final class SaveUnwritable: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        Mishaps.scenery(self, frame: frame)
        if route == .suspect { save("/nonexistent-aftermath/frame-\(frame).png") }
    }
}

// MARK: - フレームの途中で放り出した状態

/// 失敗のフレームで `beginShape()` を閉じずに抜け、次のフレームで別の形を描く。
///
/// [ADR-0021] 決定 4 の追補 (2026-09-06) は「積んだ事実はフレームに属する」と決めている。
/// 形を組み立てている途中という事実もフレームの境目で下りるはずで、**次のフレームの形は
/// 前のフレームの点を引き継がない。**
///
/// [ADR-0021]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0021-solid-space-and-frame-assembly.md
final class OpenShape: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        background(24)
        noStroke()
        fill(Mishaps.orange)
        if frame == Mishaps.fault {
            guard route == .suspect else { return }
            beginShape()
            vertex(150, 150)
            vertex(150, 10)
            return
        }
        beginShape()
        vertex(30, 30)
        vertex(130, 30)
        vertex(130, 130)
        vertex(30, 130)
        endShape(.close)
    }
}

/// 失敗のフレームで描き場所の `beginDraw()` をして、`endDraw()` をせずに抜ける。
///
/// 変換はシーンの記述で、フレームを越えない ([ADR-0021] 決定 4)。次のフレームで描き場所を
/// 描き直すときの `translate` は、**前のフレームで積んだ `translate` に重ならない**はずである。
///
/// [ADR-0021]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0021-solid-space-and-frame-assembly.md
final class OpenGraphicsDraw: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    private var layer: Canvas!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() { layer = try! createGraphics(Mishaps.side, Mishaps.side) }

    func draw() {
        frame += 1
        background(24)
        if frame == Mishaps.fault {
            guard route == .suspect else { return }
            layer.beginDraw()
            layer.translate(40, 0)
            return
        }
        layer.beginDraw()
        layer.background(LinearRGBA.transparent)
        layer.noStroke()
        layer.fill(Mishaps.orange)
        layer.translate(40, 0)
        layer.circle(40, 80, 40)
        layer.endDraw()
        image(layer, 0, 0)
    }
}

/// 失敗のフレームで、`beginDraw()` の外から描き場所へ図形を置く。
///
/// 描き場所の説明は「描くのは `beginDraw()` と `endDraw()` の間」と読める。外で置いた
/// 図形は断られるはずで、**次に描き直したときに紛れ込まない。**
final class OffFrameGraphics: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    private var layer: Canvas!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() { layer = try! createGraphics(Mishaps.side, Mishaps.side) }

    func draw() {
        frame += 1
        background(24)
        if route == .suspect && frame == Mishaps.fault {
            layer.noStroke()
            layer.fill(Mishaps.red)
            layer.circle(120, 120, 40)
        }
        layer.beginDraw()
        layer.background(LinearRGBA.transparent)
        layer.noStroke()
        layer.fill(Mishaps.blue)
        layer.rect(20, 20, 50, 50)
        layer.endDraw()
        image(layer, 0, 0)
    }
}

/// `setup()` の `createShape` の中で `beginShape()` を閉じずに抜ける。
///
/// 積む・降ろすが釣り合う単位は、フレームか形の組み立てのどちらかである ([ADR-0021]
/// 決定 4 の追補 2026-09-15)。組み立ての中で開いた形は組み立ての中で閉じるはずで、
/// **本体の最初のフレームの形へ漏れない。**
///
/// [ADR-0021]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0021-solid-space-and-frame-assembly.md
final class ShapeLeak: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    private var kept: Shape!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() {
        kept = createShape {
            circle(0, 0, 10)
            if route == .suspect {
                beginShape()
                vertex(150, 150)
                vertex(150, 10)
            }
        }
    }

    func draw() {
        frame += 1
        background(24)
        noStroke()
        fill(Mishaps.orange)
        beginShape()
        vertex(30, 30)
        vertex(130, 30)
        vertex(130, 130)
        vertex(30, 130)
        endShape(.close)
    }
}

/// 失敗のフレームで `push()` の後に描き方とシーンの記述を書き、`pop()` せずに抜ける。
///
/// [ADR-0021] 決定 4 の表と追補 (2026-09-06) から、次のフレームの状態は一意に決まる。
///
/// - **描き方 (塗り・混ぜ方) は越える。** 書いた赤と加算が残る。
/// - **シーンの記述 (変換・切り抜き) は越えない。** 平行移動と切り抜きは戻る。
/// - **積んだ履歴は越えない。** 積んだ段は捨てられ、次のフレームへ降りてこない。
///
/// 参照は同じことを `pop()` で閉じた上で、越えるはずの描き方を明示的に書き直す。
///
/// [ADR-0021]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0021-solid-space-and-frame-assembly.md
final class UnpoppedState: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        background(24)
        noStroke()
        if frame == Mishaps.fault {
            push()
            fill(Mishaps.red)
            blendMode(.add)
            translate(50, 0)
            clip(0, 0, 60, 60)
            rect(0, 0, 40, 40)
            if route == .reference {
                pop()
                fill(Mishaps.red)
                blendMode(.add)
            }
            return
        }
        rect(20, 20, 60, 60)
        circle(110, 110, 50)
    }
}

// MARK: - 検めずに通した値

/// 失敗のフレームで、数でない平行移動・無限の回転・数でない視点を書く。
///
/// 変換と視点はシーンの記述で、フレームを越えない ([ADR-0021] 決定 4)。成り立たない
/// 視点は警告して据え置く (`camera` の説明)。**次のフレームの平面と立体は、NaN を
/// 書かなかった参照と同じ**はずである。
///
/// [ADR-0021]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0021-solid-space-and-frame-assembly.md
final class NanTransform: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        if route == .suspect && frame == Mishaps.fault {
            translate(Float.nan, 0)
            rotate(Float.infinity)
            camera(Float.nan, 0, 0, 0, 0, 0, 0, 1, 0)
        }
        Mishaps.scenery(self, frame: frame)
        push()
        noStroke()
        fill(Mishaps.blue)
        translate(116, 116)
        rotateX(0.6)
        rotateY(0.4)
        box(40)
        pop()
    }
}

/// 失敗のフレームで、粒に数でない力を 1 度だけかける。
///
/// フレームごとに呼ばれる口は投げずに「受け口で値を検証し、警告を出して安全な既定へ
/// 倒す」([ADR-0020] 決定 5)。数でない力は捨てられるか 0 に倒されるはずで、**生きている
/// 粒の位置と速さに NaN が残らない。** 参照は同じフレームに 0 の力を 1 つかける (力の
/// 数を揃える)。
///
/// [ADR-0020]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0020-api-naming-and-surface.md
final class ParticleNaNForce: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    private var dust: Particles!

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() { dust = try! makeParticles(count: 512) }

    func draw() {
        frame += 1
        background(12)
        let up = -Float.pi / 2
        emit(
            dust, from: .point(80, 150), rate: 60, speed: 40...60, angle: (up - 0.4)...(up + 0.4),
            life: 2...2, size: 5...5, color: Mishaps.orange)
        force(dust, .gravity(0, 20))
        if frame == Mishaps.fault {
            force(dust, route == .suspect ? .gravity(Float.nan, 0) : .gravity(0, 0))
        }
        particles(dust)
    }
}

/// 背景を塗り直さない残像の途中で、数でない強さの効果を 1 度だけ掛ける。
///
/// 効果は出口にだけ掛かり、次のフレームは効果を通す前の絵 (控え) から続く
/// (mokume#1469 の約束)。数でない強さでその 1 枚の出口が乱れても、**控えは汚れず、次の
/// フレームからの絵は参照と同じ**はずである。参照は同じフレームに強さ 0 の同じ効果を
/// 掛ける (効果の経路を同じだけ通す)。
final class EffectNaN: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        if frame == 1 { background(24) }
        noStroke()
        fill(Mishaps.orange)
        circle(Float(12 + frame * 16), 80, 18)
        if frame == Mishaps.fault {
            effects([.invert(amount: route == .suspect ? Float.nan : 0)])
        }
    }
}

/// 失敗のフレームで、字の焼き場があふれるほど多くの字を大きく描く。
///
/// 焼き場を使い切ったフレームは警告して字を落とし、**焼き直しは次のフレームで戻る**
/// (`Canvas+Glyph` の説明)。次のフレームの字と図形は、あふれさせなかった参照と同じ
/// はずである。
final class GlyphOverflow: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    /// あふれさせる字の数。漢字の頭から取る。
    static let flood = 2000

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        if route == .suspect && frame == Mishaps.fault {
            background(24)
            fill(235)
            textSize(160)
            for i in 0..<Self.flood {
                text(String(UnicodeScalar(0x4E00 + i)!), 0, 150)
            }
        }
        Mishaps.scenery(self, frame: frame)
    }
}

/// 失敗のフレームで、断片へ宣言していない名前と、形の違う値を渡す。
///
/// 未宣言の名前・形違いは警告して据え置く (`ShaderBox` の説明)。**据え置いた値で塗った
/// 絵は、渡さなかった参照と同じ**はずである。
final class ShaderSetUnknown: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0
    private var glow: Shader!

    static let body = """
        float4 paint(Fragment in, Values values) {
            return float4(values.level, 0.35, 0.2, 1.0);
        }
        """

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func setup() { glow = try! makeShader(Self.body, name: "glow", values: ["level": 0.8]) }

    func draw() {
        frame += 1
        if route == .suspect && frame == Mishaps.fault {
            glow.set("nope", 1)
            glow.set("level", .pair(1, 1))
        }
        Mishaps.scenery(self, frame: frame)
        noStroke()
        shader(glow)
        rect(90, 60, 60, 30)
        resetShader()
    }
}

/// フレームの途中で、無い書体を名指す。
///
/// 無い書体は警告して据え置く (`textFont` の説明)。**字は名指す前の書体のまま**で、
/// 名指さなかった参照と同じはずである。
final class MissingFont: Sketch {
    var settings = Mishaps.settings
    let route: Route
    private var frame = 0

    init(route: Route) { self.route = route }
    convenience init() { self.init(route: .reference) }

    func draw() {
        frame += 1
        Mishaps.scenery(self, frame: frame) {
            if route == .suspect && frame >= Mishaps.fault { textFont("NoSuchFont-Aftermath") }
        }
    }
}
