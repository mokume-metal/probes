// repro: mokume#未起票
//
// `mokume render --out x.mp4` が子に渡すのと同じ `MOKUME_RENDER` を立てて `SketchApplication` を走らせ、
// 幅 64・高さ 1 の作品を `.mp4` へ 5 枚書かせる。子は終了コード 0 で終わるのに、書けたファイルは 0 バイトで、
// 何も知らせない。高さ 2 なら同じ頼みで中身のある MP4 が書ける (陰性対照)。
//
// 期待は、中身のあるファイルを書くか、書けないことを名乗って 0 以外で終わることである
// (`RenderRequest` の「書き出せない組は作らない」・`.gif` は割り切れない fps を書く前に断る)。
//
// **このファイルは mokume だけで閉じる** (probes の docs/filing.md)。単独で走らせると、自分自身を子として
// 2 回起こす (`PROBES_MP4_THIN_CHILD` が子の役の印)。

import Foundation
import mokume

@MainActor
enum Mp4ThinFrame {
    /// 子の役の印。値は `<幅>x<高さ>:<行き先>`。
    static let childKey = "PROBES_MP4_THIN_CHILD"

    /// 子 1 回ぶんの終わり方。
    struct Outcome {
        let status: Int32
        let bytes: Int
        let said: String
    }

    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        if let request = ProcessInfo.processInfo.environment[childKey] {
            let parts = request.split(separator: ":", maxSplits: 1).map(String.init)
            let sides = parts[0].split(separator: "x").compactMap { Int($0) }
            try renderAsChild(width: sides[0], height: sides[1], to: parts[1])
        }
        let control = try spawn(width: 64, height: 2)
        guard control.status == 0, control.bytes > 0 else {
            return "control broke: 64x2 -> exit \(control.status), \(control.bytes) B, said \(control.said.debugDescription)"
        }
        return verdict(try spawn(width: 64, height: 1))
    }

    /// 子の役。書き出しの頼みを立てて走らせる。**戻らない** — 書き切れば 0、止まれば 1 で終わる。
    static func renderAsChild(width: Int, height: Int, to path: String) throws {
        Scene.size = (width, height)
        setenv("MOKUME_RENDER", "25:5:\(path)", 1)
        try SketchApplication(sketch: Scene(), gpu: RenderDevice()).run()
    }

    /// 幅 64・高さ 1 の子の終わり方を判定する。
    static func verdict(_ thin: Outcome) -> String? {
        if thin.bytes > 0 || thin.status != 0 { return nil }
        return "64x1 -> .mp4 of \(thin.bytes) B, exit \(thin.status), "
            + "said \(thin.said.isEmpty ? "nothing" : thin.said.debugDescription) "
            + "(64x2 with the same request wrote a playable .mp4)"
    }

    /// 行き先のバイト数。無ければ -1。
    static func bytes(at path: String) -> Int {
        ((try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int) ?? -1
    }

    /// 自分自身を子の役で起こし、終わり方を集める。
    private static func spawn(width: Int, height: Int) throws -> Outcome {
        let path = FileManager.default.temporaryDirectory
            .appendingPathComponent("mp4-thin-\(getpid())-\(width)x\(height).mp4").path
        try? FileManager.default.removeItem(atPath: path)
        let child = Process()
        child.executableURL = URL(fileURLWithPath: CommandLine.arguments[0])
        var environment = ProcessInfo.processInfo.environment
        environment[childKey] = "\(width)x\(height):\(path)"
        child.environment = environment
        let errors = Pipe()
        child.standardError = errors
        child.standardOutput = FileHandle.nullDevice
        try child.run()
        let said = String(decoding: errors.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        child.waitUntilExit()
        return Outcome(
            status: child.terminationStatus, bytes: bytes(at: path),
            said: said.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    final class Scene: Sketch {
        nonisolated(unsafe) static var size = (64, 1)
        var settings = SketchSettings(width: Scene.size.0, height: Scene.size.1, frameRate: 25, title: "repro")

        func draw() {
            background(Float(frameCount * 40 % 255), 80, 160)
        }
    }
}
