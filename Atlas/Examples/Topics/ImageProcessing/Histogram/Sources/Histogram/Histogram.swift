import mokume
import Support

/// Processing の [Histogram](https://processing.org/examples/histogram/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**判定の根拠は `brightness()` に
/// 口が無いことだったが、`v0.6.0` で入った。**ただし目盛りが違う** — mokume は
/// 0…100 の百分率で返し、原典は colorMode の上限 (既定 255) で返す。
/// **同じ名前で違う数を返す**ところが、名前しか見ない台帳には写らない。原典は静止形。
final class Histogram: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Histogram")

    func setup() {
        guard let img = try? loadImage(asset("Topics/Image Processing/Histogram", "frontier.jpg"))
        else { return }
        image(img, 0, 0)

        var hist = [Int](repeating: 0, count: 256)
        for i in 0..<img.width {
            for j in 0..<img.height {
                // 原典は `brightness(get(i, j))` — 面から引く。ここは絵から引く
                // `brightness()` は 0…100 の百分率で返るので、度数の目盛り (0…255) へ直す
                let bright = Int(brightness(img.get(i, j)) * 2.55)
                hist[min(max(bright, 0), 255)] += 1
            }
        }

        let histMax = hist.max() ?? 1
        stroke(255)
        for i in stride(from: 0, to: img.width, by: 2) {
            // i (0〜img.width) を度数の位置 (0〜255) へ移す
            let which = Int(map(Float(i), 0, Float(img.width), 0, 255))
            // 度数を、絵の下端と上端のあいだの位置へ移す
            let y = map(Float(hist[which]), 0, Float(histMax), Float(img.height), 0)
            line(Float(i), Float(img.height), Float(i), y)
        }
    }
}
