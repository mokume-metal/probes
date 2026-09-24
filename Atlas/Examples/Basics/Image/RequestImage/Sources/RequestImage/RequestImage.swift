import Foundation
import mokume
import Support

/// Processing の [Request Image](https://processing.org/examples/requestimage/) を 1 行ずつ移したもの。
/// 原典は Ira Greenberg 作。
///
/// **台帳は `bend` と言った。当たっている。** `requestImage` はあるが**待つ形**
/// (`async`) なので、原典のように「戻り値の `width` が 0 かどうかで読み終わりを見る」
/// ことができない。読み終わったかどうかを自分で持つ必要がある。
/// `nf(i, 4)` も無いので `String(format:)` へ。
final class RequestImage: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Request Image")

    private let imgCount = 12
    private var imgs: [Image?] = []
    private var loadStates: [Bool] = []
    private var loaderX: Float = 0
    private var loaderY: Float = 0
    private var theta: Float = 0

    func setup() {
        imgs = Array(repeating: nil, count: imgCount)
        loadStates = Array(repeating: false, count: imgCount)
        // 待たずに読む。**原典は戻ってきた絵の width で読み終わりを見るが、
        // mokume は待つ形なので、読み終わりはこちらで持つ**
        for i in 0..<imgCount {
            let path = asset("Basics/Image/RequestImage", String(format: "PT_anim%04d.gif", i))
            Task { @MainActor in
                if let picture = try? await requestImage(path) {
                    imgs[i] = picture
                    loadStates[i] = true
                }
            }
        }
    }

    func draw() {
        background(0)
        runLoaderAni()
        if checkLoadStates() { drawImages() }
    }

    private func drawImages() {
        guard let first = imgs[0] else { return }
        let y = (height - Float(first.height)) / 2
        for (i, picture) in imgs.enumerated() {
            guard let picture else { continue }
            image(picture, width / Float(imgs.count) * Float(i), y,
                  Float(picture.height), Float(picture.height))
        }
    }

    private func runLoaderAni() {
        // 読み込み中だけ回す
        if !checkLoadStates() {
            ellipse(loaderX, loaderY, 10, 10)
            loaderX += 2
            loaderY = height / 2 + sin(theta) * (height / 8)
            theta += .pi / 22
            if loaderX > width + 5 { loaderX = -5 }
        }
    }

    private func checkLoadStates() -> Bool {
        !loadStates.contains(false)
    }
}
