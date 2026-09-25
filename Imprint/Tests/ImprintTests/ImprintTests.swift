import CoreMedia
import Foundation
import Testing
import mokume

@testable import Imprint

/// 書き出したファイルの中身の検査。**期待値は mokume の説明と ADR が約束していることに置く。**
///
/// どの検査も、書き出させたものを**ファイルとして読み戻して**判定する。フレームには番号を
/// 焼いてある (`Stamp`) ので、どのフレームが何枚入ったかを絵そのものから読める。
/// `runningSketch` は 1 つしか無いので、検査は順に回す。
@MainActor
@Suite(.serialized) struct ImprintTests {
    // MARK: - 何枚・どの番号が入るか

    /// 録りの範囲は、呼んだフレームの絵から `endRecord()` を呼んだフレームの 1 つ前まで
    /// (`beginRecord` の説明、mokume#1456)。直前の `save` には左右されない。
    @Test("a 枚目で撮り始めて b 枚目で止めた動画は、a…b−1 の番号を欠けも重なりも無く持つ", .enabled(if: proResAvailable))
    func recordRange() async throws {
        let dir = try scratch("range")
        let movie = dir.appendingPathComponent("range.mov")
        try produce(
            Ticker { s in
                if s.frameCount == 4 { s.save(dir.appendingPathComponent("before.png").path) }
                if s.frameCount == 5 { s.beginRecord(movie.path) }
                if s.frameCount == 25 { s.endRecord() }
            }, frames: 30)
        let got = try await readMovie(movie)
        #expect(got.numbers == Array(5..<25))
        // 直前の save も、その番号の絵を書いている
        #expect(try readPNG(dir.appendingPathComponent("before.png")).number == 4)
    }

    /// 連番は、その録りの中で 0 から振る。`#` の数が桁で、足りなければ切り詰めずに伸びる
    /// (`beginRecord` の説明)。
    @Test("連番は 0 から振られ、桁が足りなければ伸び、各ファイルは頼んだフレームの絵")
    func sequenceNumbering() throws {
        let dir = try scratch("sequence")
        let pattern = dir.appendingPathComponent("f-##.png").path
        try produce(
            Ticker { s in
                if s.frameCount == 3 { s.beginRecord(pattern) }
                if s.frameCount == 123 { s.endRecord() }
            }, frames: 125)
        let expected = (0..<120).map { String(format: "f-%02d.png", $0) }
        #expect(try names(in: dir) == expected.sorted())
        for (index, name) in expected.enumerated() {
            let number = try readPNG(dir.appendingPathComponent(name)).number
            #expect(number == 3 + index, "\(name) は \(number) 枚目の絵")
        }
    }

    // MARK: - 時刻

    /// 各フレームの時刻は、そのフレーム自身の時刻 (フレーム番号の時計なら (n − 1) / fps)。
    /// 長さは最後のフレーム + 1/fps まで (mokume#1457)。
    ///
    /// 読み戻す時刻は**動画の中の再生の時間軸** (1 枚目が 0) である。録り始めの時刻は編集の
    /// 区間 (media start) の側に入るので、ここでは間隔と長さだけを比べる。
    @Test("時刻の間隔はどこも 1/fps で、長さは枚数 / fps", .enabled(if: proResAvailable), arguments: [24, 30, 60])
    func ptsSpacing(fps: Int) async throws {
        let dir = try scratch("pts-\(fps)")
        let movie = dir.appendingPathComponent("pts.mov")
        try produce(
            Ticker(frameRate: fps) { s in
                if s.frameCount == 3 { s.beginRecord(movie.path) }
                if s.frameCount == 33 { s.endRecord() }
            }, frames: 35)
        let got = try await readMovie(movie)
        let step = Int64(90000 / fps)
        #expect(got.numbers == Array(3..<33))
        let gaps = zip(got.ticks.dropFirst(), got.ticks).map { $0 - $1 }
        #expect(gaps.allSatisfy { $0 == step }, "間隔: \(Set(gaps).sorted())")
        #expect(abs(got.duration - 30 / Double(fps)) < 1e-6, "長さ \(got.duration) 秒")
    }

