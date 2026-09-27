import Foundation
import Metal
import mokume

/// 列 1 本を回した判定。
///
/// 落ちる (signal) と止まる (時間切れ) は、このプロセスの中では測れない。ドライバ
/// (`scripts/tumble.py`) が子プロセスの終わり方で見る。
nonisolated struct Outcome: Codable, Sendable {
    var seed: UInt64
    /// 列の口の数。
    var ops: Int
    /// 破れの種類。空なら何も破れていない。
    ///
    /// - `threw`: `advance()` が投げた (描く口は投げない約束。mokume ADR-0020 決定 5)
    /// - `nondeterministic`: 同じ列を 2 回回して、どこかのフレームの画素がバイトで違う
    ///   (mokume ADR-0001 原則 2)
    /// - `sentinel`: 番兵のフレームが、列を回さなかった番兵と違う (戻らない劣化)
    /// - `nonfinite`: 画素に数でない値か無限がある (絵へ NaN を通さない)
    var breaks: [String]
    /// 投げたときの説明。
    var threw: String?
    /// 番兵で違った画素の数と、成分の差のいちばん大きいもの。
    var sentinelPixels: Int
    var sentinelGap: Double
    /// 数でない成分を持つ画素の数 (全フレームの和)。
    var nonfinitePixels: Int
    /// 2 回の実行で食い違った最初のフレーム (1 始まり)。
    var divergedAt: Int?
    /// 1 回目の各フレームの指紋。
    var hashes: [String]
}

/// 列を回して、判定を下す。
@MainActor
enum Examine {
    static let gpu = try! RenderDevice(device: meter)

    /// 成分の差がこれを越える画素を、違うと数える (表示の 1 段 = 1/255 より小さい)。
    static let tolerance: Float = 0.004

    /// 列を回さなかった番兵。**プロセスで最初に 1 度だけ描く** — 他の列を回した後で描くと、
    /// ランタイムをまたいで残る汚れが参照にも入る。
    static let reference: PixelBuffer = {
        let run = try! play(.empty, shots: nil, name: "reference")
        return run.pictures.last!
    }()

    struct Run {
        var pictures: [PixelBuffer] = []
        var threw: String?
    }

    /// 列を新しい `SketchRuntime` で回し、各フレームの絵を読む。
    ///
    /// **窓と同じく、フレームの間に main の run loop を 1 度回す。** mokume は GPU の完了を
    /// 受けた後始末を main actor の Task に積むので、回さないと溜まる (mokume#1594)。
    static func play(_ program: Program, shots: URL?, name: String) throws -> Run {
        let sketch = Played(program)
        let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
        defer { runtime.closePlugins() }
        var run = Run()
        for frame in 1...(program.frames.count + 1) {
            do {
                try autoreleasepool { try runtime.advance() }
            } catch {
                run.threw = "\(frame) 枚目: \(error)"
                break
            }
            _ = RunLoop.main.run(mode: .default, before: .now)
            run.pictures.append(try runtime.target.readPixels())
            if let shots {
                try runtime.target.writePNG(to: shots.appendingPathComponent("\(name)-\(frame).png"))
            }
        }
        if let failure = sketch.setupFailure { run.threw = "setup: \(failure)" }
        return run
    }

    /// 列を 2 回回し、番兵と比べる。
    ///
    /// - Parameter shots: 渡すと、1 回目の各フレームを `suspect-<n>.png`、参照の番兵を
    ///   `reference-<n>.png` (n は番兵のフレーム番号) として書き出す (scripts/shots.py が組む)。
    static func examine(_ program: Program, shots: URL? = nil, key: String = "tumble") throws -> Outcome {
        _ = reference
        let first = try play(program, shots: shots, name: "\(key)-suspect")
        let second = try play(program, shots: nil, name: "")
        var outcome = Outcome(
            seed: program.seed, ops: program.count, breaks: [], threw: first.threw ?? second.threw,
            sentinelPixels: 0, sentinelGap: 0, nonfinitePixels: 0, divergedAt: nil,
            hashes: first.pictures.map(hash))
        if outcome.threw != nil { outcome.breaks.append("threw") }

        let secondHashes = second.pictures.map(hash)
        if let index = zip(outcome.hashes, secondHashes).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset
            ?? (outcome.hashes.count != secondHashes.count ? min(outcome.hashes.count, secondHashes.count) : nil)
        {
            outcome.divergedAt = index + 1
            outcome.breaks.append("nondeterministic")
        }

        outcome.nonfinitePixels = first.pictures.reduce(0) { $0 + nonfinite($1) }
        if outcome.nonfinitePixels > 0 { outcome.breaks.append("nonfinite") }

        if first.threw == nil, let last = first.pictures.last, first.pictures.count == program.frames.count + 1 {
            let (pixels, gap) = compare(last, reference)
            outcome.sentinelPixels = pixels
            outcome.sentinelGap = Double(gap)
            if pixels > 0 { outcome.breaks.append("sentinel") }
            if let shots {
                // 参照を、疑う側の番兵と同じフレーム番号で書く (shots.py が対にする)
                try writeReference(to: shots.appendingPathComponent("\(key)-reference-\(program.frames.count + 1).png"))
            }
        }
        return outcome
    }

    static func writeReference(to url: URL) throws {
        let sketch = Played(.empty)
        let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
        defer { runtime.closePlugins() }
        try runtime.advance()
        try runtime.target.writePNG(to: url)
    }

