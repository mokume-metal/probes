import mokume

extension Scenes {
    static func named(_ key: ChurnKey) -> ChurnCase {
        all.first { $0.key == key }!
    }

    /// 履歴の関係の前置きの枚数と、その後に比べる枚数。
    static let prelude = 8
    static let settledFrames = 6

    /// 数の関係で、フレームごとに足す数。**経路が数で切り替わる境目を往復する** — 平面の畳みは
    /// 1↔2 個、半透明の立体の裏 → 表をまとめて描く経路は 3↔4 個、置き場所の列の初期容量は 256、
    /// 1 列の上限は 8192 (mokume v0.22.0 の `Canvas.swift`・`SolidSweep.swift`)。
    static let counts = [0, 1, 2, 3, 4, 5, 3, 1, 16, 17, 255, 256, 257, 2, 0]
    static let capCounts = [0, 8190, 8191, 8192, 8193, 8194, 16384, 16385, 1, 8193, 0]

    static let all: [ChurnCase] = [
        // MARK: 履歴

        // 判定の陰性対照: 前置きがどちらも空なら、同じ絵が出る。舞台と比べ方の押さえ
        ChurnCase(
            .historyBlank, .history, "前置きがどちらも空 (陰性対照)", frames: prelude + settledFrames,
            compared: (prelude + 1)...(prelude + settledFrames), prepare: prepareAssets
        ) { s in
            if s.frame <= prelude { s.background(0) } else { settled(s, t: s.frame - prelude - 1) }
        },
        // 前置きで 2D の物体を増やし・消し・動かす。その後の絵は前置きに引きずられない
        ChurnCase(
            .historyMixed2D, .history, "前置きの 2D の増減 → 同じ場面", frames: prelude + settledFrames,
            compared: (prelude + 1)...(prelude + settledFrames),
            prepare: { s in
                prepareAssets(s)
                s.bag.scenes = scenes(seed: s.seed, frames: prelude, kinds: Thing.Kind.allCases, limit: 40)
            }
        ) { s in
            if s.frame <= prelude {
                if s.suspect { draw2D(s, s.bag.scenes[s.frame - 1]) } else { s.background(0) }
            } else {
                settled(s, t: s.frame - prelude - 1)
            }
        },
        // 前置きで、描き場所・粒の群を作っては捨て、文字の大きさ・影・断片を変える
        ChurnCase(
            .historyParticles, .history, "前置きのがらくた (描き場所・粒・文字・影・断片) → 同じ場面",
            frames: prelude + settledFrames, compared: (prelude + 1)...(prelude + settledFrames),
            prepare: { s in
                prepareAssets(s)
                s.bag.scenes = scenes(seed: s.seed, frames: prelude, kinds: Thing.Kind.allCases, limit: 40)
                s.bag.random = SplitMix(seed: s.seed &+ 99)
            }
        ) { s in
            if s.frame <= prelude {
                if s.suspect { junk(s) } else { s.background(0) }
            } else {
                settled(s, t: s.frame - prelude - 1)
            }
        },
        // 前置きで 3D の物体を影つきで増減させる。その後の 3D の場面の影は前置きに引きずられない
        ChurnCase(
            .history3DShadows, .history, "前置きの 3D の増減 (影) → 同じ 3D の場面", frames: prelude + settledFrames,
            compared: (prelude + 1)...(prelude + settledFrames),
            prepare: { s in
                s.bag.scenes = scenes(seed: s.seed, frames: prelude + settledFrames, kinds: [.rect], limit: 30)
            }
        ) { s in
            if s.frame <= prelude, !s.suspect {
                s.background(0)
            } else {
                // 前置きの後は、どちらも同じ場面 (前置きの最後の場面) を描く
                let index = s.frame <= prelude ? s.frame - 1 : prelude - 1
                draw3D(s, s.bag.scenes[index], shadows: true)
            }
        },

        // MARK: runtime の積み重ね

        // 増減と移動を 1 つの runtime で回した k 枚目 = 同じ場面を新しい runtime の 1 枚目に描いたもの
        ChurnCase(
            .fresh2D, .fresh, "2D の 14 種を増減・移動した k 枚目 = 新しい runtime の 1 枚目", frames: 16,
            prepare: { s in
                prepareAssets(s)
                s.bag.scenes = scenes(seed: s.seed, frames: 16, kinds: Thing.Kind.allCases, limit: 40)
            }
        ) { s in
            draw2D(s, s.bag.scenes[s.frame - 1])
        },
        ChurnCase(
            .fresh3D, .fresh, "3D (光・影・半透明) を増減・移動した k 枚目 = 新しい runtime の 1 枚目", frames: 12,
            prepare: { s in s.bag.scenes = scenes(seed: s.seed, frames: 12, kinds: [.rect], limit: 30) }
        ) { s in
            draw3D(s, s.bag.scenes[s.frame - 1], shadows: true)
        },

        // MARK: 数

        // 左の 1 つ (A) の絵は、右に足す数に依らない。輪郭つき・輪郭なしの距離関数の経路
        ChurnCase(
            .localityForms, .locality, "右に足す数を往復させても、左の楕円は変わらない", frames: counts.count,
            columns: 0..<100
        ) { s in
            s.background(10)
            s.fill(230, 120, 40)
            s.stroke(255)
            s.strokeWeight(3)
            locality(s, counts[s.frame - 1]) { x, y in
                s.push()
                s.translate(x, y)
                s.rotate(0.37)
                s.ellipse(0, 0, 40, 26)
                s.pop()
            }
        },
        // 断片か貼る絵が効いている間は、同じ形の 2 つ目から平面の畳み (instancing) へ切り替わる。
        // 1 つ目は CPU で、2 つ目からは頂点関数で変換するので、1 つ目の絵が変わりうる所
        ChurnCase(
            .localityFolding, .locality, "断片・貼る絵の形を 1↔2 個で往復させても、左の形は変わらない",
            frames: counts.count, columns: 0..<100, prepare: prepareAssets
        ) { s in
            s.background(10)
            s.fill(255)
            s.stroke(255, 0, 0)
            s.strokeWeight(2)
            s.texture(s.bag.image)
            locality(s, counts[s.frame - 1]) { x, y in
                s.push()
                s.translate(x + 0.3, y + 0.7)
                s.rotate(0.37)
                s.ellipse(0, 0, 40, 26)
                s.pop()
            }
            s.noTexture()
            s.noStroke()
            s.fill(230, 120, 40)
            s.shader(s.bag.paint)
            locality(s, counts[s.frame - 1], at: 150) { x, y in
                s.push()
                s.translate(x + 0.3, y + 0.7)
                s.rotate(0.37)
                s.rect(-20, -13, 40, 26)
                s.pop()
            }
            s.resetShader()
        },
        // 1 列の置き場所の上限 8192 をまたいで往復させる。A を先にも後にも置く
        ChurnCase(
            .localityInstanceCap, .locality, "右に 8192 個前後を足しても、左の矩形と箱は変わらない",
            frames: capCounts.count, columns: 0..<120
        ) { s in
            s.background(10)
            s.noStroke()
            let n = s.suspect ? capCounts[s.frame - 1] : 0
            s.fill(230, 120, 40)
            s.push()
            s.translate(50, 50)
            s.rotate(0.3)
            s.rect(-20, -13, 40, 26)
            s.pop()
            s.fill(60, 200, 90)
            for i in 0..<n {
                let (x, y) = far(i)
                s.rect(x, y, 1.5, 1.5)
            }
            s.lights()
            for i in 0..<n {
                let (x, y) = far(i)
                s.push()
                s.translate(x, y, 0)
                s.box(1.5)
                s.pop()
            }
            s.fill(230, 120, 40)
            s.push()
            s.translate(50, 140, 0)
            s.rotateY(0.6)
            s.rotateX(0.4)
            s.box(30)
            s.pop()
        },
        // 半透明の立体は、置き場所の数で裏 → 表をまとめて描く経路へ切り替わる (箱なら 3↔4 個)。
        // 鏡映した箱・球も混ぜる
        ChurnCase(
            .localitySweep, .locality, "半透明の箱・鏡映・球を 3↔4 個で往復させても、左は変わらない",
            frames: counts.count, columns: 0..<100
        ) { s in
            s.background(10)
            s.lights()
            s.noStroke()
            s.fill(200, 80, 40, 128)
            locality(s, counts[s.frame - 1], at: 40) { x, y in
                s.push()
                s.translate(x, y, 0)
                s.rotateY(0.6)
                s.rotateX(0.4)
                s.box(30)
                s.pop()
            }
            locality(s, counts[s.frame - 1], at: 100) { x, y in
                s.push()
                s.translate(x, y, 0)
                s.scale(-1, 1, 1)
                s.rotateY(0.6)
                s.rotateX(0.4)
                s.box(30)
                s.pop()
            }
            s.fill(60, 160, 220, 128)
            locality(s, counts[s.frame - 1], at: 160) { x, y in
                s.push()
                s.translate(x, y, 0)
                s.sphere(16)
                s.pop()
            }
        },
        // 影を落とす物体の数を変えても、左の箱と床の影は変わらない
        ChurnCase(
            .localityShadow, .locality, "影を落とす箱の数を往復させても、左の箱と影は変わらない",
            frames: counts.count, columns: 0..<100
        ) { s in
            s.background(10)
            s.lights()
            s.shadows(true)
            s.noStroke()
            s.fill(180)
            s.push()
            s.translate(50, 100, -40)
            s.box(90, 190, 4)
            s.pop()
            s.fill(200, 80, 40)
            locality(s, counts[s.frame - 1]) { x, y in
                s.push()
                s.translate(x, y, 0)
                s.rotateY(0.6)
                s.rotateX(0.4)
                s.box(30)
                s.pop()
            }
        },

        // MARK: 置き方

        // 2 つの領域 (rect = 距離関数・triangle = 平面) を持つ形を、重なる 3 か所へまとめて置く =
        // 1 か所ずつ置く。置き場所は毎フレーム動き、重なり方が変わる
        ChurnCase(.shapeAtRegions, .equivalence, "2 領域の形を shape(at:) でまとめて置く = 1 つずつ置く", frames: 6) { s in
            s.background(0)
            spread(s, regions(s), placements(s.frame))
        },
        // 同じ形を、置き場所ごとの半透明の色で置く
        ChurnCase(
            .shapeAtTranslucent, .equivalence, "置き場所の色を半透明にして、まとめて置く = 1 つずつ置く", frames: 6
        ) { s in
            s.background(0)
            let shape = s.createShape {
                s.noStroke()
                s.fill(255)
                s.rect(0, 0, 40, 40)
                s.triangle(0, 0, 40, 0, 0, 40)
            }
            let colors = [
                LinearRGBA(straightRed: 1, green: 0, blue: 0, alpha: 0.5),
                LinearRGBA(straightRed: 0, green: 0, blue: 1, alpha: 0.5),
                LinearRGBA(straightRed: 0, green: 1, blue: 0, alpha: 0.5),
            ]
            spread(s, shape, placements(s.frame).enumerated().map { i, p in
                Placement(x: p.x, y: p.y, fill: colors[i % colors.count])
            })
        },
        // 陰性対照: 領域が 1 つ (三角形 2 つ) なら、まとめて置いても 1 つずつと同じ
        ChurnCase(
            .shapeAtSingleRegion, .equivalence, "1 領域の形をまとめて置く = 1 つずつ置く (陰性対照)", frames: 6
        ) { s in
            s.background(0)
            let shape = s.createShape {
                s.noStroke()
                s.fill(255, 0, 0)
                s.triangle(0, 40, 40, 40, 40, 0)
                s.fill(0, 0, 255)
                s.triangle(0, 0, 40, 0, 0, 40)
            }
            spread(s, shape, placements(s.frame))
        },
        // 陰性対照: 3D の立体は奥行きで前後が決まるので、まとめて置いても 1 つずつと同じ
        ChurnCase(.shapeAt3D, .equivalence, "3D の半透明の箱と球をまとめて置く = 1 つずつ置く (陰性対照)", frames: 6) { s in
            s.background(0)
            s.lights()
            let shape = s.createShape {
                s.noStroke()
                s.fill(255, 0, 0, 128)
                s.box(30)
                s.fill(0, 0, 255, 128)
                s.translate(20, 0, 0)
                s.sphere(15)
            }
            spread(s, shape, placements(s.frame).map { Placement(x: $0.x + 20, y: $0.y + 20) })
        },
        // 物体ごとに描き場所を持たせ、同じフレームで 1 つが死んで 1 つが生まれる。生まれた描き場所を置いて
        // から描き換えても、置いた所には置いた時点の絵が出る = 2 つの描き場所に分けて描く
        ChurnCase(
            .graphicsReuse, .equivalence, "捨てた描き場所の後に作った描き場所を、置いてから描き換える", frames: 4
        ) { s in
            layers(s, keepAlive: false)
        },
        // 陰性対照: 死んだ描き場所を生かしたままなら、置いた時点の絵が出る
        ChurnCase(
            .graphicsKeptAlive, .equivalence, "前の描き場所を生かしたまま、置いてから描き換える (陰性対照)", frames: 4
        ) { s in
            layers(s, keepAlive: true)
        },
    ]

