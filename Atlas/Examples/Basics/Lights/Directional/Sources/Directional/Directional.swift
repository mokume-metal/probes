import mokume

/// Processing の [Directional](https://processing.org/examples/directional/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ。** `directionalLight` は色を 3 数ではなく
/// `LinearRGBA` で取るので、原典の 6 引数が 4 引数になる。
final class Directional: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Directional")

    func setup() {
        noStroke()
        fill(204)
    }

    func draw() {
        noStroke()
        background(0)
        let dirY = (mouseY / height - 0.5) * 2
        let dirX = (mouseX / width - 0.5) * 2
        directionalLight(204, 204, 204, -dirX, -dirY, -1)
        translate(width / 2 - 100, height / 2, 0)
        sphere(80)
        translate(200, 0, 0)
        sphere(80)
    }
}
