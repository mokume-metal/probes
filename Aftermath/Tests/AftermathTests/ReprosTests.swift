import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: endDraw() せずに抜けた描き場所の変換は、次のフレームの描き直しに積み上がらない")
    func openGraphicsDraw() throws {
        let broken = try UnclosedDraw.reproduce()
        withKnownIssue("mokume#1622: 次の beginDraw() がフレームを始め直さず、変換が積み上がる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: NaN の力を 1 度かけても、生きている粒は消えない")
    func particleNaNForce() throws {
        let broken = try NaNGravity.reproduce()
        withKnownIssue("mokume#1623: 数でない力を検めずに積み、生きている粒がすべて消える") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
