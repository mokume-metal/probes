import mokume

/// mokume が**書き出したファイルの中身**を突く物差しの窓。
///
/// **作品ではない。** 数で押さえるのは `Tests/ImprintTests` の側で、そちらは窓を出さずに
/// `SketchRuntime` を回して書き出し、出てきた PNG・連番・動画を読み戻す (README
/// 「何をしているか」)。窓は、検査が焼いている番号の升と動く円を目で見るためだけにある。
/// スペースを押すと、`imprint-###.png` への連番を撮り始める (もう一度押すと止める)。
@main
final class Imprint: Sketch {
    var settings = SketchSettings(width: 480, height: 270, frameRate: 60, title: "imprint — mokume v0.11.2")
    private var recording = false

    func keyPressed() {
        guard key == " " else { return }
        recording ? endRecord() : beginRecord("imprint-###.png")
        recording.toggle()
    }

    func draw() {
        background(40)
        noStroke()
        fill(240, 140, 40)
        circle(Float(frameCount % 120) * 4, 180, 40)
        Stamp.draw(frameCount, on: self)
        fill(230)
        textSize(14)
        text("frame \(frameCount)  —  左上の升がフレーム番号 (2 進、左が下の桁)", 16, 40)
        text(recording ? "● 連番を撮っている (スペースで止める)" : "スペースで imprint-###.png へ連番を撮る", 16, 64)
    }
}
