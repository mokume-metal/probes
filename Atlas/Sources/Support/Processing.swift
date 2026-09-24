import Foundation
import mokume

// Processing にあって mokume の面に無い語彙のうち、**面の外に書けば済むもの**。
// 台帳 (`ledger/vocabulary.jsonl`) が `write` と判定しているものがここに来る。
//
// **1 箇所にまとめたのは、数えるため。** 例ごとに書き下すと、同じ 1 行が 156 回
// 書かれるだけで「何本の例がこれを要求したか」が消える。ここに集めておけば、
// **この 1 ファイルの長さがそのまま「Processing の例を書くのに mokume の外へ
// どれだけ書き足す必要があるか」の答え**になる。
//
// **面に足りないものを面へ足しているわけではない。** ここにあるのは書く側で書ける
// ものだけで、書けないもの (`noLoop` / `colorMode` の目盛りの張り替え) は入れない。
// それらは移植の中に「書けない」と書いて止まった形で残す。
//
// **`v0.6.0` で 12 個が面へ移った** — `gray` / `rgb` / `hex` / `hsb` (色を数値で作る口と
// HSB) ・`map` / `radians` / `degrees` (数) ・`red` / `green` / `blue` / `brightness`
// (成分の読み出し)。177 行あったこのファイルは 88 行になった。
// 何が動いたかは README の「面の外に書き足したもの」にある。

// MARK: - 色

/// 原典の `lerpColor(a, b, t)`。**混ぜる空間が違う** — mokume は線形の空間で持つので、
/// 原典 (表示値のまま混ぜる) とは中間の色が変わる。
public func lerpColor(_ from: LinearRGBA, _ to: LinearRGBA, _ amount: Float) -> LinearRGBA {
    LinearRGBA(
        straightRed: from.red + (to.red - from.red) * amount,
        green: from.green + (to.green - from.green) * amount,
        blue: from.blue + (to.blue - from.blue) * amount,
        alpha: from.alpha + (to.alpha - from.alpha) * amount)
}

// MARK: - 数

// `map` / `radians` / `degrees` は `v0.6.0` で面に入った ([mokume#883](https://github.com/mokume-metal/mokume/issues/883))。
// 綴りも引数の形も原典と同じなので、呼ぶ側は 1 文字も変わっていない。

/// 原典の `constrain(value, low, high)`。**9 本の例が要求する。**
public func constrain(_ value: Float, _ low: Float, _ high: Float) -> Float { min(max(value, low), high) }

/// 原典の `dist(x1, y1, x2, y2)`。**10 本の例が要求する。**
public func dist(_ x1: Float, _ y1: Float, _ x2: Float, _ y2: Float) -> Float {
    ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)).squareRoot()
}

/// 原典の `dist(x1, y1, z1, x2, y2, z2)` — 立体の側。
public func dist(_ x1: Float, _ y1: Float, _ z1: Float, _ x2: Float, _ y2: Float, _ z2: Float) -> Float {
    ((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1) + (z2 - z1) * (z2 - z1)).squareRoot()
}

/// 原典の `mag(x, y)` — 原点からの長さ。**7 本の例が要求する。**
public func mag(_ x: Float, _ y: Float) -> Float { (x * x + y * y).squareRoot() }

/// 原典の `lerp(start, stop, amount)`。
public func lerp(_ start: Float, _ stop: Float, _ amount: Float) -> Float { start + (stop - start) * amount }

/// 原典の `norm(value, start, stop)` — `map` の 0〜1 版。
public func norm(_ value: Float, _ start: Float, _ stop: Float) -> Float { (value - start) / (stop - start) }

/// 原典の `sq(n)`。
public func sq(_ value: Float) -> Float { value * value }

// MARK: - 時計

// **mokume に壁時計が無い。** あるのは起動からの秒 (`time`) と `frameCount` と
// `deltaTime` だけで、`millis` / `second` / `hour` は台帳でも `none` に落ちている。
// ただし壁時計そのものは Foundation が持っているので、面の外でなら書ける — 面に
// 無いのは「読む口」であって、値そのものが取れないわけではない。

/// 原典の `second()`。
public func second() -> Float { Float(Calendar.current.component(.second, from: Date())) }

/// 原典の `minute()`。
public func minute() -> Float { Float(Calendar.current.component(.minute, from: Date())) }

/// 原典の `hour()`。
public func hour() -> Float { Float(Calendar.current.component(.hour, from: Date())) }

/// 原典の `millis()` — 走り出してからのミリ秒。**mokume の `time` (秒) と同じものだが、
/// あちらは `Sketch` の上にあるので、面の外からは読めない。** ここでは起動時刻からの
/// 経過で組む。
private let started = Date()
public func millis() -> Float { Float(Date().timeIntervalSince(started) * 1000) }

// MARK: - 資材

/// この作品の根。**`#filePath` から遡って `ledger/` を持つディレクトリを探す。**
///
/// 目印に `ledger/sources.json` を使うのは、`upstream/` が `scripts/fetch.py` を
/// 走らせるまで存在しないため。台帳は常にある。
///
/// 見つからなければ作業ディレクトリへ落ちる — チェックアウトを移したときに硬く
/// 落ちず、`#filePath` を入れる前と同じ挙動に退化する。
private let root: URL = {
    let marker = "ledger/sources.json"
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while directory.path != "/" {
        if FileManager.default.fileExists(atPath: directory.appendingPathComponent(marker).path) {
            return directory
        }
        directory = directory.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
}()

/// 例が読む資材の道。**絶対パスで返す。**
///
/// **資材はリポジトリに置けない。** 21 本の例が読む絵・書体・立体にはライセンス表記が
/// 無く、works が再配布する理由もない (`scripts/fetch.py` と同じ判断)。SwiftPM の
/// resource として宣言すると `Sources/` の下へコミットすることになるので、束の外 —
/// `scripts/fetch.py` が置いた `upstream/examples/<例>/data/` — を読む。
///
/// **作業ディレクトリからの相対では届かなくなった。** 例 1 本ずつが独立した
/// パッケージになり、`mokume run <その例>` は例のディレクトリを作業ディレクトリに
/// して起動する ([`RunCommand.swift`](https://github.com/mokume-metal/mokume/blob/main/Sources/MokumeCLI/RunCommand.swift) の
/// `currentDirectoryURL`)。上の `root` から組んだ絶対パスなら、どこから起動しても
/// 同じ場所に解決する — mokume も Foundation も絶対パスはそのまま通す
/// (`ImageFile.candidates`)。
public func asset(_ example: String, _ file: String) -> String {
    root.appendingPathComponent("upstream/examples/\(example)/data/\(file)").path
}
