// repro: mokume#1592
//
// 描き場所 (`createGraphics`) に `beginDraw()` / `endDraw()` を付けずに、毎フレーム円を 1000 個置く。
// 何も描かれないのに、置いた図形が捨てられずに溜まり、プロセスの footprint が 1 枚ごとに増え続ける。
// `beginDraw()` … `endDraw()` で挟む参照は、この増え方をしない。
//
// 増え方は、同じ枚数を回した参照と 1 枚あたりの増分 (KB) で比べる。footprint はプロセス全体の値
// なので、2 つの経路は順に回す。main actor は譲らないので、どちらの経路にも mokume#1594 の増え方
// (1 枚あたり約 1.5 KB) が同じだけ乗る。比べるのはその差である。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum OffFrameGraphicsRepro {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let framed = try growth(Scene(framed: true))
        let unframed = try growth(Scene(framed: false))
        // 参照は mokume#1594 の約 1.5 KB/枚だけ増えるが、main actor を譲らないので、malloc の領域が
        // 1 度伸びる段を踏んで 25 KB/枚ほどに見える回がある。疑いの側は 100 KB/枚を越える
        guard unframed > framed + 64 else { return nil }
        return String(
            format: "beginDraw() なしは %.1f KB/枚ずつ増える (beginDraw() … endDraw() で挟む参照は %.1f KB/枚・暖機 30 枚の後の 270 枚)",
            unframed, framed)
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")
        let framed: Bool
        var layer: Canvas!
        init(framed: Bool) { self.framed = framed }
        convenience init() { self.init(framed: true) }

        func setup() {
            layer = try! createGraphics(200, 200)
        }

        func draw() {
            background(12)
            if framed { layer.beginDraw() }
            layer.noStroke()
            for i in 0..<1000 {
                layer.circle(Float(i % 200), Float(i / 5), 6)
            }
            if framed { layer.endDraw() }
        }
    }

    /// 300 枚回し、暖機 30 枚の後の 1 枚あたりの footprint の増え方 (KB)。
    ///
    /// 頭の 1/4 と尻の 1/4 の中央値どうしで測る。malloc が空きを一度にまとめて返すと、
    /// 端の 1 点どうしの差ではその 1 回で符号まで変わる。
    static func growth(_ sketch: any Sketch, frames: Int = 300, warmup: Int = 30) throws -> Double {
        let runtime = try SketchRuntime(sketch: sketch, gpu: RenderDevice())
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
