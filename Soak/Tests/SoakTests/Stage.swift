import Foundation
import mokume

@testable import Soak

/// 1 経路を回した記録。**比べるのは暖機の後**で、1 枚目のシェーダの組み立てや、置き場が
/// 最初に伸びる分は数えない。
struct Soaked {
    /// 各フレームを進めた後の footprint (バイト)。
    let footprints: [UInt64]
    /// 回す前と各フレームの後の GPU の確保量 (バイト)。先頭が回す前。
    let gpus: [Int]
    /// 各フレームの `advance()` にかかった秒数。
    let seconds: [Double]
    /// 数えない頭の枚数。
    let warmup: Int
    /// 最後の絵で、明るい画素の数。参照の側が描いていることを押さえるのに使う。
    let lit: Int

    /// 暖機の後、1 枚あたりに増えた footprint (KB)。
    ///
    /// **頭の 1/4 と尻の 1/4 の中央値どうしで測る。** malloc は解放した領域をまとめて
    /// OS へ返すことがあり (連番の OBJ では 38 枚目に 40 MB 落ちた)、端の 1 点どうしの差だと
    /// その 1 回で増え方の符号まで変わる。
    var kilobytesPerFrame: Double {
        let measured = footprints.dropFirst(warmup).map { Double($0) }
        let quarter = max(1, measured.count / 4)
        guard measured.count > quarter else { return 0 }
        func median(_ values: ArraySlice<Double>) -> Double { values.sorted()[values.count / 2] }
        let rise = median(measured.suffix(quarter)) - median(measured.prefix(quarter))
        return rise / 1024 / Double(measured.count - quarter)
    }

    /// 暖機の後の、1 枚ごとの増分の中央値 (KB)。
    ///
    /// **毎フレーム同じだけ積む疑い**に使う。1 度きりの大きな段差 (連番の OBJ では、
    /// `malloc_zone_pressure_relief` を挟んでも 35 枚目前後で 40 MB 返る) に引きずられない。
    /// 増分が数フレームに 1 ページ (16 KB) しか出ない小さな増え方では 0 になるので、
    /// そちらは ``kilobytesPerFrame`` で見る。
    var stepKilobytes: Double {
        let measured = footprints.dropFirst(warmup - 1).map { Double($0) }
        let steps = zip(measured.dropFirst(), measured).map { $0 - $1 }.sorted()
        guard !steps.isEmpty else { return 0 }
        return steps[steps.count / 2] / 1024
    }

    /// 回している間に GPU の確保量が回す前からいちばん伸びた幅 (MB)。
    var gpuPeakMegabytes: Double { Double(gpus.max()! - gpus[0]) / 1_048_576 }

    /// 暖機の後の 1 枚の平均 (ms)。
    var milliseconds: Double {
        let measured = seconds.dropFirst(warmup)
        return measured.reduce(0, +) / Double(measured.count) * 1000
    }

    var summary: String {
        String(
            format: "%.2f KB/枚 (1 枚ごとの中央値 %.2f KB)・GPU の山 +%.1f MB・%.2f ms/枚", kilobytesPerFrame,
            stepKilobytes, gpuPeakMegabytes, milliseconds)
    }
}

/// 窓を出さずに `frames` 枚回し、資源の推移を記録する。
///
/// **窓と同じ条件で回す。** 毎フレームを `autoreleasepool` で包み、`Task.yield()` で
/// main actor を譲る。窓では run loop がどちらもしている。譲らないと mokume が GPU の
/// 完了を受けて main actor へ積む後始末 (`releaseFinished`) が走らず、何もしない
/// スケッチでも 1 枚あたり 1.45 KB ずつ増える (それ自体を突くのが `headlessAdvance`)。
///
/// - Parameter yielding: `false` で main actor を譲らずに回す。`headlessAdvance` だけが使う。
@MainActor
func soak(_ sketch: any Sketch, frames: Int, warmup: Int, yielding: Bool = true) async throws -> Soaked {
    let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
    defer { runtime.closePlugins() }
    var footprints: [UInt64] = []
    var gpus = [Meter.gpu()]
    var seconds: [Double] = []
    for _ in 1...frames {
        let started = Date()
        try autoreleasepool { try runtime.advance() }
        seconds.append(Date().timeIntervalSince(started))
        if yielding { await Task.yield() }
        // 解放済みの領域を OS へ返させてから読む。返す時期を malloc に任せると、
        // 溜まった空きが一度にまとめて返って段差になる (下の `kilobytesPerFrame`)
        malloc_zone_pressure_relief(nil, 0)
        footprints.append(Meter.footprint())
        gpus.append(Meter.gpu())
    }
    let picture = try runtime.target.readPixels()
    var lit = 0
    for y in 0..<picture.height {
        for x in 0..<picture.width where max(picture[x, y].red, picture[x, y].green, picture[x, y].blue) > 0.2 {
            lit += 1
        }
    }
    return Soaked(footprints: footprints, gpus: gpus, seconds: seconds, warmup: warmup, lit: lit)
}

/// 候補 1 件の 1 経路を回す。
@MainActor
func soak(_ key: LoadKey, _ route: Route, frames: Int, warmup: Int) async throws -> Soaked {
    try await soak(Loads.named(key).make(route), frames: frames, warmup: warmup)
}

/// 落ちる候補を 2 枚だけ回す。**exit test の中 (子プロセス) で呼ぶ。**
///
/// 落ちなければ普通に戻り、子プロセスは成功で終わる。
@MainActor
func survive(_ key: CrashKey, extreme: Bool) async {
    guard let runtime = try? SketchRuntime(sketch: Crash(key, extreme: extreme), gpu: gpu) else { return }
    for _ in 1...2 {
        try? runtime.advance()
        await Task.yield()
    }
    runtime.closePlugins()
}

/// 目盛りと同じ装置で組む (`Meter`)。GPU の確保量はこの装置から読む。
@MainActor let gpu = try! Meter.renderDevice()
