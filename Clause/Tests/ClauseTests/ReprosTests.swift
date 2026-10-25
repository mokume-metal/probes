import Foundation
import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (読めない・組めない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **Clause では、再現そのものが検査である。** 約束の 1 文を確かめる形は再現と同じで、陰性対照
/// (破れない隣の条件) は各再現の中で先に確かめ、崩れたら `control broke` を返す。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite(.serialized) struct ReprosTests {
    @Test("再現: 空の datagram の後に続けて届いた datagram も、1 つずつメッセージになる")
    func udpEmptyDatagram() throws {
        let broken = try UdpEmptyDatagram.reproduce()
        #expect(broken == nil, "mokume#2324 で直った: \(broken ?? "")")
    }

    @Test("再現: datagram は 9215 B まで全長で届き、9216 B 以上は丸ごと捨てて知らせる (mokume#2325 で改まった約束)")
    func udpLargeDatagram() throws {
        let broken = try UdpLargeDatagram.reproduce()
        #expect(broken == nil, "mokume#2325 で改まった約束 (9215 B まで・9216 B 以上は捨てて数える) と違う: \(broken ?? "")")
    }

    @Test("再現: 受け手のいない宛先への send は、診断を 1 度だけ出す")
    func sendRefusedWarns() throws {
        let broken = try SendRefusedWarns.reproduce()
        #expect(broken == nil, "mokume#2326 で直った: \(broken ?? "")")
    }

    @Test("再現: jumpTime に数でない秒を渡しても、time は有限のまま")
    func jumpTimeNonFinite() throws {
        let broken = try JumpTimeNonFinite.reproduce()
        #expect(broken == nil, "mokume#2327 で直った: \(broken ?? "")")
    }

    @Test("再現: 観測の枚で pauseTime を呼んでも、作者の時計の秒で止まる")
    func pauseTimeObserved() throws {
        let broken = try PauseTimeObserved.reproduce()
        #expect(broken == nil, "mokume#2328 で直った: \(broken ?? "")")
    }

    @Test("再現: Double に収まらない負の数 (-1e400) も、loadJSONObject は投げる")
    func jsonNegativeOverflow() throws {
        let broken = try JsonNegativeOverflow.reproduce()
        #expect(broken == nil, "mokume#2329 で直った: \(broken ?? "")")
    }

    @Test("再現: getFloat は Swift だけの綴り (nan・inf・0x10) を数として読まず、改行は空白として落とす")
    func floatText() throws {
        let broken = try FloatText.reproduce()
        #expect(broken == nil, "mokume#2330 で直った: \(broken ?? "")")
    }

    @Test("再現: CR だけで改行した XML も、壊れた行を正しく名乗る")
    func xmlCarriageReturn() throws {
        let broken = try XmlCarriageReturn.reproduce()
        #expect(broken == nil, "mokume#2331 で直った: \(broken ?? "")")
    }

    @Test("再現: UTF-8 として読めた XML は、宣言の encoding に関わらず読める")
    func xmlEncodingDecl() throws {
        let broken = try XmlEncodingDecl.reproduce()
        #expect(broken == nil, "mokume#2332 で直った: \(broken ?? "")")
    }

    @Test("再現: 根に width だけを書いた SVG は、viewBox の縦横比で高さが決まる")
    func svgWidthOnly() throws {
        let broken = try SvgWidthOnly.reproduce()
        #expect(broken == nil, "mokume#2333 で直った: \(broken ?? "")")
    }

    @Test("再現: <style> の * の規則は、後に書いても要素名の規則に負ける")
    func svgUniversalSelector() throws {
        let broken = try SvgUniversalSelector.reproduce()
        #expect(broken == nil, "mokume#2334 で直った: \(broken ?? "")")
    }

    @Test("再現: 128 B に満たない文字の STL も、面があれば読める")
    func stlSmallAscii() throws {
        let broken = try StlSmallAscii.reproduce()
        #expect(broken == nil, "mokume#2335 で直った: \(broken ?? "")")
    }

    @Test("再現: 前に空白のある文字の STL は、読めないとして投げる")
    func stlIndentedAscii() throws {
        let broken = try StlIndentedAscii.reproduce()
        #expect(broken == nil, "mokume#2336 で直った: \(broken ?? "")")
    }

    @Test("再現: OBJ の vn の無い面は、他の面に vn があっても形から向きを求める")
    func objMixedNormals() throws {
        let broken = try ObjMixedNormals.reproduce()
        #expect(broken == nil, "mokume#2337 で直った: \(broken ?? "")")
    }

    @Test("再現: STL の facet normal 0 0 0 の面は、向きを書いた面と同じファイルでも両面になる")
    func stlZeroNormalMixed() throws {
        let broken = try StlZeroNormalMixed.reproduce()
        #expect(broken == nil, "mokume#2338 で直った: \(broken ?? "")")
    }

    @Test("再現: OBJ の面に読めない角があれば、読み飛ばしに数える")
    func objBadCorners() throws {
        let broken = try ObjBadCorners.reproduce()
        #expect(broken == nil, "mokume#2339 で直った: \(broken ?? "")")
    }

    @Test("再現: saveTable で書いた表は、頭のセルが U+FEFF で始まっても同じ表に戻る")
    func saveTableBom() throws {
        let broken = try SaveTableBom.reproduce()
        #expect(broken == nil, "mokume#2340 で直った: \(broken ?? "")")
    }

    @Test("再現: ディレクトリや読む権利の無いファイルは、UTF-8 の問題と名乗らない")
    func textFileDirectory() throws {
        let broken = try TextFileDirectory.reproduce()
        #expect(broken == nil, "mokume#2341 で直った: \(broken ?? "")")
    }

    // MARK: - 書き出しの子 (exit test)

    /// 書き出しの子は `SketchApplication.run()` から戻らず、プロセスごと終わる。exit test に閉じ込め、
    /// 終わり方と書けたファイルを親で読む。**終わり方の期待は包みの外に置く** — 直り方が「書ける」
    /// (0 で終わり中身がある) でも「断る」(0 以外で終わる) でも、どちらかで赤くなって知らせる。
    @Test("再現: mokume render の .mp4 は、高さ 1 の作品でも中身を書くか、書けないと名乗る")
    func mp4ThinFrame() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("clause-mp4-thin-\(getpid())").path
        try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
        let control = directory + "/64x2.mp4", thin = directory + "/64x1.mp4"
        await #expect(processExitsWith: .success) { [control = control as String] in
            try await Mp4ThinFrame.renderAsChild(width: 64, height: 2, to: control)
        }
        #expect(Mp4ThinFrame.bytes(at: control) > 0, "control broke: 64x2 wrote \(Mp4ThinFrame.bytes(at: control)) B")
        let ended = await #expect(processExitsWith: .success, observing: [\.standardErrorContent]) { [thin = thin as String] in
            try await Mp4ThinFrame.renderAsChild(width: 64, height: 1, to: thin)
        }
        let said = String(decoding: ended?.standardErrorContent ?? [], as: UTF8.self)
        let broken = Mp4ThinFrame.verdict(.init(status: 0, bytes: Mp4ThinFrame.bytes(at: thin), said: said))
        withKnownIssue("mokume#未起票: H.264 が辺 1 で 0 バイトを書いても、子は名乗らず 0 で終わる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