    /// 時刻はフレーム番号から一意に決まる (mokume ADR-0025 決定 1)。**128 秒を越えると、
    /// Float の時刻の刻み (約 15 µs) が動画の刻み (1/90000 秒 ≈ 11 µs) より粗くなる**ので、
    /// 時刻を Float から作っていると間隔が揺れる。
    @Test("128 秒を越えた所から撮っても、時刻の間隔は 1/fps のまま", .enabled(if: proResAvailable))
    func ptsLate() async throws {
        let dir = try scratch("pts-late")
        let movie = dir.appendingPathComponent("late.mov")
        let start = 128 * 60 + 10
        try produce(
            Ticker(height: 16) { s in
                if s.frameCount == start { s.beginRecord(movie.path) }
                if s.frameCount == start + 60 { s.endRecord() }
            }, frames: start + 62)
        let got = try await readMovie(movie)
        #expect(got.numbers == Array(start..<start + 60))
        let gaps = zip(got.ticks.dropFirst(), got.ticks).map { $0 - $1 }
        #expect(gaps.allSatisfy { $0 == 1500 }, "間隔 (刻み): \(Dictionary(grouping: gaps) { $0 }.mapValues(\.count))")
    }

    // MARK: - 出口どうしの関わり

    /// 絵が落ちるのは描けなかったときだけ (mokume ADR-0025 決定 2)。静止画の書き出しが
    /// 1 度失敗しても、同じ絵を受け取る録画 (ADR-0023 決定 2) の枚数は変わらないはずである。
    @Test("録画中に書けない先へ 1 度 save しても、動画は 1 枚も欠けない", .enabled(if: proResAvailable))
    func saveFailureKeepsMovie() async throws {
        let dir = try scratch("save-failure")
        func record(_ name: String, failing: Bool) throws -> URL {
            let movie = dir.appendingPathComponent(name)
            try produce(
                Ticker { s in
                    if s.frameCount == 3 { s.beginRecord(movie.path) }
                    if failing && s.frameCount == 10 { s.save("/nonexistent-imprint/still.png") }
                    if s.frameCount == 43 { s.endRecord() }
                }, frames: 45)
            return movie
        }
        // 対照: 失敗させなければ 40 枚そろう
        let control = try await readMovie(try record("control.mov", failing: false))
        #expect(control.numbers == Array(3..<43))
        let got = try await readMovie(try record("failing.mov", failing: true))
        withKnownIssue("mokume#1626: save の失敗の印が消えず、3 フレーム後に撮る係ごと外れて動画が途切れる") {
            #expect(got.numbers == Array(3..<43), "\(got.frames.count) 枚、最後は \(got.numbers.last ?? -1) 枚目")
        }
    }

    /// 同じ名前へ撮り直したら、ファイルはその録りの中身だけになる。
    @Test("同じ .mov へ短く撮り直すと、中身は新しい録りの枚数と番号だけ", .enabled(if: proResAvailable))
    func rerecordMovie() async throws {
        let dir = try scratch("rerecord")
        let movie = dir.appendingPathComponent("again.mov")
        try produce(
            Ticker { s in
                if s.frameCount == 1 { s.beginRecord(movie.path) }
                if s.frameCount == 31 { s.endRecord() }
            }, frames: 32)
        try produce(
            Ticker { s in
                if s.frameCount == 7 { s.beginRecord(movie.path) }
                if s.frameCount == 12 { s.endRecord() }
            }, frames: 13)
        let got = try await readMovie(movie)
        #expect(got.numbers == Array(7..<12))
        let left = try names(in: dir)
        #expect(left == ["again.mov"], "置き場に残ったもの: \(left)")
    }

    /// `save` は呼んだフレームの絵を書く (`save` の説明)。同じ名前へ毎フレーム頼めば、
    /// 最後に残るのは最後に頼んだフレームの絵のはずである。書く仕事は 1 枚ずつ別に走るので、
    /// 順番が崩れれば前の絵が後から上書きする。**20 回繰り返して、1 回でも崩れたら破れ。**
    @Test("同じ名前へ毎フレーム save すると、残るのは最後のフレームの絵")
    func sameNameSave() throws {
        var last: [Int] = []
        for trial in 0..<20 {
            let dir = try scratch("same-name-\(trial)")
            let file = dir.appendingPathComponent("latest.png")
            try produce(Ticker { s in s.save(file.path) }, frames: 30)
            last.append(try readPNG(file).number)
        }
        // 1 回では稀にしか崩れない (1 プロセスずつで 600 試行に 1 回)。反復・同時実行で回すと
        // 出やすい (scripts/stress.py、ADR-0007)
        withKnownIssue("mokume#1627: 書く仕事の順序が保たれず、前のフレームの絵が後から上書きする", isIntermittent: true) {
            #expect(last.allSatisfy { $0 == 30 }, "残った絵の番号: \(last)")
        }
    }

    // MARK: - 色

