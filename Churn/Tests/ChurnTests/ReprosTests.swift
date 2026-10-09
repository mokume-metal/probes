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
    @Test("再現: 2 領域の形を shape(at:) で重なる 2 か所へまとめて置く = 1 か所ずつ置く")
    func shapeAtRegions() throws {
        let broken = try ShapeAtRegions.reproduce()
        withKnownIssue("mokume#未起票: shape(_:at:) が記録した領域ごとに置き場所を回し、重なる置き場所の前後が入れ替わる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 捨てた描き場所の ObjectIdentifier を引き継いだ描き場所も、置いた時点の絵が出る")
    func graphicsReuse() throws {
        let broken = try GraphicsReuse.reproduce()
        withKnownIssue("mokume#未起票: 捨てた描き場所の ObjectIdentifier を引き継ぐと、置いた時点の絵が保たれない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
