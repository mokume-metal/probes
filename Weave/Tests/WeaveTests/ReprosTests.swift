import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: 一直線に並べた 3 点の太い折れ線 = 同じ 2 点を結ぶ line")
    func polylineJoin() throws {
        let broken = try PolylineJoin.reproduce()
        withKnownIssue("mokume#1644: 任意多角形の折れ目を、形自身の座標軸に沿った正方形で埋める") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
