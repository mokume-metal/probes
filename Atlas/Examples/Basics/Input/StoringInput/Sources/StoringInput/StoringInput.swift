import mokume

/// Processing の [Storing Input](https://processing.org/examples/storinginput/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `fill(255, 153)` の**明るさ + 透かしの 2 つ組**が
/// 書けない。`frameCount` はそのまま届く。
final class StoringInput: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Storing Input")

    private let num = 60
    private var mx: [Float] = []
    private var my: [Float] = []

    func setup() {
        noStroke()
        fill(255, 153)
        mx = [Float](repeating: 0, count: num)
        my = [Float](repeating: 0, count: num)
    }

    func draw() {
        background(51)

        // 並びを 1 つずつ使い回す。剰余で回すほうが、値を全部ずらすより速い
        let which = frameCount % num
        mx[which] = mouseX
        my[which] = mouseY

        for i in 0..<num {
            // which+1 がいちばん古い
            let index = (which + 1 + i) % num
            ellipse(mx[index], my[index], Float(i), Float(i))
        }
    }
}
