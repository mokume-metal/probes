import Foundation
import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **別の suite にせず、`SoakTests` の拡張に置く。** `SoakTests` は `.serialized` で、footprint は
/// プロセス全体の値なので、別の suite にすると並べて回り、隣の検査の増え方に混ざる。
///
/// **再現はどれも、exit test (子プロセス) の中で走らせる。**
/// - 落ちる再現は、本来の検査と同じく子プロセスに閉じ込める。
/// - 資源の再現は、溜めたものを戻る前にまとめて手放す。同期の `reproduce()` の中では main actor
///   を譲れないので、GPU の完了の知らせ (mokume#1594) もフレームの数だけ溜まってから解放される。
///   同じプロセスで走らせると、その空きを後の検査の増え方が埋めて、本来の検査の
///   `headlessAdvance` と `modelSequence` が「既知の問題が起きなかった」で赤くなった
///   (2026-09-27)。子プロセスなら、`filing.py repro` が単独で走らせるのと同じ条件にもなる。
extension SoakTests {
    // MARK: - メモリ

    @Test("再現: 閉じ忘れた beginShape が、フレームをまたいで頂点を積み続けない")
    func unclosedShapeRepro() async {
        let broken = await isolated(.unclosedShape)
        withKnownIssue("mokume#1591: 開いた形の印がフレームの境目で下りず、vertex() が点を積み続ける") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: beginDraw の外で描き場所へ置いた図形が、溜まり続けない")
    func offFrameGraphicsRepro() async {
        let broken = await isolated(.offFrameGraphics)
        withKnownIssue("mokume#1592: 図形の口がフレームの外を見ずに溜め場へ積み、捨てる契機が来ない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: sin で脈打つ textSize でも、書体の控えが増え続けない")
    func pulsingTextRepro() async {
        let broken = await isolated(.pulsingText)
        withKnownIssue("mokume#1431: 書体の控えが大きさごとに増え続け、減らす経路も上限も無い") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: main actor を譲らずに advance() を回しても、後始末が溜まらない")
    func headlessAdvanceRepro() async {
        let broken = await isolated(.headlessAdvance)
        withKnownIssue("mokume#1594: GPU の完了の後始末を main actor の Task に積むので、譲らないと走らない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 連番の OBJ を読み進めても、読んだモデルが控えに溜まり続けない")
    func modelSequenceRepro() async {
        let broken = await isolated(.modelSequence)
        withKnownIssue("mokume#1593: loadModel の控えに上限も追い出しも無い") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    // MARK: - 落ちる

    @Test("再現: 巨大な textSize で字を描いても、落ちない")
    func hugeTextSizeRepro() async {
        await withKnownIssue("mokume#1587: 字形の外接矩形を Int へ直すところで、大きさの上限を見ていない") {
            await #expect(processExitsWith: .success) { _ = try? await HugeTextSizeRepro.reproduce() }
        }
    }

    @Test("再現: createShape の中で background() を呼んでも、落ちない")
    func createShapeDiscardRepro() async {
        await withKnownIssue("mokume#1588: 溜め場を空にした後で、入口で覚えた開始位置から切り出す") {
            await #expect(processExitsWith: .success) { _ = try? await CreateShapeDiscardRepro.reproduce() }
        }
    }

    // MARK: - 子プロセス

    /// 資源の再現の名前。exit test の中へは、値として渡す。
    nonisolated enum Resource: String, Codable, Sendable {
        case unclosedShape, offFrameGraphics, pulsingText, headlessAdvance, modelSequence
    }

    /// 印の行。子プロセスの標準出力から、再現の説明だけを拾う。
    nonisolated static let brokenMark = "repro-broken: "

    static func reproduce(_ resource: Resource) throws -> String? {
        switch resource {
        case .unclosedShape: try UnclosedShapeRepro.reproduce()
        case .offFrameGraphics: try OffFrameGraphicsRepro.reproduce()
        case .pulsingText: try PulsingTextRepro.reproduce()
        case .headlessAdvance: try HeadlessAdvanceRepro.reproduce()
        case .modelSequence: try ModelSequenceRepro.reproduce()
        }
    }

    /// 資源の再現を子プロセスで走らせ、返した説明を持ち帰る (期待どおりなら `nil`)。
    ///
    /// 子プロセスは再現が投げても落ちても失敗で終わり、それは既知の問題に数えずに落とす。
    func isolated(_ resource: Resource) async -> String? {
        let result = await #expect(processExitsWith: .success, observing: [\.standardOutputContent]) {
            [resource = resource as SoakTests.Resource] in
            if let broken = try await SoakTests.reproduce(resource) {
                print(SoakTests.brokenMark + broken)
            }
        }
        let output = result.map { String(decoding: $0.standardOutputContent, as: UTF8.self) } ?? ""
        let line = output.split(separator: "\n").first { $0.hasPrefix(Self.brokenMark) }
        return line.map { String($0.dropFirst(Self.brokenMark.count)) }
    }
}
