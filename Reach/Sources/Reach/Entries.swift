import Foundation
import mokume

/// 並べる口の一覧。**窓もテストも README もここを正本にする。**
///
/// 選び方: p5.js のリファレンスの区分に沿って、入門書・授業でまず使う口を拾う。Processing と
/// p5.js で綴りが割れるものは p5.js の綴りを見出しにし、Processing の綴りを注に書く。
/// DOM・音・映像・通信は mokume の射程の外なので並べない (`Param` だけは部品の代わりとして並べる)。
enum Entries {
    static let all: [Entry] =
        structure + shape + colors + transform + images + type + math + input + solid + data

    /// タイルの一辺。
    static let s = Float(Reach.side)
    /// タイルの中心。
    static let m = s / 2
}
