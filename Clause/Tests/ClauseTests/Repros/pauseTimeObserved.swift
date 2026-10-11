// repro: mokume#未起票
//
import Foundation
import mokume

/// 時刻を指定した観測 (`{"time": 5}`) が描き直す 1 枚の中で `pauseTime()` を呼ぶと、観測の秒 (5) で
/// 止まる。作者の時計 (その枚の本来の時刻) へ戻らない。
///
/// 期待: Sources/MokumeCore/Sketch/Clock.swift:157-158「観測の指定秒はずれに触れない — 撮った後は
/// 作者の時計へ戻る」・Sources/MokumeCore/Observation/ObservationRequest.swift:15「次は元の時計へ戻る」。
/// `pauseTime()` の止めた秒は「呼んだフレームの値」(Sketch+Time.swift:51) だが、観測の枚の `time` は
/// 作者の時計の値ではない。
///
/// 観測の要求 (`request.json`) は、プロセスの基準の下の `.mokume/observe/` に置いて、走らせた後に消す。
enum PauseTimeObserved {
    final class Probe: Sketch {
        var settings = SketchSettings(width: 8, height: 4)
        var pauseOnObserved = true
        var times: [Float] = []
        init() {}
        func draw() {
            times.append(time)
            background(0)
            if pauseOnObserved, frameCount == 4 { pauseTime() }
            if !pauseOnObserved, frameCount == 5 { pauseTime() }
        }
    }

    /// 4 枚目を観測で 5 秒に描き直させ、8 枚の time を返す。
    @MainActor
    static func run(pauseOnObserved: Bool) throws -> [Float] {
        // 観測の区画は、プロセスの基準 (作業ディレクトリか MOKUME_WORK_DIR) の下の .mokume/observe。
        // 基準は起動時に 1 度だけ決まるので、ここで動かさずに公開の口から場所を引く
        let facet = WorkDirectory.facet("observe")
        try FileManager.default.createDirectory(at: facet, withIntermediateDirectories: true)
        let request = facet.appendingPathComponent("request.json")
        try? FileManager.default.removeItem(at: request)
        defer { try? FileManager.default.removeItem(at: request) }
        let sketch = Probe(); sketch.pauseOnObserved = pauseOnObserved
        let runtime = try SketchRuntime(sketch: sketch, gpu: RenderDevice())
        for frame in 1...8 {
            if frame == 4 {
                try Data("{\"id\":\"\(UUID().uuidString)\",\"time\":5}".utf8).write(to: request)
            }
            try runtime.advance()
        }
        return sketch.times
    }

    @MainActor
    static func reproduce() throws -> String? {
        // 陰性対照: 観測の次の枚 (作者の時計の 5 枚目 = 4/60 秒) で止めると、その秒で止まる
        let control = try run(pauseOnObserved: false)
        guard control[3] == 5, control[4...].allSatisfy({ $0 == Float(4.0 / 60) }) else {
            return "control broke: 観測の次の枚で pauseTime() → \(control)"
        }
        let times = try run(pauseOnObserved: true)
        guard times[3] == 5 else { return "観測が効いていない (4 枚目の time = \(times[3]))" }
        // 作者の時計での 4 枚目は 3/60 秒。止めた後の枚はそこに留まるはず
        let expected = Float(3.0 / 60)
        let held = Array(times[4...])
        if held.allSatisfy({ $0 == expected }) { return nil }
        return "観測の枚で pauseTime() → 5..8 枚目の time = \(held) (期待 \(expected))"
    }
}
