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
    @Test("再現: textBounds は色を持つ字形 (絵文字) の墨も囲む")
    func textBoundsColorGlyph() throws {
        let broken = try TextBoundsColorGlyph.reproduce()
        withKnownIssue("mokume#2308: textBounds が色を持つ字形 (絵文字) の墨を囲まない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
