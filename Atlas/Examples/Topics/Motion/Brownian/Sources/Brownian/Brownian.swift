import mokume
import Support

/// Processing の [Brownian](https://processing.org/examples/brownian/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言った。当たっている** — `frameRate(30)` が走り出す前にしか
/// 決められない。`constrain()` も無いので面の外に書く。
///
/// 乱数で歩くので **画素では比べられない。**
final class Brownian: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "Brownian")

    private let num = 2000
    private let range: Float = 6
    private var ax: [Float] = []
    private var ay: [Float] = []

    func setup() {
        ax = [Float](repeating: width / 2, count: num)
        ay = [Float](repeating: height / 2, count: num)
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
    }

    func draw() {
        background(51)

        // 中身を 1 つずつ左へ寄せる
        for i in 1..<num {
            ax[i - 1] = ax[i]
            ay[i - 1] = ay[i]
        }
        // 末尾に新しい値を置く
        ax[num - 1] += random(-range, range)
        ay[num - 1] += random(-range, range)
        // 面の中へ収める
        ax[num - 1] = constrain(ax[num - 1], 0, width)
        ay[num - 1] = constrain(ay[num - 1], 0, height)

        // 点をつないだ線を引く
        for i in 1..<num {
            let val = Float(i) / Float(num) * 204.0 + 51
            stroke(val)
            line(ax[i - 1], ay[i - 1], ax[i], ay[i])
        }
    }
}
