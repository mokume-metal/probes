import Foundation
import Testing
import mokume

@testable import Soak

/// 候補ごとの検査。**期待値は「正しい振る舞い」のほうに置く。**
///
/// **1 本ずつ順に回す** (`.serialized`)。footprint も GPU の確保量もプロセス全体の値で、
/// 時間も CPU を取り合うと伸びるので、並べて回すと隣の検査が疑いに混ざる。
///
/// 各検査は、疑いを確かめる前に**参照の側が動いていること**を押さえる (描いている・
/// 増えていない・時間が仕事に見合う)。参照まで増えていたら、比べても何も言えないため。
@MainActor
@Suite(.serialized) struct SoakTests {
    /// 「増えていない」とみなす 1 枚あたりの増え方 (KB)。
    ///
    /// 参照の側はほぼ 0 KB/枚だが、malloc の領域が 1 度だけ 2 MB 伸びる段を踏むことがあり、
    /// 300 枚で割ると最大 10 KB/枚に見える。疑いの側はどれも 100 KB/枚を越えて増えるので、
    /// 32 KB/枚は両方から十分に離れている。
    static let flat = 32.0

    // MARK: - メモリ

    /// 2 経路を回し、参照が描いて増えていないことを押さえてから、疑いの増え方を返す。
    func memory(_ key: LoadKey, frames: Int, warmup: Int) async throws -> (suspect: Soaked, reference: Soaked) {
        let b = try await soak(key, .reference, frames: frames, warmup: warmup)
        let a = try await soak(key, .suspect, frames: frames, warmup: warmup)
        #expect(b.lit > 100, "参照が描いていない: 明るい画素 \(b.lit)")
        #expect(b.kilobytesPerFrame < Self.flat, "参照が増えている: \(b.summary)")
        return (a, b)
    }

    @Test("閉じ忘れた beginShape が、フレームをまたいで頂点を積み続けない")
    func unclosedShape() async throws {
        let (a, b) = try await memory(.unclosedShape, frames: 300, warmup: 30)
        withKnownIssue("mokume#1591: 開いた形の印がフレームの境目で下りず、vertex() が点を積み続ける") {
            #expect(a.kilobytesPerFrame < b.kilobytesPerFrame + Self.flat, "閉じない \(a.summary)、閉じる \(b.summary)")
        }
    }

    @Test("beginDraw の外で描き場所へ置いた図形が、溜まり続けない")
    func offFrameGraphics() async throws {
        let (a, b) = try await memory(.offFrameGraphics, frames: 300, warmup: 30)
        withKnownIssue("mokume#1592: 図形の口がフレームの外を見ずに溜め場へ積み、捨てる契機が来ない") {
            #expect(a.kilobytesPerFrame < b.kilobytesPerFrame + Self.flat, "挟まない \(a.summary)、挟む \(b.summary)")
        }
    }

    @Test("sin で脈打つ textSize でも、書体の控えが増え続けない")
    func pulsingText() async throws {
        let (a, b) = try await memory(.pulsingText, frames: 600, warmup: 60)
        withKnownIssue("mokume#1431: 書体の控えが大きさごとに増え続け、減らす経路も上限も無い") {
            #expect(a.kilobytesPerFrame < b.kilobytesPerFrame + Self.flat, "textSize で脈打つ \(a.summary)、scale で脈打つ \(b.summary)")
        }
    }

    @Test("main actor を譲らずに advance() を回しても、後始末が溜まらない")
    func headlessAdvance() async throws {
        // 1.45 KB/枚の差を見るので、枚数を多く取って閾値を詰める
        let b = try await soak(Idle(), frames: 4000, warmup: 1000, yielding: true)
        let a = try await soak(Idle(), frames: 4000, warmup: 1000, yielding: false)
        #expect(b.kilobytesPerFrame < 0.3, "譲る回し方が増えている: \(b.summary)")
        withKnownIssue("mokume#1594: GPU の完了の後始末を main actor の Task に積むので、譲らないと走らない") {
            #expect(a.kilobytesPerFrame < b.kilobytesPerFrame + 0.5, "譲らない \(a.summary)、譲る \(b.summary)")
        }
    }

    // MARK: - 時間

    /// 仕事の量を倍にしたときの時間の比。線形なら 2、二乗なら 4 に近づく。
    ///
    /// **比で見るので機械に依らない。** 固定の費用があると 2 より小さく出る。
    static let linear = 2.6

