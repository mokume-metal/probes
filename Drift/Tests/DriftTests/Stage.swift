import CryptoKit
import Foundation
import mokume

@testable import Drift

/// 候補 1 件の 1 経路だけを載せた舞台。窓のタイル 1 枚と同じものを、窓を出さずに描く。
///
/// **経路ごとに別の舞台で回す。** 窓では左右が 1 枚の面を分け合うので、並び (`numbers`)
/// や切り抜きを片方が戻し忘れるともう片方に漏れる。検査ではその漏れを疑いに含めない。
final class Stage: Sketch {
    var settings = SketchSettings(
        width: Motions.side, height: Motions.side, frameRate: Motions.frameRate, title: "stage")

    let motion: any Motion

    init(_ key: MotionKey, _ route: Route) {
        motion = Motions.named(key).make(route)
    }

    /// `Sketch` が求めるだけで、検査からは呼ばない。
    convenience init() { self.init(.graphicsTime, .reference) }

    func setup() { motion.setup(self) }

    func draw() {
        background(12)
        motion.draw(self, at: .zero)
    }
}

/// 窓を出さずに `frames` 枚回し、読んだフレームの絵を返す。
///
/// **時計はフレーム番号から導く** (`SketchRuntime` の既定) ので、`frameRate` 30 なら
/// n 枚目の `time` は (n − 1) / 30 秒、`deltaTime` はいつも 1/30 秒である。同じ機械なら
/// 毎回同じ絵が出る。
///
/// - Parameters:
///   - reading: 絵を読むフレーム (1 始まり)。省くと最後の 1 枚だけ。
///   - before: 各フレームを進める直前に呼ぶ。入力を送るのに使う。
@MainActor
func run(
    _ sketch: any Sketch, frames: Int, reading: Set<Int>? = nil, dump: String? = nil,
    before: ((Int, SketchRuntime) -> Void)? = nil
) throws -> [Int: Picture] {
    let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
    defer { runtime.closePlugins() }
    let wanted = reading ?? [frames]
    var pictures: [Int: Picture] = [:]
    for frame in 1...frames {
        before?(frame, runtime)
        try runtime.advance()
        if wanted.contains(frame) {
            let pixels = try runtime.target.readPixels()
            try fingerprint(pixels, name: dump ?? "unnamed", frame: frame)
            try shoot(runtime.target, name: dump ?? "unnamed", frame: frame)
            pictures[frame] = Picture(pixels)
        }
    }
    if let dump, let directory = ProcessInfo.processInfo.environment["DRIFT_DUMP"] {
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(dump).png")
        try runtime.target.writePNG(to: url)
    }
    return pictures
}

/// 候補 1 件の 1 経路を回す。
@MainActor
func run(_ key: MotionKey, _ route: Route, frames: Int, reading: Set<Int>? = nil) throws -> [Int: Picture] {
    try run(Stage(key, route), frames: frames, reading: reading, dump: "\(key)-\(route)")
}

@MainActor let gpu = try! RenderDevice()

/// 読み戻した画素。**値は線形・乗算済み**。
struct Picture {
    let pixels: PixelBuffer
    init(_ pixels: PixelBuffer) { self.pixels = pixels }

    var width: Int { pixels.width }
    var height: Int { pixels.height }

    subscript(x: Int, y: Int) -> LinearRGBA { pixels[x, y] }

    /// 条件を満たす画素の数。`columns` で調べる列を絞れる。
    func count(columns: Range<Int>? = nil, where test: (LinearRGBA, Int, Int) -> Bool) -> Int {
        var count = 0
        for y in 0..<height {
            for x in columns ?? 0..<width where test(self[x, y], x, y) { count += 1 }
        }
        return count
    }
}

/// 読んだ絵を、環境変数 `PROBES_SHOTS` の置き場へ PNG で書く (`scripts/shots.py` が組み立てる)。
///
/// **`fingerprint` と同じ名前とフレームで書く**ので、指紋の行と絵が 1 対 1 に対応する。mokume へ
/// 起票するときに添える比べる絵の元である (`.claude/skills/probes-evidence/`)。書くのは出す面
/// (`writePNG` = 表示に符号化した絵) で、置き場は `<PROBES_SHOTS>/Drift/<name>-<frame>.png`。
/// 変数が無ければ何もしない。
@MainActor
func shoot(_ target: RenderTarget, name: String, frame: Int) throws {
    guard let root = ProcessInfo.processInfo.environment["PROBES_SHOTS"] else { return }
    let directory = URL(fileURLWithPath: root).appendingPathComponent("Drift", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = String(name.map { $0.isLetter || $0.isNumber || $0 == "-" ? $0 : "_" })
    try target.writePNG(to: directory.appendingPathComponent("\(file)-\(frame).png"))
}

/// 描いた絵の指紋を、環境変数 `PROBES_FINGERPRINT` の置き場へ 1 行足す (`scripts/stress.py` が読む)。
///
/// **同じフレーム番号からはバイト単位で同じ絵が出る** (mokume ADR-0001 原則 2)。反復・検証レイヤ・
/// 同時実行をまたいで指紋が食い違えば、許容誤差の内に収まるずれでも約束の破れである (ADR-0007)。
/// 変数が無ければ何もしない。
@MainActor
func fingerprint(_ pixels: PixelBuffer, name: String, frame: Int) throws {
    guard let directory = ProcessInfo.processInfo.environment["PROBES_FINGERPRINT"] else { return }
    var hasher = SHA256()
    for y in 0..<pixels.height {
        for x in 0..<pixels.width {
            let c = pixels[x, y]
            for value in [c.red, c.green, c.blue, c.alpha] {
                withUnsafeBytes(of: value.bitPattern) { hasher.update(bufferPointer: $0) }
            }
        }
    }
    let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
    let url = URL(fileURLWithPath: directory).appendingPathComponent("Drift-\(getpid()).tsv")
    let line = Data("\(name)\t\(frame)\t\(digest)\n".utf8)
    if !FileManager.default.fileExists(atPath: url.path) {
        try Data().write(to: url)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: line)
}
