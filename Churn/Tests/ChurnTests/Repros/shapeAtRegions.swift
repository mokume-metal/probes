// repro: mokume#未起票
//
// 同じ形を `shape(_:at:)` で 2 か所へまとめて置いた絵は、1 か所ずつ置いた絵と同じになるはず
// (`Placement` の説明「1 ビットも変わらない」・`shape(_:at:)` の説明「1 つずつ置いたときと同じ絵」)。
//
// 形は 2 つの領域を持つ — `rect` は距離関数の経路、`triangle` は平面の経路に積まれる。置き場所 P1 = (120, 100) と
// P2 = (100, 100) は重なる。画素 (130, 125) は P1 からは (10, 25) で、矩形と三角形の両方の内側にある。P2 からは
// (30, 25) で、矩形の内側・三角形の外側にある。
//
// - 1 つずつ置く: 矩形@P1・三角形@P1・矩形@P2・三角形@P2 の順。最後に塗る矩形@P2 の赤が出る。
// - まとめて置く: 赤なら置き場所の順、青なら領域の順 (矩形@P1・矩形@P2・三角形@P1・三角形@P2) で描いている。
//
// **このファイルは mokume だけで閉じる** (docs/filing.md)。起票の本文にはこれをそのまま
// 貼り、probes の検査 (ReprosTests) も同じものを走らせる。

import mokume

enum ShapeAtRegions {
    /// 期待どおりなら `nil`、破れていればその様子を返す。
    static func reproduce() throws -> String? {
        let together = try render(loop: false)
        let oneByOne = try render(loop: true)
        var differing = 0
        for y in 0..<oneByOne.height {
            for x in 0..<oneByOne.width {
                let a = together[x, y]
                let b = oneByOne[x, y]
                if max(abs(a.red - b.red), abs(a.green - b.green), abs(a.blue - b.blue)) > 0.004 { differing += 1 }
            }
        }
        guard differing > 0 else { return nil }
        let a = together[130, 125]
        let b = oneByOne[130, 125]
        return "\(differing) 画素違う ((130, 125) の赤・青: まとめて \(a.red)・\(a.blue) / 1 つずつ \(b.red)・\(b.blue))"
    }

    /// 窓を出さずに 1 枚描いて、画素を読む。
    static func render(loop: Bool) throws -> PixelBuffer {
        let runtime = try SketchRuntime(sketch: Scene(loop: loop), gpu: RenderDevice())
        defer { runtime.closePlugins() }
        try runtime.advance()
        return try runtime.target.readPixels()
    }

    final class Scene: Sketch {
        var settings = SketchSettings(width: 200, height: 200, frameRate: 30, title: "repro")
        let loop: Bool
        var shape: Shape!
        init(loop: Bool) { self.loop = loop }
        convenience init() { self.init(loop: false) }

        func setup() {
            shape = createShape {
                noStroke()
                fill(255, 0, 0)
                rect(0, 0, 40, 40)
                fill(0, 0, 255)
                triangle(0, 0, 40, 0, 0, 40)
            }
        }

        func draw() {
            background(0)
            let placements = [Placement(x: 120, y: 100), Placement(x: 100, y: 100)]
            if loop {
                for placement in placements { shape(shape, at: [placement]) }
            } else {
                shape(shape, at: placements)
            }
        }
    }
}
