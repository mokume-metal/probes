import mokume

/// Processing の [IntList Lottery](https://processing.org/examples/intlistlottery/) を 1 行ずつ移したもの。
///
/// **台帳は `out-of-scope` と言った (データ構造が主題)。絵は出る。**
/// `IntList` は Swift の `[Int]` で、`shuffle()` も `shuffled()` で当たる (`host`)。
/// `frameRate(30)` だけが走り出す前にしか決められない。
///
/// 乱数で並べ替えるので **画素では比べられない。**
final class IntListLottery: Sketch {
    var settings = SketchSettings(width: 640, height: 360, frameRate: 30, title: "IntList Lottery")

    private var lottery: [Int] = []
    private var results: [Int] = []
    private var ticket: [Int] = []

    func setup() {
        // 原典はここで `frameRate(30)` を呼ぶ。settings へ移した
        lottery = Array(0..<20)
        // 引いた 5 つを ticket へ
        for _ in 0..<5 {
            ticket.append(lottery[Int(random(Float(lottery.count)))])
        }
    }

    func draw() {
        background(51)

        // 並びをでたらめに混ぜる (原典は `lottery.shuffle()`)
        lottery.shuffle()

        showList(lottery, 16, 48)
        showList(results, 16, 100)
        showList(ticket, 16, 140)

        // 引いた番号が ticket と合っているか
        for i in results.indices where i < ticket.count {
            if results[i] == ticket[i] {
                fill(0, 255, 0, 100)
            } else {
                fill(255, 0, 0, 100)
            }
            ellipse(16 + Float(i) * 32, 140, 24, 24)
        }

        // 30 フレームに 1 度、新しい番号を引く
        if frameCount % 30 == 0 {
            if results.count < 5 {
                results.append(lottery.removeFirst())
            } else {
                lottery.append(contentsOf: results)
                results.removeAll()
            }
        }
    }

    private func showList(_ list: [Int], _ x: Float, _ y: Float) {
        for (i, val) in list.enumerated() {
            stroke(255)
            noFill()
            ellipse(x + Float(i) * 32, y, 24, 24)
            textAlign(.center)
            fill(255)
            text("\(val)", x + Float(i) * 32, y + 6)
        }
    }
}
