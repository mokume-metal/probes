@testable import Lattice

extension Relation {
    /// 変換せずに描いた絵から、変換して描いたはずの絵を画素の置き換えで作る。
    ///
    /// 軸は面の中心 c。**塗りは画素の角、線は画素の中心を軸に取る** (mokume ADR-0039
    /// 決定 2: 線だけを画面で +0.5 画素寄せる)。画素 i の中心 i + 0.5 を軸 a で折ると
    /// 2a − 1 − i なので、`doubled` = 2a は塗りで 2c、線で 2c + 1 になる。
    ///
    /// `rotate(+90°)` は y が下向きの画面で時計回りなので、出 (i, j) には入 (j, 2a − 1 − i)
    /// が来る。
    func expected(from picture: Picture, center c: Int, stroke: Bool) -> [SIMD4<Float>?] {
        let a2 = 2 * c + (stroke ? 1 : 0)
        switch self {
        case .mirrorX: return picture.mapped { (a2 - 1 - $0, $1) }
        case .mirrorY: return picture.mapped { ($0, a2 - 1 - $1) }
        case .rotate90: return picture.mapped { (i, j) in (j, a2 - 1 - i) }
        case .rotate180: return picture.mapped { (i, j) in (a2 - 1 - i, a2 - 1 - j) }
        case .rotate270: return picture.mapped { (i, j) in (a2 - 1 - j, i) }
        case .shift: return picture.mapped { (i, j) in (i - Self.offset.x, j - Self.offset.y) }
        }
    }
}