    /// 画素の成分のビット列から取る指紋 (FNV-1a 64)。
    static func hash(_ picture: PixelBuffer) -> String {
        var value: UInt64 = 0xcbf2_9ce4_8422_2325
        for component in picture.components {
            let bits = component.bitPattern
            value = (value ^ UInt64(bits & 0xff)) &* 0x0000_0100_0000_01B3
            value = (value ^ UInt64(bits >> 8)) &* 0x0000_0100_0000_01B3
        }
        return String(value, radix: 16)
    }

    /// 数でない成分を持つ画素の数。
    static func nonfinite(_ picture: PixelBuffer) -> Int {
        var count = 0
        let c = picture.components
        var i = 0
        while i < c.count {
            if !c[i].isFinite || !c[i + 1].isFinite || !c[i + 2].isFinite || !c[i + 3].isFinite { count += 1 }
            i += 4
        }
        return count
    }

    /// 違う画素の数と、成分の差のいちばん大きいもの。数でない成分は違うと数える。
    static func compare(_ a: PixelBuffer, _ b: PixelBuffer) -> (Int, Float) {
        guard a.width == b.width, a.height == b.height else { return (a.width * a.height, .infinity) }
        var count = 0
        var widest: Float = 0
        let (p, q) = (a.components, b.components)
        var i = 0
        while i < p.count {
            var gap: Float = 0
            for k in 0..<4 {
                let d = abs(Float(p[i + k]) - Float(q[i + k]))
                gap = d.isNaN ? .infinity : max(gap, d)
            }
            if gap > tolerance { count += 1 }
            widest = max(widest, gap)
            i += 4
        }
        return (count, widest)
    }
}

// MARK: - 漏れ

/// 列を繰り返し回したときの資源の増え方。
nonisolated struct Soaked: Codable, Sendable {
    var seed: UInt64
    /// 暖機の後、1 枚あたりに増えた footprint (KB)。参照 (番兵だけを繰り返す) の増え方を引いた値。
    var kilobytesPerFrame: Double
    /// 回している間に GPU の確保量が回す前からいちばん伸びた幅 (MB)。
    var gpuPeakMegabytes: Double
    /// 最後の 1/4 で GPU の確保量が暖機の直後より伸びた幅 (MB)。増え続けていれば正。
    var gpuRiseMegabytes: Double
    var breaks: [String]
}

extension Examine {
    /// 漏れとみなす増え方。Soak の検査の閾値と揃える (1 枚 2 KB・GPU 8 MB)。
    static let leakKilobytes = 2.0
    static let leakGPUMegabytes = 8.0

    /// 目盛りを読む装置。GPU の確保量はこの装置から読むので、`gpu` と同じもの。
    static let meter: any MTLDevice = MTLCreateSystemDefaultDevice()!

    /// 参照の増え方 (番兵だけを繰り返す)。プロセスで最初に 1 度だけ測る。
    static let soakReference: Double = {
        (try? measure(.empty, frames: 240, warmup: 60).kilobytes) ?? 0
    }()

    /// 列のフレームを `frames` 枚繰り返し、footprint と GPU の確保量の増え方を測る。
    ///
    /// **窓と同じ条件で回す** — 毎フレームを `autoreleasepool` で包み、main の run loop を 1 度回す。
    /// 増え方は、暖機の後の頭の 1/4 と尻の 1/4 の中央値どうしで測る (Soak の `kilobytesPerFrame`)。
    static func soak(_ program: Program, frames: Int = 240, warmup: Int = 60) throws -> Soaked {
        _ = soakReference
        let measured = try measure(program, frames: frames, warmup: warmup)
        var soaked = Soaked(
            seed: program.seed, kilobytesPerFrame: measured.kilobytes - soakReference,
            gpuPeakMegabytes: measured.gpuPeak, gpuRiseMegabytes: measured.gpuRise, breaks: [])
        if soaked.kilobytesPerFrame > leakKilobytes { soaked.breaks.append("leak") }
        if soaked.gpuRiseMegabytes > leakGPUMegabytes { soaked.breaks.append("gpuLeak") }
        return soaked
    }

    static func measure(_ program: Program, frames: Int, warmup: Int) throws -> (kilobytes: Double, gpuPeak: Double, gpuRise: Double) {
        let runtime = try SketchRuntime(sketch: Played(program, loops: true), gpu: gpu)
        defer { runtime.closePlugins() }
        var footprints: [Double] = []
        var gpus: [Double] = [Double(meter.currentAllocatedSize)]
        for _ in 1...frames {
            try? autoreleasepool { try runtime.advance() }
            _ = RunLoop.main.run(mode: .default, before: .now)
            malloc_zone_pressure_relief(nil, 0)
            footprints.append(Double(footprint()))
            gpus.append(Double(meter.currentAllocatedSize))
        }
        let settled = Array(footprints.dropFirst(warmup))
        let quarter = max(1, settled.count / 4)
        func median(_ values: ArraySlice<Double>) -> Double { values.sorted()[values.count / 2] }
        let rise = median(settled.suffix(quarter)) - median(settled.prefix(quarter))
        let kilobytes = rise / 1024 / Double(settled.count - quarter)
        let gpuSettled = Array(gpus.dropFirst(warmup + 1))
        let gpuRise = (median(gpuSettled.suffix(quarter)) - median(gpuSettled.prefix(quarter))) / 1_048_576
        return (kilobytes, (gpus.max()! - gpus[0]) / 1_048_576, gpuRise)
    }

    /// プロセスの `phys_footprint` (バイト)。Soak の `Meter.footprint` と同じ。
    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
