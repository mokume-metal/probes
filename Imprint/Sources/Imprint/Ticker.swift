import mokume

/// 各フレームに**フレーム番号を 2 値のブロックで焼く**スケッチ。
///
/// 書き出したファイル (PNG・連番・動画) から、そのフレームが何枚目かを読み戻すために
/// ある。番号は左上の横 1 列、`Stamp.bits` 個の升に、1 なら白 (255)・0 なら黒 (0) で
/// 置く。**灰色の両端だけを使う**ので、次のものに読みが左右されない。
///
/// - 符号化の誤差 (ProRes 4444 で最大 2 階調)
/// - 色空間の刻印 (灰色は原色の取り方によらない。mokume#911)
///
/// 番号の下には動く円を描く。フレームごとに絵が違うことを、番号とは別の画素でも示すため
/// である。
///
/// `script` は描き終えた後に呼ぶ。検査はそこで `save` / `beginRecord` / `endRecord` を
/// 呼ぶ。
final class Ticker: Sketch {
    var settings: SketchSettings
    let script: (Ticker) -> Void

    init(width: Int = Stamp.width, height: Int = 90, frameRate: Int = 60, script: @escaping (Ticker) -> Void = { _ in }) {
        settings = SketchSettings(width: width, height: height, frameRate: frameRate, title: "imprint")
        self.script = script
    }
    convenience init() { self.init() { _ in } }

    func draw() {
        background(40)
        noStroke()
        fill(240, 140, 40)
        circle(Float(frameCount % 60) * 3, Float(settings.height) * 0.65, 24)
        Stamp.draw(frameCount, on: self)
        script(self)
    }
}

/// フレーム番号を焼く升の並び。焼き方と読み方を 1 か所に置く。
enum Stamp {
    /// 焼く桁 (2 進)。65535 枚まで読める。
    static let bits = 16
    /// 升の一辺 (画素)。縁の滑らかさが升の中心まで届かない大きさにする。
    static let cell = 8
    /// 焼くのに要る幅。スケッチはこれ以上の幅にする。
    static let width = bits * cell + 32

    static func draw(_ number: Int, on s: some Sketch) {
        s.noStroke()
        for bit in 0..<bits {
            s.fill(number >> bit & 1 == 1 ? 255 : 0)
            s.rect(Float(bit * cell), 0, Float(cell), Float(cell))
        }
    }

    /// 並び (RGBA または BGRA、1 画素 4 バイト、行の間隔 `stride`) から番号を読む。
    /// 升の中心の 1 成分 (灰色なのでどれでもよい) を 128 で 2 値にする。
    static func read(_ bytes: [UInt8], stride: Int) -> Int {
        var number = 0
        for bit in 0..<bits {
            let x = bit * cell + cell / 2
            let y = cell / 2
            if bytes[y * stride + x * 4 + 1] >= 128 { number |= 1 << bit }
        }
        return number
    }
}
