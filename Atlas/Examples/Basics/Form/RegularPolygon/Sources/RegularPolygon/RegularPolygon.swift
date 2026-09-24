import Foundation
import mokume

/// Processing の [Regular Polygon](https://processing.org/examples/regularpolygon/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `frameCount` / `beginShape` / `vertex` / `endShape(CLOSE)` はすべて名前どおり届く。
final class RegularPolygon: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Regular Polygon")

    func draw() {
        background(102)

        pushMatrix()
        translate(width * 0.2, height * 0.5)
        rotate(Float(frameCount) / 200.0)
        polygon(0, 0, 82, 3)   // 三角形
        popMatrix()

        pushMatrix()
        translate(width * 0.5, height * 0.5)
        rotate(Float(frameCount) / 50.0)
        polygon(0, 0, 80, 20)  // 20 角形
        popMatrix()

        pushMatrix()
        translate(width * 0.8, height * 0.5)
        rotate(Float(frameCount) / -100.0)
        polygon(0, 0, 70, 7)   // 7 角形
        popMatrix()
    }

    private func polygon(_ x: Float, _ y: Float, _ radius: Float, _ npoints: Int) {
        let angle = (.pi * 2) / Float(npoints)
        beginShape()
        for a in stride(from: Float(0), to: .pi * 2, by: angle) {
            vertex(x + cos(a) * radius, y + sin(a) * radius)
        }
        endShape(.close)
    }
}
