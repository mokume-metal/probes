// repro: mokume#2334
//
import Foundation
import mokume

@MainActor
enum SvgUniversalSelector {
    /// loadShape で読んだ SVG を 100×100 の黒地に置き、画素を返すための舞台 (このファイルだけで閉じる)。
    @MainActor
    final class Stage: Sketch {
        nonisolated(unsafe) static var path = ""
        nonisolated(unsafe) static var size = 100
        var settings: SketchSettings { SketchSettings(width: Self.size, height: Self.size, title: "SvgUniversalSelector") }
        var shapeRead: Shape?
        init() {}
        func setup() { shapeRead = try? loadShape(Self.path) }
        func draw() {
            background(0)
            if let shapeRead { shape(shapeRead, 0, 0) }
        }
    }

    /// SVG の文字を一時ファイルに書いて loadShape で読み、2 フレーム回した絵を返す。
    @MainActor
    private static func picture(_ svg: String) throws -> PixelBuffer {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SvgUniversalSelector-\(UUID().uuidString).svg")
        try svg.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }
        Stage.path = url.path
        let runtime = try SketchRuntime(sketch: Stage(), gpu: try RenderDevice())
        for _ in 0..<2 { try runtime.advance() }
        let pixels = try runtime.target.readPixels()
        runtime.closePlugins()
        return pixels
    }

    /// 赤の成分が 0.1 を越える画素の数。
    @MainActor
    private static func lit(_ p: PixelBuffer) -> Int {
        var n = 0
        for y in 0..<p.height { for x in 0..<p.width where p[x, y].red > 0.1 { n += 1 } }
        return n
    }

    @MainActor
    static func reproduce() throws -> String? {
        // CSS では要素名のセレクタ (詳細度 0,0,1) は * (0,0,0) より強い。書いた順に依らず rect は赤のはず
        let starAfter = try picture(#"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><style>rect{fill:red} *{fill:blue}</style><rect width="50" height="50"/></svg>"#)
        // 陰性対照: * を先に書けば、順でも詳細度でも赤
        let starBefore = try picture(#"<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><style>*{fill:blue} rect{fill:red}</style><rect width="50" height="50"/></svg>"#)
        let after = starAfter[20, 20], before = starBefore[20, 20]
        guard before.red > 0.5, before.blue < 0.1 else { return "control broke: *-first gave r=\(before.red) b=\(before.blue)" }
        if after.red > 0.5 && after.blue < 0.1 { return nil }
        return "rect{fill:red} *{fill:blue}: the rect is painted r=\(after.red) g=\(after.green) b=\(after.blue) (blue); CSS specificity says the type selector wins over *, so it should be red like the *-first control (r=\(before.red))"
    }
}