    @Test("多角形の塗りの時間が、頂点数に見合う")
    func polygonFill() async throws {
        func ms(_ route: Route, _ vertices: Int) async throws -> Double {
            try await soak(PolygonFill(route: route, vertices: vertices), frames: 8, warmup: 3).milliseconds
        }
        let reference = (try await ms(.reference, 1000), try await ms(.reference, 2000))
        let suspect = (try await ms(.suspect, 1000), try await ms(.suspect, 2000))
        #expect(reference.1 / reference.0 < Self.linear, "扇: 1000 頂点 \(reference.0) ms、2000 頂点 \(reference.1) ms")
        // **倍の比ではなく、同じ機械の扇との比で見る。** mokume#1595 が採った直し方 (earcut 系)
        // でも debug の倍の比は 3.0 までしか下がらない (試作)。扇との比は、いま 2000 頂点で約 41 倍、
        // 直った後の試作で約 5 倍なので、10 倍で分かれる
        withKnownIssue("mokume#1595: 耳を探すたびに頭から走査し、耳の判定で全頂点を見る (頂点数の二乗)") {
            #expect(
                suspect.1 < reference.1 * 10,
                "多角形: 1000 頂点 \(suspect.0) ms、2000 頂点 \(suspect.1) ms (扇は \(reference.0)・\(reference.1) ms)")
        }
    }

    @Test("立体の既定の線が、立体を置く費用に見合う")
    func solidStroke() async throws {
        let b = try await soak(SolidStroke(route: .reference, count: 100), frames: 8, warmup: 3)
        let a = try await soak(SolidStroke(route: .suspect, count: 100), frames: 8, warmup: 3)
        let half = try await soak(SolidStroke(route: .suspect, count: 50), frames: 8, warmup: 3)
        #expect(b.lit > 1000, "参照が描いていない: 明るい画素 \(b.lit)")
        // 線の費用は立体の数に比例する (倍にして 2 倍前後)。ここまでは約束どおり
        #expect(a.milliseconds / half.milliseconds < Self.linear, "50 個 \(half.summary)、100 個 \(a.summary)")
        // mokume#1596 は視点を 1 度だけ読む手前の直しで閉じ、この期待 (線なしの 10 倍 + 16 ms・
        // GPU の山 32 MB 未満) は #1604 (Design) へ移った。手前の直しでは線なしの 25 倍が残る
        withKnownIssue("mokume#1604: 稜線の帯と角を、立体ごと・毎フレーム CPU で組み直す (根本は GPU で広げるか)") {
            // 線を付けても、1 フレーム (60 fps の 16 ms) と線なしの 10 倍を足した分に収まる
            #expect(
                a.milliseconds < b.milliseconds * 10 + 16,
                "線あり \(a.summary)、線なし \(b.summary)")
            #expect(a.gpuPeakMegabytes < 32, "線あり \(a.summary)、線なし \(b.summary)")
        }
    }

    // MARK: - 落ちる

    /// 対照が落ちずに通ることを押さえてから、疑いが落ちないかを見る。
    ///
    /// exit test の中身は子プロセスで走り、外の値を掴めない。候補は字面で渡す。

    @Test("巨大な textSize で字を描いても、落ちない")
    func hugeTextSize() async {
        await #expect(processExitsWith: .success) { await survive(.hugeTextSize, extreme: false) }
        await withKnownIssue("mokume#1587: 字形の外接矩形を Int へ直すところで、大きさの上限を見ていない") {
            await #expect(processExitsWith: .success) { await survive(.hugeTextSize, extreme: true) }
        }
    }

    @Test("数でない座標・巨大な textSize で textOutline を取っても、落ちない")
    func textOutline() async {
        await #expect(processExitsWith: .success) { await survive(.textOutlineNaN, extreme: false) }
        await #expect(processExitsWith: .success) { await survive(.textOutlineHuge, extreme: false) }
        await withKnownIssue("mokume#1587: 曲線を割る数を Int((rough / 2).rounded(.up)) で作り、rough が NaN / inf になる") {
            await #expect(processExitsWith: .success) { await survive(.textOutlineNaN, extreme: true) }
            await #expect(processExitsWith: .success) { await survive(.textOutlineHuge, extreme: true) }
        }
    }

    @Test("createShape の中で background() / get() を呼んでも、落ちない")
    func createShapeDiscard() async {
        await #expect(processExitsWith: .success) { await survive(.createShapeBackground, extreme: false) }
        await #expect(processExitsWith: .success) { await survive(.createShapeGet, extreme: false) }
        await withKnownIssue("mokume#1588: 溜め場を空にした後で、入口で覚えた開始位置から切り出す") {
            await #expect(processExitsWith: .success) { await survive(.createShapeBackground, extreme: true) }
            await #expect(processExitsWith: .success) { await survive(.createShapeGet, extreme: true) }
        }
    }

    @Test("makeNumbers(count:) に巨大な数を渡すと、落ちずに投げる")
    func makeNumbersHuge() async {
        await #expect(processExitsWith: .success) { await survive(.makeNumbersHuge, extreme: false) }
        await withKnownIssue("mokume#1589: 上限を検める前のバイト数の掛け算があふれる") {
            await #expect(processExitsWith: .success) { await survive(.makeNumbersHuge, extreme: true) }
        }
    }

    @Test("画面へ出す絵を範囲の外で読んでも、落ちない")
    func displayImageOutside() async {
        await #expect(processExitsWith: .success) { await survive(.displayImageOutside, extreme: false) }
        await withKnownIssue("mokume#1590: DisplayImage の添字が precondition で止まる (PixelBuffer は #1436 で透明を返す)") {
            await #expect(processExitsWith: .success) { await survive(.displayImageOutside, extreme: true) }
        }
    }

    // MARK: - 最後に回す

    /// **いちばん重いメモリの検査なので、最後に回す。** 列を読み切ると 160 MB ほど確保して
    /// 手放す。この検査の直後に回した `pulsingText` が 1 度だけ既知の問題を記録しなかった
    /// (2026-09-25・4 回に 1 回。原因は確かめていない)。小さな増え方を見る検査
    /// (`pulsingText`・`headlessAdvance`) に後始末が混ざる疑いがあるので、後ろに何も置かない。
    /// `.serialized` は宣言順に回す。
    @Test("連番の OBJ を読み進めても、読んだモデルが控えに溜まり続けない")
    func modelSequence() async throws {
        // 毎フレーム 1 モデルずつ積むので、1 枚ごとの増分で見る (`stepKilobytes`)
        let (a, b) = try await memory(.modelSequence, frames: ModelSequence.length, warmup: 10)
        withKnownIssue("mokume#1593: loadModel の控えに上限も追い出しも無い") {
            #expect(a.stepKilobytes < b.stepKilobytes + Self.flat, "連番 \(a.summary)、同じ 1 枚 \(b.summary)")
        }
    }
}