    /// A を左に 1 つ置き、`suspect` だけ右に `n` 個足す。`at` は A の縦の位置。
    @MainActor static func locality(_ s: Stir, _ n: Int, at y: Float = 100, _ draw: (Float, Float) -> Void) {
        draw(50, y)
        guard s.suspect else { return }
        for i in 0..<n {
            draw(140 + Float(i % 5) * 9, 10 + Float((i / 5) % 20) * 9)
        }
    }

    /// 2 つの領域を持つ形。
    @MainActor static func regions(_ s: Stir) -> Shape {
        s.createShape {
            s.noStroke()
            s.fill(255, 0, 0)
            s.rect(0, 0, 40, 40)
            s.fill(0, 0, 255)
            s.triangle(0, 0, 40, 0, 0, 40)
        }
    }

    /// 重なる 3 つの置き場所。フレームごとに 1 つ目が右へ動き、重なり方が変わる。
    static func placements(_ frame: Int) -> [Placement] {
        [
            Placement(x: 80 + Float(frame) * 6, y: 70),
            Placement(x: 60, y: 80),
            Placement(x: 75, y: 95 - Float(frame) * 3),
        ]
    }

    /// `suspect` はまとめて、`reference` は 1 つずつ置く。
    @MainActor static func spread(_ s: Stir, _ shape: Shape, _ placements: [Placement]) {
        if s.suspect {
            s.shape(shape, at: placements)
        } else {
            for placement in placements { s.shape(shape, at: [placement]) }
        }
    }

