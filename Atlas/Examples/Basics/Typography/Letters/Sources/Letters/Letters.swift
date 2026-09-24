import mokume

/// Processing の [Letters](https://processing.org/examples/letters/) を 1 行ずつ移したもの。
///
/// **台帳は `blocked` と言った。半分だけ — 絵は出る。**
/// `createFont("SourceCodePro-Regular.ttf", 24)` の**書体ファイルを読む口が無く**、
/// mokume の `textFont` はシステムに入っている書体の名前しか取らない。同梱の .ttf を
/// 使うという原典の主題は消えるが、字は組めるので絵は出る。
/// `PFont.list()` (使える書体を並べる) も無い。
///
/// **字形は環境で変わる**ので、原典と画素では比べられない。
final class Letters: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Letters")

    func setup() {
        background(0)
        // 原典はここで `printArray(PFont.list())` と
        // `f = createFont("SourceCodePro-Regular.ttf", 24)` を呼ぶ。**どちらも書けない**
        textFont("Menlo")
        textSize(24)
        textAlign(.center, .center)
    }

    func draw() {
        background(0)
        // 左と上の余白
        let margin: Float = 10
        translate(margin * 4, margin * 4)
        let gap: Float = 46
        var counter = 35

        for y in stride(from: Float(0), to: height - gap, by: gap) {
            for x in stride(from: Float(0), to: width - gap, by: gap) {
                let letter = String(UnicodeScalar(UInt8(counter)))

                if ["A", "E", "I", "O", "U"].contains(letter) {
                    fill(255, 204, 0)
                } else {
                    fill(255)
                }
                text(letter, x, y)
                counter += 1
            }
        }
    }
}
