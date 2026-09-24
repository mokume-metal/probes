import mokume

/// Processing の [Embedding Iteration](https://processing.org/examples/embeddediteration/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。** 詰まるのは色の渡し方だけで、`stroke(255, 100)` の
/// **明るさ + 透かしの 2 つ組**もここに出る (`color(255, 100)` へ)。
final class EmbeddedIteration: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Embedded Iteration")

    func setup() {
        background(0)

        let gridSize = 40
        for x in stride(from: gridSize, through: Int(width) - gridSize, by: gridSize) {
            for y in stride(from: gridSize, through: Int(height) - gridSize, by: gridSize) {
                noStroke()
                fill(255)
                rect(Float(x) - 1, Float(y) - 1, 3, 3)
                stroke(255, 100)
                line(Float(x), Float(y), width / 2, height / 2)
            }
        }
    }
}
