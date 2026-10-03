import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、縮めた列の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: 白を越える明るさの background の上でも、不透明な図形は下地を覆う")
    func backgroundOverflowRepro() throws {
        let broken = try BackgroundOverflowRepro.reproduce()
        #expect(broken == nil, "mokume#1691 で直った: \(broken ?? "")")
    }

    @Test("再現: curveDetail に大きな値を渡しても、曲線の点の数は上限で止まる")
    func curveDetailUnboundedRepro() throws {
        let broken = try CurveDetailUnboundedRepro.reproduce()
        #expect(broken == nil, "mokume#1692 で直った: \(broken ?? "")")
    }
}
