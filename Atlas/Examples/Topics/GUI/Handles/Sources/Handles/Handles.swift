import mokume

/// Processing の [Handles](https://processing.org/examples/handles/) を 1 行ずつ移したもの。
///
/// **台帳は `bend` と言い、`v0.5.0` では歪んでいた。`v0.6.0` で原典の形に戻った。**
/// 原典は `firstMousePress` — **押した最初の 1 フレームだけを真にする印**を
/// `mousePressed()` で立て、`mouseReleased()` で掴みを解く。出来事の口が無かった頃は
/// `isMousePressed` のポーリングから「押した瞬間」を作るしかなく、**前のフレームの値を
/// 自分で覚える**状態 (`wasPressed`) を 1 つ余分に持っていた
/// ([#723](https://github.com/mokume-metal/mokume/issues/723) — 閉じた)。
///
/// いまは原典と同じ 2 つのコールバックがそのまま書ける。
final class Handles: Sketch {
    var settings = SketchSettings(width: 640, height: 360, title: "Handles")

    private var handles: [Handle] = []
    private var firstMousePress = false

    final class Handle {
        let x: Float
        let y: Float
        var boxx: Float = 0
        var boxy: Float = 0
        var stretch: Float
        let size: Float
        var over = false
        var press = false
        var locked = false
        var otherslocked = false
        var others: [Handle] = []

        init(_ ix: Float, _ iy: Float, _ il: Float, _ isize: Float) {
            x = ix
            y = iy
            stretch = il
            size = isize
            boxx = x + stretch - size / 2
            boxy = y - size / 2
        }

        func update(on sketch: any Sketch, firstMousePress: Bool) {
            boxx = x + stretch
            boxy = y - size / 2
            otherslocked = others.contains { $0.locked }
            if otherslocked == false {
                over = overRect(on: sketch, boxx, boxy, size, size)
                if over && firstMousePress || locked {
                    press = true
                    locked = true
                } else {
                    press = false
                }
            }
            if press {
                stretch = min(max(sketch.mouseX - sketch.width / 2 - size / 2, 0),
                              sketch.width / 2 - size - 1)
            }
        }

        func releaseEvent() { locked = false }

        func display(on sketch: any Sketch) {
            sketch.line(x, y, x + stretch, y)
            sketch.fill(255)
            sketch.stroke(0)
            sketch.rect(boxx, boxy, size, size)
            if over || press {
                sketch.line(boxx, boxy, boxx + size, boxy + size)
                sketch.line(boxx, boxy + size, boxx + size, boxy)
            }
        }

        private func overRect(on sketch: any Sketch, _ x: Float, _ y: Float,
                              _ w: Float, _ h: Float) -> Bool {
            sketch.mouseX >= x && sketch.mouseX <= x + w
                && sketch.mouseY >= y && sketch.mouseY <= y + h
        }
    }

    func setup() {
        let num = Int(height) / 15
        let hsize: Float = 10
        handles = (0..<num).map {
            Handle(width / 2, 10 + Float($0) * 15, 50 - hsize / 2, 10)
        }
        for handle in handles { handle.others = handles }
    }

    func draw() {
        background(153)
        for handle in handles {
            handle.update(on: self, firstMousePress: firstMousePress)
            handle.display(on: self)
        }
        fill(0)
        rect(0, 0, width / 2, height)

        // 使い終えたら倒す。原典と同じ 1 行
        if firstMousePress {
            firstMousePress = false
        }
    }

    /// 原典の `void mousePressed()`。
    func mousePressed() {
        if !firstMousePress {
            firstMousePress = true
        }
    }

    /// 原典の `void mouseReleased()`。
    func mouseReleased() {
        for handle in handles { handle.releaseEvent() }
    }
}
