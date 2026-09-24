import mokume
import Support

/// Processing の [Animated Sprite](https://processing.org/examples/animatedsprite/) を 1 行ずつ移したもの。
/// 原典は James Paterson 作。
///
/// **台帳は `bend` と言った。当たっている。** `frameRate(24)` は settings へ移り、
/// `mousePressed` は変数なので `isMousePressed` へ、`nf(i, 4)` は `String(format:)` へ。
/// 描く口が面の上にあるので `display(on:)` が面を受け取る。
final class AnimatedSprite: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 24, title: "Animated Sprite")

    /// 原典の `class Animation`。
    final class Animation {
        var images: [Image?] = []
        let imageCount: Int
        var frame = 0

        init(_ imagePrefix: String, _ count: Int, load: (String) -> Image?) {
            imageCount = count
            images = (0..<count).map { load(imagePrefix + String(format: "%04d", $0) + ".gif") }
        }

        func display(on sketch: any Sketch, _ xpos: Float, _ ypos: Float) {
            frame = (frame + 1) % imageCount
            if let picture = images[frame] { sketch.image(picture, xpos, ypos) }
        }

        func getWidth() -> Float { Float(images[0]?.width ?? 0) }
    }

    private var animation1: Animation?
    private var animation2: Animation?
    private var xpos: Float = 0
    private var ypos: Float = 0
    private let drag: Float = 30.0

    func setup() {
        background(255, 204, 0)
        // 原典はここで `frameRate(24)` を呼ぶ。settings へ移した
        let load: (String) -> Image? = { [self] name in
            try? loadImage(asset("Topics/Animation/AnimatedSprite", name))
        }
        animation1 = Animation("PT_Shifty_", 38, load: load)
        animation2 = Animation("PT_Teddy_", 60, load: load)
        ypos = height * 0.25
    }

    func draw() {
        let dx = mouseX - xpos
        xpos = xpos + dx / drag
        guard let animation1, let animation2 else { return }
        if isMousePressed {
            background(153, 153, 0)
            animation1.display(on: self, xpos - animation1.getWidth() / 2, ypos)
        } else {
            background(255, 204, 0)
            animation2.display(on: self, xpos - animation1.getWidth() / 2, ypos)
        }
    }
}
