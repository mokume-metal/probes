import Foundation
import mokume

/// Processing の [Polar To Cartesian](https://processing.org/examples/polartocartesian/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。当たっている** (色の書き下しを除く)。
/// `translate` / `ellipseMode(CENTER)` は `ShapeMode.center` へ名前が変わるだけで届く。
final class PolarToCartesian: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Polar To Cartesian")

    private var r: Float = 0

    // 角度と、その速さ・加速
    private var theta: Float = 0
    private var thetaVel: Float = 0
    private var thetaAcc: Float = 0

    func setup() {
        r = height * 0.45
        theta = 0
        thetaVel = 0
        thetaAcc = 0.0001
    }

    func draw() {
        background(0)

        // 原点を面の中央へ移す
        translate(width / 2, height / 2)

        // 極座標から直交座標へ
        let x = r * cos(theta)
        let y = r * sin(theta)

        ellipseMode(.center)
        noStroke()
        fill(200)
        ellipse(x, y, 32, 32)

        // 角度に加速と速さを効かせる
        thetaVel += thetaAcc
        theta += thetaVel
    }
}
