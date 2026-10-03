import Foundation
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

    // MARK: - 出口の取り合い (子プロセス)

    // 4 本とも標準入力・作業ディレクトリ・`NSApp`・プロセスの終わり方に触るので、exit test で子に
    // 閉じ込める。**終了コード 0 が期待どおり、1 が再現**で、`filing.py repro` の単独パッケージと揃う。
    // `WorkDirectory.base` は初めて読まれたときに場所を決めるので、子でなければ他の検査の場所が
    // 残って再現にならない。

    @Test("再現: viewport が在る場所でも、窓なしの SketchRuntime は標準入力を非ブロックにしない")
    func stdinLeftNonBlocking() async {
        await withKnownIssue("mokume#未起票: 区画が在るだけで道具の管と読み、標準入力に O_NONBLOCK を立てて戻さない") {
            await #expect(processExitsWith: .success) {
                if let broken = try await StdinLeftNonBlocking.reproduce() {
                    print(broken)
                    exit(1)
                }
            }
        }
    }

    @Test("再現: viewport が在る場所でも、閉じた標準入力のまま書き出しが全部の枚数を書く")
    func renderBesideViewport() async {
        await withKnownIssue("mokume#未起票: 書き出しの子も区画が在れば標準入力の管を開き、閉じていると道具が去ったと読んで止まる") {
            await #expect(processExitsWith: .success) { _ = try? await RenderBesideViewport.reproduce() }
        }
    }

    @Test("再現: 道具に起こされていないスケッチは、watch の目録を書き換えない")
    func viewportTakeover() async {
        await withKnownIssue("mokume#未起票: 区画が在るだけで共有面へ差し出し、走っている watch の目録を乗っ取る") {
            await #expect(processExitsWith: .success) { _ = try? await ViewportTakeover.reproduce() }
        }
    }

    @Test("再現: 2 つ目の SketchApplication を run しても、1 つ目の録画は開ける", .enabled(if: proResAvailable))
    func secondApplication() async {
        await withKnownIssue("mokume#未起票: 2 つ目の run() を断らず、1 つ目の終了時の後始末を奪って録画が閉じない") {
            await #expect(processExitsWith: .success) { _ = try? await SecondApplication.reproduce() }
        }
    }
}
