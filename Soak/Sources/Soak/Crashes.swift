import mokume

/// 落ちるかどうかを突く候補の名前。**テストだけ**で使う (窓に並べると窓ごと落ちる)。
///
/// [ADR-0020] 決定 5 は失敗の伝え方を呼ばれ方で決めている: 描く口は投げずに警告して
/// 安全な既定へ倒す、資源の生成は型のついたエラーを投げる、読み取りは決して落ちない。
/// ここに並べるのは、**そのどれにも当たらずプロセスごと止まる**当たりである。
///
/// [ADR-0020]: https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0020-api-naming-and-surface.md
nonisolated enum CrashKey: String, CaseIterable, Sendable {
    /// 有限だが巨大な `textSize` で字を描く (描く口)。
    case hugeTextSize
    /// 数でない座標で `textOutline` を取る (読み取り)。
    case textOutlineNaN
    /// 巨大な `textSize` で `textOutline` を取る (読み取り)。
    case textOutlineHuge
    /// 図形を溜めた後、`createShape` の中で `background()` を呼ぶ (描く口)。
    case createShapeBackground
    /// 図形を溜めた後、`createShape` の中で `get()` を呼ぶ (読み取り)。
    case createShapeGet
    /// `makeNumbers(count:)` に巨大な数を渡す (資源の生成)。
    case makeNumbersHuge
    /// 画面へ出す絵 (`DisplayImage`) を範囲の外で読む (読み取り)。
    case displayImageOutside
}

/// 候補 1 件を 1 フレームで踏むスケッチ。
///
/// **`extreme` を外すと、同じ口を極端でない値で呼ぶ対照になる。** 対照が通ることで、
/// 落ちたのが口のせいで、舞台や書き方のせいではないことを押さえる。
final class Crash: Sketch {
    var settings = Loads.settings
    let key: CrashKey
    let extreme: Bool

    init(_ key: CrashKey, extreme: Bool) {
        self.key = key
        self.extreme = extreme
    }
    convenience init() { self.init(.hugeTextSize, extreme: false) }

    func draw() {
        background(12)
        fill(240)
        switch key {
        case .hugeTextSize:
            textSize(extreme ? 1e20 : 400)
            text("M", 10, 100)
        case .textOutlineNaN:
            _ = textOutline("o", extreme ? Float.nan : 50, 100)
        case .textOutlineHuge:
            textSize(extreme ? 1e21 : 400)
            _ = textOutline("o", 0, 0)
        case .createShapeBackground:
            triangle(10, 10, 60, 10, 10, 60)
            _ = createShape {
                if extreme { background(255) }
                circle(0, 0, 20)
            }
        case .createShapeGet:
            triangle(10, 10, 60, 10, 10, 60)
            _ = createShape {
                if extreme { _ = get(5, 5) }
                circle(0, 0, 20)
            }
        case .makeNumbersHuge:
            // 対照は、上限を越えて投げるはずの大きさ (2^40 個 = 4 TiB)
            _ = try? makeNumbers(count: extreme ? .max : 1 << 40)
        case .displayImageOutside:
            guard let shown = try? canvas.output.encodeForDisplay() else { return }
            _ = shown[extreme ? shown.width : shown.width - 1, 0]
        }
    }
}
