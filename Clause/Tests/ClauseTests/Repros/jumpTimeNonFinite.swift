// repro: mokume#未起票
//
import Foundation
import mokume

/// `jumpTime(.nan)` / `jumpTime(.infinity)` を受けると、その後の `time` が数でない値・無限のまま
/// 戻らない (止める・再開するでも戻らない)。注意も出ない。
///
/// 期待: ADR-0020 決定 5 — フレームごとに呼ばれる口は受け口で値を検め、注意を出して安全な既定へ
/// 倒す。同じ動詞の兄弟 `Movie.jump(_:)` は数でない値・無限を「位置を変えず、1 度だけ知らせる」
/// (Sources/MokumeCamera/Movie.swift:122-123)。
enum JumpTimeNonFinite {
    final class Probe: Sketch {
        var settings = SketchSettings(width: 8, height: 4)
        var target: Float = 0
        var times: [Float] = []
        init() {}
        func draw() {
            times.append(time)
            background(0)
            switch frameCount {
            case 2: jumpTime(target)  // 3 枚目から効く
            case 4: pauseTime()       // 止めて
            case 5: playTime()        // 再開しても
            default: break
            }
        }
    }

    @MainActor
    static func times(after target: Float) throws -> [Float] {
        let sketch = Probe(); sketch.target = target
        let runtime = try SketchRuntime(sketch: sketch, gpu: RenderDevice())
        for _ in 0..<8 { try runtime.advance() }
        return sketch.times
    }

    @MainActor
    static func reproduce() throws -> String? {
        // 陰性対照: 有限の負の秒は受けて、そこから進む (DocC「負の秒も受ける」)
        let negative = try times(after: -1)
        guard negative[2] == -1, negative.allSatisfy(\.isFinite) else {
            return "control broke: jumpTime(-1) → \(negative)"
        }
        var broken: [String] = []
        for target in [Float.nan, .infinity, -.infinity] {
            let times = try times(after: target)
            let bad = times.filter { !$0.isFinite }.count
            if bad > 0 {
                broken.append("jumpTime(\(target)) → 8 枚のうち \(bad) 枚の time が非有限 \(times)")
            }
        }
        return broken.isEmpty ? nil : broken.joined(separator: "\n")
    }
}
