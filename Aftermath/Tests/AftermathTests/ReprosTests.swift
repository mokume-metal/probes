import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: endDraw() せずに抜けた描き場所の変換は、次のフレームの描き直しに積み上がらない")
    func openGraphicsDraw() throws {
        let broken = try UnclosedDraw.reproduce()
        #expect(broken == nil, "mokume#1622 で直った: \(broken ?? "")")
    }

    @Test("再現: NaN の力を 1 度かけても、生きている粒は消えない")
    func particleNaNForce() throws {
        let broken = try NaNGravity.reproduce()
        #expect(broken == nil, "mokume#1623 で直った: \(broken ?? "")")
    }
}
