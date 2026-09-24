import mokume

/// Processing の [Statements and Comments](https://processing.org/examples/statementscomments/) を 1 行ずつ移したもの。
///
/// **台帳は `clean` と言った。半分だけ当たっている。**
/// 原典は「文とは何か」を見せるために `size()` と `background()` の 2 文だけを書くが、
/// **mokume では `size()` が文ですらない** — 面の大きさは走り出す前に決まる
/// (`SketchSettings`) ので、原典の 2 文のうち 1 つは書く場所そのものが違う。
final class StatementsComments: Sketch {
    // size(640, 360) に当たるもの。**文ではなく設定**
    var settings = SketchSettings(width: 640, height: 360, title: "Statements and Comments")

    func setup() {
        // background は、表に出す面の色 (または灰色の値) を決める文
        background(204, 153, 0)
    }
}
