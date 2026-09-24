import mokume
import Support

/// Processing の [Load and Display an OBJ Shape](https://processing.org/examples/loaddisplayobj/) を 1 行ずつ移したもの。
///
/// **台帳は「絵が出せない」と言った。外れている。**
/// 判定の根拠は `loadShape` に口が無いことだったが、**OBJ に限れば `loadModel` がある** —
/// `loadShape` は SVG と OBJ の 2 つを 1 つの名前で受ける Processing 側の都合で、
/// mokume はそこを `loadShape` / `loadModel` に分けている。`shape(rocket)` は
/// `model(rocket)` へ名前が変わる。
///
/// **台帳を直す根拠がこれである** — 語彙の名前 1 つに判定を 1 つ持たせている限り、
/// 「同じ名前で 2 つのものを読む」語彙は正しく測れない。
final class LoadDisplayOBJ: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Load and Display OBJ")

    private var rocket: Model?
    private var ry: Float = 0

    func setup() {
        // 原典は `loadShape("rocket.obj")`。**立体は loadModel が受ける**
        rocket = try? loadModel(asset("Basics/Shape/LoadDisplayOBJ", "rocket.obj"))
    }

    func draw() {
        background(0)
        lights()

        translate(width / 2, height / 2 + 100, -200)
        rotateZ(Float.pi)
        rotateY(ry)
        if let rocket { model(rocket) }   // 原典は `shape(rocket)`

        ry += 0.02
    }
}
