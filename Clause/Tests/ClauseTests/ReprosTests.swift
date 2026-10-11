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
        withKnownIssue("mokume#未起票: 空の datagram を受けると繋ぎを閉じ、続けて届いた datagram を黙って落とす") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 9216 B を超える datagram も、切らずに 1 つのメッセージになる")
    func udpLargeDatagram() throws {
        let broken = try UdpLargeDatagram.reproduce()
        withKnownIssue("mokume#未起票: 9216 B を超える datagram を UDPPort が切って渡し、OSCPort は捨てる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 受け手のいない宛先への send は、診断を 1 度だけ出す")
    func sendRefusedWarns() throws {
        let broken = try SendRefusedWarns.reproduce()
        withKnownIssue("mokume#未起票: 受け手のいない宛先への send が、1 度だけのはずの診断を出し直す") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: jumpTime に数でない秒を渡しても、time は有限のまま")
    func jumpTimeNonFinite() throws {
        let broken = try JumpTimeNonFinite.reproduce()
        withKnownIssue("mokume#未起票: jumpTime(.nan / .infinity) で time が以後ずっと非有限になる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 観測の枚で pauseTime を呼んでも、作者の時計の秒で止まる")
    func pauseTimeObserved() throws {
        let broken = try PauseTimeObserved.reproduce()
        withKnownIssue("mokume#未起票: 観測の枚で pauseTime を呼ぶと、観測の秒で止まる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: Double に収まらない負の数 (-1e400) も、loadJSONObject は投げる")
    func jsonNegativeOverflow() throws {
        let broken = try JsonNegativeOverflow.reproduce()
        withKnownIssue("mokume#未起票: loadJSONObject が -1e400 を投げずに -inf として読む") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: getFloat は Swift だけの綴り (nan・inf・0x10) を数として読まず、改行は空白として落とす")
    func floatText() throws {
        let broken = try FloatText.reproduce()
        withKnownIssue("mokume#未起票: getFloat が nan を知らせず、inf・0x10 を数として読み、改行を落とさない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: CR だけで改行した XML も、壊れた行を正しく名乗る")
    func xmlCarriageReturn() throws {
        let broken = try XmlCarriageReturn.reproduce()
        withKnownIssue("mokume#未起票: CR だけで改行した XML の壊れた行が、いつも line 1 になる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: UTF-8 として読めた XML は、宣言の encoding に関わらず読める")
    func xmlEncodingDecl() throws {
        let broken = try XmlEncodingDecl.reproduce()
        withKnownIssue("mokume#未起票: UTF-8 として読めた XML を、宣言の encoding で解き直して投げる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 根に width だけを書いた SVG は、viewBox の縦横比で高さが決まる")
    func svgWidthOnly() throws {
        let broken = try SvgWidthOnly.reproduce()
        withKnownIssue("mokume#未起票: 根に width / height の片方だけを書くと、viewBox の縦横比を使わない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: <style> の * の規則は、後に書いても要素名の規則に負ける")
    func svgUniversalSelector() throws {
        let broken = try SvgUniversalSelector.reproduce()
        withKnownIssue("mokume#未起票: <style> の * の規則が、後に書かれると要素名の規則に勝つ") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 128 B に満たない文字の STL も、面があれば読める")
    func stlSmallAscii() throws {
        let broken = try StlSmallAscii.reproduce()
        withKnownIssue("mokume#未起票: 128 B に満たない文字の STL を、面があっても投げる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: 前に空白のある文字の STL は、読めないとして投げる")
    func stlIndentedAscii() throws {
        let broken = try StlIndentedAscii.reproduce()
        withKnownIssue("mokume#未起票: 前に空白 2 つの文字の STL をバイナリとして読み、でたらめな形を返す") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: OBJ の vn の無い面は、他の面に vn があっても形から向きを求める")
    func objMixedNormals() throws {
        let broken = try ObjMixedNormals.reproduce()
        withKnownIssue("mokume#未起票: OBJ で vn のある面と無い面が混ざると、無い面の向きが (0,0,1) になる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: STL の facet normal 0 0 0 の面は、向きを書いた面と同じファイルでも両面になる")
    func stlZeroNormalMixed() throws {
        let broken = try StlZeroNormalMixed.reproduce()
        withKnownIssue("mokume#未起票: STL の 0 0 0 の面が、向きを書いた面と同じファイルだと両面にならない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: OBJ の面に読めない角があれば、読み飛ばしに数える")
    func objBadCorners() throws {
        let broken = try ObjBadCorners.reproduce()
        withKnownIssue("mokume#未起票: OBJ の面の読めない角を、黙って落として読み飛ばしに数えない") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: saveTable で書いた表は、頭のセルが U+FEFF で始まっても同じ表に戻る")
    func saveTableBom() throws {
        let broken = try SaveTableBom.reproduce()
        withKnownIssue("mokume#未起票: saveTable → loadTable で、頭のセルの U+FEFF が落ちる") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }

    @Test("再現: ディレクトリや読む権利の無いファイルは、UTF-8 の問題と名乗らない")
    func textFileDirectory() throws {
        let broken = try TextFileDirectory.reproduce()
        withKnownIssue("mokume#未起票: ディレクトリや読む権利の無いファイルを、UTF-8 として読めないと名乗る") {
            #expect(broken == nil, "\(broken ?? "")")
        }
    }
}
