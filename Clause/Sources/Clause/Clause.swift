import mokume

/// mokume の **DocC・ADR が書いた約束の 1 文**を、境界と陰性対照で突く物差し。
///
/// **作品ではない。** 他の物差しが同じ絵になるはずの 2 経路を画素で比べるのに対し、Clause は約束の
/// 文 (「1 つの datagram が 1 つのメッセージになる」「`1e400` のように Double に収まらない数は読めない」…)
/// を 1 つ選び、その文が言う値・ファイル・ポート・知らせの行をそのまま確かめる。
///
/// 数で押さえるのは `Tests/ClauseTests` の側で、窓は突いた約束の一覧を出すだけである (README「何をしているか」)。
@main
final class Clause: Sketch {
    var settings = SketchSettings(width: 760, height: 420, title: "clause — mokume v0.22.1")

    /// 突いた口の群と、その群で約束を破っていた件数 (README の表と揃える)。
    static let groups: [(String, Int)] = [
        ("通信 (UDPPort・OSCPort)", 3),
        ("時刻 (jumpTime・pauseTime)", 2),
        ("文字と表 (loadTable・saveTable・loadStrings)", 2),
        ("JSON・XML (loadJSONObject・loadXML)", 4),
        ("SVG (loadShape)", 2),
        ("立体 (loadModel の STL・OBJ)", 5),
    ]

    func draw() {
        background(16)
        fill(235)
        textSize(20)
        text("Clause — 約束の 1 文を、境界と陰性対照で突く", 24, 40)
        textSize(15)
        for (row, group) in Self.groups.enumerated() {
            text("\(group.0): 破れ \(group.1) 件", 24, 90 + Float(row) * 32)
        }
        fill(150)
        textSize(13)
        text("確かめるのは swift test (Tests/ClauseTests)。窓は一覧を出すだけ", 24, 390)
    }
}