    /// PNG は Display P3 を刻む。数で書いた色は sRGB の原色として作業空間へ移す (mokume#911
    /// の決着、ADR-0011)。`fill(204, 153, 0)` の生のバイトは P3 で (196, 155, 51) になり、
    /// 灰色は原色によらず数のまま。
    @Test("PNG は Display P3 を刻み、数で書いた色は sRGB の原色として書かれる")
    func pngColorTag() throws {
        let dir = try scratch("color")
        let file = dir.appendingPathComponent("color.png")
        try produce(
            Ticker { s in
                guard s.frameCount == 3 else { return }
                s.fill(204, 153, 0)
                s.rect(0, 20, 60, 40)
                s.fill(128)
                s.rect(80, 20, 60, 40)
                s.save(file.path)
            }, frames: 4)
        let png = try readPNG(file)
        #expect(png.colorSpace == "kCGColorSpaceDisplayP3", "刻まれた色空間: \(png.colorSpace ?? "無い")")
        let (r, g, b) = png[30, 40]
        #expect(abs(r - 196) <= 1 && abs(g - 155) <= 1 && abs(b - 51) <= 1, "橙の生のバイト (\(r), \(g), \(b))")
        let gray = png[110, 40]
        #expect(gray == (128, 128, 128), "灰色の生のバイト \(gray)")
    }

    /// 静止画・連番・動画は 1 回の読み戻しから配る同じ絵 (ADR-0023 決定 2)。動画は ProRes 4444
    /// で、原色 P3_D65・転送 IEC_sRGB・行列 709_2 を宣言する (`MovieFile`)。符号化の差は
    /// 最大 2 階調 (mokume の実測)。
    @Test("同じフレームの動画と PNG の差は 2 階調以内で、動画は色の宣言を持つ", .enabled(if: proResAvailable))
    func movieMatchesPNG() async throws {
        let dir = try scratch("match")
        let movie = dir.appendingPathComponent("match.mov")
        let still = dir.appendingPathComponent("match.png")
        try produce(
            Ticker { s in
                if s.frameCount == 3 { s.beginRecord(movie.path) }
                if s.frameCount == 10 { s.save(still.path) }
                if s.frameCount == 23 { s.endRecord() }
            }, frames: 25)
        let got = try await readMovie(movie)
        let png = try readPNG(still)
        #expect(got.codec == kCMVideoCodecType_AppleProRes4444)
        #expect(got.primaries == (kCMFormatDescriptionColorPrimaries_P3_D65 as String))
        #expect(got.transfer == (kCMFormatDescriptionTransferFunction_sRGB as String))
        #expect(got.matrix == (kCMFormatDescriptionYCbCrMatrix_ITU_R_709_2 as String))
        let index = try #require(got.numbers.firstIndex(of: 10))
        let frame = got.frames[index]
        #expect(frame.count == png.bytes.count)
        let worst = zip(frame, png.bytes).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(worst <= 2, "動画と PNG の差の最大 \(worst) 階調")
    }

    // MARK: - 決定論

    /// 同じ機械・同じ入力なら、動画もファイルのバイトまで一致する (`MovieFile` の説明、
    /// ADR-0025 決定 3)。PNG も同じ。
    ///
    /// **2 本の間を 1 秒以上あける。** 容れ物の作成時刻 (秒) が違う秒に落ちるようにして、
    /// 刻印のずれを毎回起きる形にするためである (同じ秒に収まると、たまたま一致する)。
    /// 刻印を除いたバイト (絵と時刻の表) の一致は、別に厳しく押さえる。
    @Test("同じ入力から 2 回書き出した .mov と PNG は、バイトまで一致する", .enabled(if: proResAvailable))
    func byteDeterminism() async throws {
        var movies: [String] = []
        var stills: [String] = []
        var unstamped: [Data] = []
        for trial in 0..<2 {
            let dir = try scratch("twice-\(trial)")
            let movie = dir.appendingPathComponent("twice.mov")
            let still = dir.appendingPathComponent("twice.png")
            try produce(
                Ticker { s in
                    if s.frameCount == 2 { s.beginRecord(movie.path) }
                    if s.frameCount == 8 { s.save(still.path) }
                    if s.frameCount == 20 { s.endRecord() }
                }, frames: 21)
            movies.append(try digest(movie))
            stills.append(try digest(still))
            unstamped.append(try Data(contentsOf: movie).withoutContainerTimes())
            if trial == 0 { try await Task.sleep(for: .milliseconds(1100)) }
        }
        #expect(stills[0] == stills[1], "PNG のバイトが違う")
        #expect(unstamped[0] == unstamped[1], "容れ物の時刻の刻印を除いても .mov のバイトが違う")
        withKnownIssue("mokume#1628: 秒の境目をまたぐと、容れ物の作成・更新時刻だけが違う") {
            #expect(movies[0] == movies[1], ".mov のバイトが違う")
        }
    }
}
