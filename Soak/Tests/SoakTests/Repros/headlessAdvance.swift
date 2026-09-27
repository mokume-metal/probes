// repro: mokume#1594
//
// 何もしないに近いスケッチ (背景と四角 1 つ) を、main actor を譲らない `SketchRuntime.advance()` の
// ループで 4000 枚回す。プロセスの footprint が、フレームに比例して増え続ける。
//
// **比べる参照を置かず、増え方の絶対量で見る。** 譲る側 (`await Task.yield()`) は、同期の
// `reproduce()` には書けない。main の run loop を回して代わりにする手は、トップレベルのコード
// では効くが、swift-testing の中では main actor に積まれたものを走らせない。譲れば増えないことは、
// probes の Soak の検査 `headlessAdvance` が毎フレーム `await Task.yield()` を挟んで押さえている
// (0.03 KB/枚)。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum HeadlessAdvanceRepro {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let growth = try growth()
        // 増えなければ 0.03 KB/枚ほど。1 枚あたり 0.5 KB は、4000 枚で 2 MB にあたる
        guard growth > 0.5 else { return nil }
        return String(format: "main actor を譲らずに回すと %.2f KB/枚ずつ増える (暖機 1000 枚の後の 3000 枚)", growth)
    }

    final class Idle: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")

        func draw() {
            background(12)
            rect(20, 20, 40, 40)
        }
    }

    /// main actor を譲らずに 4000 枚回し、暖機 1000 枚の後の 1 枚あたりの footprint の増え方 (KB)。
    ///
    /// 頭の 1/4 と尻の 1/4 の中央値どうしで測る。malloc が空きを一度にまとめて返すと、
    /// 端の 1 点どうしの差ではその 1 回で符号まで変わる。
    static func growth(frames: Int = 4000, warmup: Int = 1000) throws -> Double {
        let runtime = try SketchRuntime(sketch: Idle(), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        var footprints: [Double] = []
        for _ in 1...frames {
            try autoreleasepool { try runtime.advance() }
            malloc_zone_pressure_relief(nil, 0)
            footprints.append(footprint())
        }
        let measured = Array(footprints.dropFirst(warmup))
        let quarter = measured.count / 4
        func median(_ values: ArraySlice<Double>) -> Double { values.sorted()[values.count / 2] }
        let rise = median(measured.suffix(quarter)) - median(measured.prefix(quarter))
        return rise / 1024 / Double(measured.count - quarter)
    }

    /// プロセスの `phys_footprint` (バイト)。活動モニタの「メモリ」と同じ値。
    static func footprint() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.phys_footprint) : 0
    }
}
