import Foundation
import mokume

extension Entries {
    static let input: [Entry] = [
        Entry(section: .input, reference: "mouseX / mouseY", verdict: .same, mokume: "mouseX / mouseY",
              tile: .value { r in "\(Int(r.mouseX)), \(Int(r.mouseY))" }),
        Entry(section: .input, reference: "pmouseX / pmouseY", verdict: .same, mokume: "pmouseX / pmouseY",
              tile: .value { r in "\(Int(r.pmouseX)), \(Int(r.pmouseY))" }),
        Entry(section: .input, reference: "mouseIsPressed", verdict: .renamed, mokume: "isMousePressed",
              note: "Processing の変数 mousePressed は関数と同名になり Swift では並べられない。p5 の mouseIsPressed でもない綴りになっている", issue: "mokume#1556",
              tile: .value { r in r.isMousePressed ? "pressed" : "up" }),
        Entry(section: .input, reference: "mouseButton === LEFT", verdict: .renamed, mokume: "mouseButton (Int)",
              note: "同じ名前で値の体系が違う。LEFT / RIGHT / CENTER ではなく番号 (0 = 主釦)", issue: "mokume#1555",
              tile: .value { r in "button \(r.mouseButton)" }),
        Entry(section: .input, reference: "mousePressed() / mouseReleased() / mouseClicked()", verdict: .same, mokume: "同名の関数を書く",
              note: "mouseMoved() も同名。v0.6.0 で入った (mokume#723)",
              tile: .value { _ in "events" }),
        Entry(section: .input, reference: "mouseDragged()", verdict: .renamed, mokume: "mouseDragged(deltaX:deltaY:)",
              note: "引数で動いた量を受ける",
              tile: .value { r in "drag \(Int(r.dragX))" }),
        Entry(section: .input, reference: "mouseWheel(event)", verdict: .renamed, mokume: "mouseWheel(deltaX:deltaY:)",
              tile: .value { r in "scroll \(Int(r.scrollY))" }),
        Entry(section: .input, reference: "doubleClicked()", verdict: .none, mokume: "—",
              note: "2 度押しを受ける口が無い。mouseClicked() の間隔を自分で測れば書ける",
              tile: .absent),
        Entry(section: .input, reference: "key / keyCode", verdict: .renamed, mokume: "key (String) / keyCode (Key?)",
              note: "keyCode は手本の数ではなく Key の値 (mokume ADR-0034)",
              tile: .value { r in "key \(r.key)" }),
        Entry(section: .input, reference: "keyIsDown(LEFT_ARROW)", verdict: .renamed, mokume: "isKeyDown(.arrowLeft)",
              note: "引数を Key で受けるのは mokume ADR-0034。語順が手本と違う理由は見当たらない", issue: "mokume#1556",
              tile: .value { r in r.isKeyDown(.arrowLeft) ? "←" : "-" }),
        Entry(section: .input, reference: "keyPressed() / keyReleased() / keyTyped()", verdict: .same, mokume: "同名の関数を書く",
              tile: .value { _ in "events" }),
        Entry(section: .input, reference: "keyIsPressed", verdict: .write, mokume: "keyPressed / keyReleased で数える",
              note: "何かのキーが押されているかを読む値が無い。Processing は変数の keyPressed",
              tile: .value { r in r.keysDown > 0 ? "key down" : "no key" }),
    ]

    static let data: [Entry] = [
        Entry(section: .data, reference: "loadStrings() / loadJSON()", verdict: .host, mokume: "String(contentsOf:) / JSONDecoder",
              note: "Foundation で読む。スケッチの置き場から読む口 (資材の場所) は mokume に無い",
              tile: .value { _ in
                  unreached { _ = try? String(contentsOfFile: "data.txt", encoding: .utf8) }
                  return "Foundation"
              }),
        Entry(section: .data, reference: "createSlider()", verdict: .renamed, mokume: "@Param",
              note: "DOM の部品ではなく、外から動かせる値として名乗る (mokume ADR-0013)",
              tile: .value { r in "\(r.params.count) params" }),
    ]
}
