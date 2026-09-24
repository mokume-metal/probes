import Foundation
import mokume

extension Entries {
    static let structure: [Entry] = [
        Entry(section: .structure, reference: "setup() / draw()", verdict: .same, mokume: "setup() / draw()",
              tile: .value { r in "frame \(r.frameCount)" }),
        Entry(section: .structure, reference: "noLoop() / loop()", verdict: .same, mokume: "noLoop() / loop() / redraw()",
              note: "v0.9.0 で入った (mokume#900)",
              tile: .value { r in
                  unreached { r.noLoop(); r.loop(); r.redraw() }
                  return "noLoop"
              }),
        Entry(section: .structure, reference: "frameCount", verdict: .same, mokume: "frameCount",
              tile: .value { r in "\(r.frameCount)" }),
        Entry(section: .structure, reference: "deltaTime", verdict: .bend, mokume: "deltaTime * 1000",
              note: "同じ名前で単位が違う (手本はミリ秒、mokume は秒)。p5 のコードを写すと黙って 1000 倍ずれる", issue: "mokume#1572",
              tile: .value { r in String(format: "%.3f s", r.deltaTime) }),
        Entry(section: .structure, reference: "millis()", verdict: .bend, mokume: "time * 1000",
              note: "`time` はそのフレームの時刻で、フレームの途中では進まない。処理の時間を測る使い方 (`millis() - t0`) は書けず、works の 4 作品が Date() で書いている。mokume は `millis()` ではなく、区間を測って観測へ出す口を足す方向でトリアージした", issue: "mokume#1554",
              tile: .value { r in "\(Int(r.time * 1000)) ms" }),
        Entry(section: .structure, reference: "frameRate(fps)", verdict: .bend, mokume: "SketchSettings(frameRate:)",
              note: "起動のときだけ決まる。走っている最中の代入は黙って効かない", issue: "mokume#1323",
              tile: .value { r in "\(r.settings.frameRate) fps" }),
        Entry(section: .structure, reference: "createCanvas(w, h)", verdict: .renamed, mokume: "SketchSettings(width:height:)",
              note: "Processing の size()",
              tile: .value { r in "\(Int(r.width))×\(Int(r.height))" }),
        Entry(section: .structure, reference: "width / height", verdict: .same, mokume: "width / height",
              note: "Float で返る",
              tile: .picture { c, r in
                  c.noStroke()
                  c.rect(0, 0, s * 0.5, s * 0.5)
                  _ = (r.width, r.height)
              }),
        Entry(section: .structure, reference: "pixelDensity(d)", verdict: .renamed, mokume: "SketchSettings(pixelDensity:)",
              note: "起動のときだけ決まる",
              tile: .value { r in "×\(r.settings.pixelDensity)" }),
        Entry(section: .structure, reference: "resizeCanvas() / windowResized()", verdict: .none, mokume: "—",
              note: "面の大きさは起動のときに決まり、窓の大きさが変わったことを受ける口も無い",
              tile: .absent),
        Entry(section: .structure, reference: "fullscreen()", verdict: .none, mokume: "—",
              note: "Processing の fullScreen()。SketchSettings に全画面の指定が無い",
              tile: .absent),
        Entry(section: .structure, reference: "cursor() / noCursor()", verdict: .none, mokume: "—",
              note: "カーソルの形を変える口・隠す口が無い (一人称で捕まえる話は mokume#1144)",
              tile: .absent),
        Entry(section: .structure, reference: "second() / hour() / year()", verdict: .write, mokume: "clockField(.second)",
              note: "壁時計の値は Foundation の Calendar が持つ",
              tile: .value { _ in "\(clockField(.hour)):\(clockField(.minute))" }),
        Entry(section: .structure, reference: "push() / pop()", verdict: .same, mokume: "push() / pop()",
              tile: .picture { c, _ in
                  c.push()
                  c.fill(60, 160, 230)
                  c.translate(20, 20)
                  c.rect(0, 0, 40, 40)
                  c.pop()
                  c.rect(40, 40, 40, 40)
              }),
        Entry(section: .structure, reference: "exit()", verdict: .host, mokume: "Foundation.exit(0)",
              note: "後始末を通らずに止まる。窓を閉じる口は mokume に無い",
              tile: .value { _ in
                  unreached { Foundation.exit(0) }
                  return "exit"
              }),
    ]
}
