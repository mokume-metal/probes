import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、縮めた列の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: 白を越える明るさの background の上でも、不透明な図形は下地を覆う")
    func backgroundOverflowRepro() throws {
        let broken = try BackgroundOverflowRepro.reproduce()
        withKnownIssue("mokume#未起票: background が色を締めずに Float16 の面へ置き、面が +inf を持つ") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: curveDetail に大きな値を渡しても、曲線の点の数は上限で止まる")
    func curveDetailUnboundedRepro() throws {
        let broken = try CurveDetailUnboundedRepro.reproduce()
        withKnownIssue("mokume#未起票: curveDetail が下限だけを締め、渡した数だけ曲線の点を作る") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
