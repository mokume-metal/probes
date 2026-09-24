import mokume
import Support

/// Processing の [Sequential](https://processing.org/examples/sequential/) を 1 行ずつ移したもの。
/// 原典は James Paterson 作。
///
/// **台帳は `bend` と言った。当たっている** — `frameRate(24)` は走り出す前にしか
/// 決められないので `SketchSettings` へ移る。連番の絵を読むところはそのまま届く。
final class Sequential: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 24, title: "Sequential")

    private let numFrames = 12   // 動きの枚数
    private var currentFrame = 0
    private var images: [Image?] = []

    func setup() {
        // 原典はここで `frameRate(24)` を呼ぶ。settings へ移した
        // 原典は 12 行を書き下しているが、注釈のとおり綴りを組み立ててもよい
        images = (0..<numFrames).map {
            try? loadImage(asset("Topics/Animation/Sequential", String(format: "PT_anim%04d.gif", $0)))
        }
    }

    func draw() {
        background(0)
        currentFrame = (currentFrame + 1) % numFrames
        var offset = 0
        guard let first = images[0] else { return }
        for x in stride(from: Float(-100), to: width, by: Float(first.width)) {
            if let picture = images[(currentFrame + offset) % numFrames] {
                image(picture, x, -20)
            }
            offset += 2
            if let picture = images[(currentFrame + offset) % numFrames] {
                image(picture, x, height / 2)
            }
            offset += 2
        }
    }
}
