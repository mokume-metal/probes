// repro: mokume#未起票
//
import Foundation
import mokume

@MainActor
enum SvgWidthOnly {
    /// loadShape で読んだ SVG を 100×100 の黒地に置き、画素を返すための舞台 (このファイルだけで閉じる)。
    @MainActor
    final class Stage: Sketch {
        nonisolated(unsafe) static var path = ""
        nonisolated(unsafe) static var size = 100
        var settings: SketchSettings { SketchSettings(width: Self.size, height: Self.size, title: "SvgWidthOnly") }
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
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("SvgWidthOnly-\(UUID().uuidString).svg")
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
        // viewBox は 10×20 (縦長 1:2)、width だけ 50 と書いた根。width と縦横比から高さは 100 になり、
        // 赤い矩形 (viewBox いっぱい) は 50×100 = 5000 画素を覆うはず (ブラウザの <img>・resvg・librsvg の大きさの決め方)。
        let widthOnly = try picture(#"<svg xmlns="http://www.w3.org/2000/svg" width="50" viewBox="0 0 10 20"><rect width="10" height="20" fill="red"/></svg>"#)
        // 陰性対照: width と height を両方書けば 50×100 に写る
        let both = try picture(#"<svg xmlns="http://www.w3.org/2000/svg" width="50" height="100" viewBox="0 0 10 20"><rect width="10" height="20" fill="red"/></svg>"#)
        // height だけでも同じ
        let heightOnly = try picture(#"<svg xmlns="http://www.w3.org/2000/svg" height="50" viewBox="0 0 20 10"><rect width="20" height="10" fill="red"/></svg>"#)
        let (w, b, h) = (lit(widthOnly), lit(both), lit(heightOnly))
        guard b == 5000 else { return "control broke: width+height covered \(b) px, expected 5000" }
        if w == 5000 && h == 5000 { return nil }
        return "width only (50, viewBox 10x20) covered \(w) px and height only (50, viewBox 20x10) covered \(h) px; expected 5000 each (same as width+height = \(b) px). The missing side falls back to the viewBox size, so the drawing stays at 1x and is only shifted"
    }
}