    /// 描き場所の入れ替わり。左上に死ぬ描き場所 (赤) を置き、生まれた描き場所を緑で描いて置いてから青へ
    /// 描き換え、もう 1 度置く。**置いた時点の絵が出る約束**なので、1 度目の所は緑、2 度目の所は青になる。
    /// `reference` は緑と青を別の描き場所に描く。
    ///
    /// `suspect` は死んだ描き場所の `ObjectIdentifier` を新しい描き場所が引き継ぐまで作り直す (アドレスの
    /// 使い回しに頼る)。引き継いだ回数は `reused` に数える。`keepAlive` なら死んだ描き場所を生かしておくので、
    /// 引き継ぎは起きない。
    @MainActor static func layers(_ s: Stir, keepAlive: Bool) {
        s.background(0)
        let shift = Float(s.frame - 1) * 10
        var dying: Canvas? = try! s.createGraphics(40, 40)
        dying!.beginDraw()
        dying!.background(255, 0, 0)
        dying!.endDraw()
        s.image(dying!, 10 + shift, 10)
        let gone = ObjectIdentifier(dying!)
        let kept = keepAlive ? dying : nil
        dying = nil
        if s.suspect {
            var born = try! s.createGraphics(40, 40)
            var held: [Canvas] = []
            while !keepAlive, ObjectIdentifier(born) != gone, held.count < 256 {
                held.append(born)
                born = try! s.createGraphics(40, 40)
            }
            if ObjectIdentifier(born) == gone { s.reused += 1 }
            born.beginDraw()
            born.background(0, 255, 0)
            born.endDraw()
            s.image(born, 60 + shift, 60)
            born.beginDraw()
            born.background(0, 0, 255)
            born.endDraw()
            s.image(born, 60 + shift, 120)
        } else {
            for (color, y) in [((Float(0), Float(255), Float(0)), Float(60)), ((0, 0, 255), 120)] {
                let layer = try! s.createGraphics(40, 40)
                layer.beginDraw()
                layer.background(color.0, color.1, color.2)
                layer.endDraw()
                s.image(layer, 60 + shift, y)
            }
        }
        withExtendedLifetime(kept) {}
    }
}
