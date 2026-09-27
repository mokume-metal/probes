import Foundation
import mokume

/// mokume を**乱数から作った呼び出しの列**で突く物差し。
///
/// **作品ではない。** 種 1 つから口録 (`Catalog`) の口と引数 (端の値を含む) を引いて列を
/// 作り、窓を出さずに回して判定する — 落ちない・止まらない・投げない・毎回同じ絵が出る・
/// 列の後の番兵が列を回さなかった番兵と同じ・絵が数である・漏れない (README「何をしているか」)。
///
/// 引数で走り方が変わる:
///
/// ```
/// Tumble                                  窓で種を 1 つずつ回す (← → で替える)
/// Tumble --headless --seeds 0..<500       窓を出さずに回し、1 種 1 行の JSON を出す
/// Tumble --headless --seeds 0..<50 --soak  列を繰り返し回し、漏れを測る (1 種 1 行の JSON)
/// Tumble --headless --program p.json      列を 1 本回す (縮小器が使う。`--soak` も付けられる)
///        [--shots <dir> --key <鍵>]       読んだ絵を書き出す (scripts/shots.py が組む)
/// Tumble --emit 17                        種 17 の列を JSON で出す
/// Tumble --swift 17 | p.json              列を Swift で出す (再現に起こすのに使う)
/// ```
@main
final class Tumble: Sketch {
    static func main() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        if arguments.isEmpty {
            // mokume の既定の入口 (`Sketch.main()`) と同じ
            do {
                let application = try SketchApplication(sketch: Tumble(), gpu: RenderDevice())
                application.run()
            } catch {
                FileHandle.standardError.write(Data("起動できませんでした: \(error)\n".utf8))
                exit(1)
            }
            return
        }
        exit(Command.run(arguments))
    }

    var settings = SketchSettings(width: 720, height: 400, frameRate: 10, title: "tumble — mokume v0.12.1")

    private var seed: UInt64 = 0
    private var program = Program.empty
    private var runtime: SketchRuntime?
    private var shown: Image?
    private var reference: Image?

    func setup() {
        show(0)
        reference = picture(of: .empty, frames: 1)
    }

    func keyPressed() {
        if keyCode == .arrowRight { show(seed + 1) }
        if keyCode == .arrowLeft, seed > 0 { show(seed - 1) }
    }

    private func show(_ next: UInt64) {
        seed = next
        program = Program.generate(seed: seed)
        runtime = try? SketchRuntime(sketch: Played(program), gpu: Examine.gpu)
    }

    /// 列を `frames` 枚回した絵。
    private func picture(of program: Program, frames: Int) -> Image? {
        guard let runtime = try? SketchRuntime(sketch: Played(program), gpu: Examine.gpu) else { return nil }
        defer { runtime.closePlugins() }
        for _ in 0..<frames { try? runtime.advance() }
        guard let display = try? runtime.target.encodeForDisplay(), let image = try? createImage(display.width, display.height)
        else { return nil }
        image.write(display)
        return image
    }

    func draw() {
        background(12)
        fill(230)
        noStroke()
        textAlign(.left, .top)
        textSize(14)
        text("seed \(seed) — \(program.count) 口・\(program.frames.count) 枚 + 番兵   (← → で種を替える)", 16, 12)
        // 列を 1 枚ずつ進め、番兵まで来たら頭から回し直す
        if let current = runtime {
            if current.frameCount > program.frames.count { runtime = try? SketchRuntime(sketch: Played(program), gpu: Examine.gpu) }
            if let runtime, (try? runtime.advance()) != nil, let display = try? runtime.target.encodeForDisplay() {
                if shown?.width != display.width || shown?.height != display.height { shown = try? createImage(display.width, display.height) }
                shown?.write(display)
            }
        }
        if let shown { image(shown, 16, 40, 320, 240) }
        if let reference { image(reference, 352, 40, 320, 240) }
        textSize(11)
        fill(150)
        text("左: 列 (最後が番兵)  右: 列を回さなかった番兵", 16, 288)
        text(program.swift.split(separator: "\n").prefix(8).joined(separator: "\n"), 16, 306, 690, 90)
    }
}

/// 窓を出さない走り方。
@MainActor
enum Command {
    static func run(_ arguments: [String]) -> Int32 {
        func value(_ flag: String) -> String? {
            arguments.firstIndex(of: flag).flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        func emit(_ value: some Encodable) {
            let data = try! encoder.encode(value)
            FileHandle.standardOutput.write(data + Data("\n".utf8))
        }
        do {
            if let seed = value("--emit").flatMap(UInt64.init) {
                emit(Program.generate(seed: seed))
                return 0
            }
            if let target = value("--swift") {
                print(try load(target).swift)
                return 0
            }
            guard arguments.contains("--headless") else {
                FileHandle.standardError.write(Data("使い方は Sources/Tumble/Tumble.swift の冒頭\n".utf8))
                return 2
            }
            let soaking = arguments.contains("--soak")
            if let path = value("--program"), soaking {
                emit(try Examine.soak(try load(path)))
                return 0
            }
            if let path = value("--program") {
                let shots = value("--shots").map { URL(fileURLWithPath: $0) }
                if let shots { try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
                emit(try Examine.examine(try load(path), shots: shots, key: value("--key") ?? "tumble"))
                return 0
            }
            guard let range = value("--seeds").flatMap(parse) else {
                FileHandle.standardError.write(Data("--seeds A..<B か --program が要る\n".utf8))
                return 2
            }
            for seed in range {
                // 落ちたときにどの種だったか分かるよう、回す前に名乗る
                emit(["start": seed])
                let program = Program.generate(seed: seed)
                if soaking { emit(try Examine.soak(program)) } else { emit(try Examine.examine(program)) }
            }
            return 0
        } catch {
            FileHandle.standardError.write(Data("\(error)\n".utf8))
            return 3
        }
    }

    /// `A..<B` を読む。
    static func parse(_ text: String) -> Range<UInt64>? {
        let parts = text.components(separatedBy: "..<")
        guard parts.count == 2, let low = UInt64(parts[0]), let high = UInt64(parts[1]), low <= high else { return nil }
        return low..<high
    }

    /// 種の数字か、列の JSON のパスから列を読む。
    static func load(_ target: String) throws -> Program {
        if let seed = UInt64(target) { return Program.generate(seed: seed) }
        return try JSONDecoder().decode(Program.self, from: Data(contentsOf: URL(fileURLWithPath: target)))
    }
}
