// repro: mokume#1593
//
// 別々のパスに置いた OBJ (格子 1 枚・3721 頂点 / 7200 三角形) を、毎フレーム 1 つずつ `loadModel` で
// 読んで置く (動きを書き出した連番の形)。読んだモデルが控えに残り、プロセスの footprint が 1 枚ごとに
// 約 1 MB 増え続ける。同じ 1 つを読み続ける参照 (控えに当たる) は、この増え方をしない。
//
// 列は 160 個・約 160 MB にしてある。控えに 64 MiB の予算が入れば、予算を越えた後は増えなくなる。
// 増え方は、同じ枚数を回した参照と **1 枚ごとの増分の中央値** (KB) で比べる。malloc が空きを一度に
// まとめて返す段差 (数十 MB) に引きずられないためである。main actor は譲らないので、どちらの経路にも
// mokume#1594 の増え方 (1 枚あたり約 1.5 KB) が同じだけ乗る。
// OBJ は一時ディレクトリに書き、終わったら消す。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。

import Foundation
import mokume

enum ModelSequenceRepro {
    static let length = 160

    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("mokume-repro-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let grid = obj(grid: 60)
        let paths = try (0..<length).map { index in
            let url = directory.appendingPathComponent(String(format: "wave-%03d.obj", index))
            try grid.write(to: url, atomically: true, encoding: .utf8)
            return url.path
        }
        let same = try step(Scene(paths: [paths[0]]))
        let sequence = try step(Scene(paths: paths))
        guard sequence > same + 32 else { return nil }
        return String(
            format: "連番を 1 つずつ読むと 1 枚ごとに %.0f KB 増える (同じ 1 つを読み続ける参照は %.0f KB・1 枚ごとの増分の中央値・%d 枚)",
            sequence, same, length)
    }

    /// 格子 1 枚の OBJ。頂点は (grid + 1)² = 3721、三角形は 2 × grid² = 7200。
    static func obj(grid n: Int) -> String {
        var lines: [String] = []
        for i in 0...n {
            for j in 0...n { lines.append("v \(Float(i) / Float(n) - 0.5) \(Float(j) / Float(n) - 0.5) 0") }
        }
        for i in 0..<n {
            for j in 0..<n {
                let a = i * (n + 1) + j + 1
                lines.append("f \(a) \(a + 1) \(a + n + 2)")
                lines.append("f \(a) \(a + n + 2) \(a + n + 1)")
            }
        }
        return lines.joined(separator: "\n")
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")
        let paths: [String]
        init(paths: [String]) { self.paths = paths }
        convenience init() { self.init(paths: []) }

        func draw() {
            background(12)
            guard let wave = try? loadModel(paths[(frameCount - 1) % paths.count]) else { return }
            lights()
            noStroke()
            translate(100, 100)
            rotateX(1)
            model(wave)
        }
    }

    /// 列を 1 巡回し、暖機 10 枚の後の 1 枚ごとの footprint の増分の中央値 (KB)。
    static func step(_ sketch: any Sketch, warmup: Int = 10) throws -> Double {
        let runtime = try SketchRuntime(sketch: sketch, gpu: RenderDevice())
        defer { runtime.closePlugins() }
        var footprints: [Double] = []
        for _ in 1...length {
            try autoreleasepool { try runtime.advance() }
            malloc_zone_pressure_relief(nil, 0)
            footprints.append(footprint())
        }
        let measured = footprints.dropFirst(warmup - 1)
        let steps = zip(measured.dropFirst(), measured).map { $0 - $1 }.sorted()
        return steps[steps.count / 2] / 1024
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
