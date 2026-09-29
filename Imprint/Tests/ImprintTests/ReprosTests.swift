import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (書き出せない) は
/// 既知の問題に数えず、そのまま落とす。動画を書く再現は、ProRes 4444 を書けない機械では
/// 本来の検査と同じく飛ばす。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite(.serialized) struct ReprosTests {
    @Test("再現: 録画中に書けない先へ 1 度 save しても、動画は 1 枚も欠けない", .enabled(if: proResAvailable))
    func saveFailureKeepsMovie() throws {
        let broken = try SaveFailureMovie.reproduce()
        #expect(broken == nil, "mokume#1626 で直った: \(broken ?? "")")
    }

    /// 空いた機械では稀にしか崩れないので、再現の中で機械を混ませて 20 試行を繰り返す (数秒)。
    /// それでも出ない回がありうるので、本来の検査と同じく `isIntermittent` で包む。
    @Test("再現: 同じ名前へ毎フレーム save すると、残るのは最後のフレームの絵")
    func sameNameSave() throws {
        let broken = try SameNameSave.reproduce()
        #expect(broken == nil, "mokume#1627 で直った: \(broken ?? "")")
    }

    @Test("再現: 同じ入力から 2 回書き出した .mov は、バイトまで一致する", .enabled(if: proResAvailable))
    func byteDeterminism() throws {
        let broken = try MovieBytes.reproduce()
        withKnownIssue("mokume#1628: 秒の境目をまたぐと、容れ物の作成・更新時刻だけが違う") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
