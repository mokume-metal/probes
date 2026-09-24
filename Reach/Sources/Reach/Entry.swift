import mokume

/// 手本の口 1 つを mokume で書いたときの判定。**Atlas の台帳と同じ 7 区分**
/// (`Atlas/README.md`「判定の意味」)。上の 4 つは届き、下の 3 つが穴。
enum Verdict: String, CaseIterable {
    /// mokume に同名・同じ引数の形がある。
    case same
    /// 口はあるが別名・別の形 (`CENTER` → `ShapeMode.center`)。
    case renamed
    /// mokume ではなく Swift・Foundation の語彙で当たる (`PI` → `Float.pi`)。
    case host
    /// 手本にはあるが mokume では要らない (`updatePixels` — 画素は書いた時点で届く)。
    case drop
    /// 面に無いが、面の外に書けば済む。書いたものは `Support.swift` に集める。
    case write
    /// 書けるが歪む。手本の形が保てない。
    case bend
    /// 口が無い。
    case none

    /// 届くか。
    var reaches: Bool { self == .same || self == .renamed || self == .host || self == .drop }
}

/// p5.js のリファレンスの区分に揃えた並び。
enum Section: String, CaseIterable {
    case structure = "構造と環境"
    case shape = "2D の形"
    case color = "色"
    case transform = "変換"
    case image = "画像と画素"
    case type = "字"
    case math = "数"
    case input = "入力"
    case solid = "3D"
    case data = "データと部品"
}

/// タイルに何を描くか。
enum Tile {
    /// 口を通した絵。**下地以外の画素を置くはず**で、テストはそれを確かめる。
    case picture(@MainActor (Canvas, Reach) -> Void)
    /// 絵にならない口 (入力・時計・実行の制御)。値を字で刷る。**コンパイルが通ること自体が
    /// 「口がある」の証明**で、呼ぶと走りが変わるもの (`noLoop`) は `unreached` で包んで呼ばない。
    case value(@MainActor (Reach) -> String)
    /// 口が無い。**書けないものを書けたように作り替えない** (Atlas と同じ態度) — 判定と注だけを刷る。
    case absent
}

/// 手本の口 1 つ。
struct Entry {
    let section: Section
    /// 手本 (p5.js / Processing) の綴り。テストと README が名指しする鍵を兼ねる。
    let reference: String
    let verdict: Verdict
    /// mokume での書き方。無ければ `—`。
    let mokume: String
    /// 判定の理由。`bend` / `none` では何が歪むか・何が無いかを書く。
    var note: String = ""
    /// 関わる mokume の Issue (`mokume#1323`)。
    var issue: String? = nil
    let tile: Tile
}

/// 本体を書くが呼ばない。**型が合うこと (口があること) だけを確かめる。**
@inline(never)
func unreached(_ body: () -> Void) {
    if Reach.neverTrue { body() }
}
