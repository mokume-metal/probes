# Probe — mokume v0.11.0 の継ぎ目を突く

**作品ではなく物差しである。** Atlas が「原典の語彙のどこが欠けているか」を数えるのに対し、
Probe は「**約束されていることが、期待どおりに出るか**」を 1 件ずつ突く。mokume `v0.11.0` の
ソースを読んでバグの当たりを付け、その当たりを実際に描いて確かめた記録である。

## 何をしているか

**候補 1 件を、同じ絵になるはずの 2 つの経路で描く。**

- **左 (`suspect`)** は、疑っている口を通す。
- **右 (`reference`)** は、同じ結果を素朴な口で作る。
  - 例: 鏡映した箱 ↔ 逆に回した箱。
  - 例: 楕円の `arc` ↔ 媒介変数の角で点を並べた多角形。

左右が食い違えば、どちらかが約束を破っている。

| 確かめ方 | 何を通るか | 何で見るか |
| --- | --- | --- |
| `mokume run .` | 窓の経路。タイルごとに `createGraphics` の面を持つ | 目で見る (12 枚のタイルが並ぶ) |
| `swift test` | 窓を出さない経路。`SketchRuntime` を直に組み、本体の面へ描く | 画素を読んで数で比べる |

**時計はフレーム番号から導かれる** (`SketchRuntime` の既定) ので、テストは同じ機械なら
毎回同じ絵を読む。

**2 つの経路で同じ食い違いが出た。** 窓の絵と、テストが読んだ画素とで、破れているところが
すべて一致している。

候補の定義は [`Sources/Probe/Probes.swift`](Sources/Probe/Probes.swift) に 1 か所だけある。
窓もテストも同じ定義を描く。

## 走らせる

```bash
mokume run .      # 窓で並べて見る
swift test        # 窓を出さずに描いて、画素で比べる
PROBE_DUMP=/tmp/probe swift test   # 比べた絵を PNG で書き出す
```

**`swift test` は緑で終わる。** 破れていたものは `withKnownIssue` で包んであり、
「既知の問題」として数えられる (`v0.11.0` では 13 本のテストで 21 件)。

**mokume 側で直ると赤くなる。** 版を上げて直ったものがあると、そのテストは
「Known issue was not recorded」で落ちる。そのときは包みを外し、下の表を書き換える。

## 結果 — mokume `v0.11.0`

**mokume の `origin/main` (`4ce58b4`、2026-09-23) でも全件同じ値が出た。** v0.11.0 の後に
直ったものは無い。

### 破れていたもの (起票した)

| 鍵 | 何が起きたか | mokume |
| --- | --- | --- |
| `mirroredSolid` | `scale(-1, 1, 1)` した不透明の箱で、手前の面が捨てられて奥の面だけが写る。輝度の和が期待の 1/10 | [#1446](https://github.com/mokume-metal/mokume/issues/1446) |
| `blendOnTransparent` | 透明な下地の上で、`blend` / `replace` 以外の 8 種の色が狂う。`multiply` の赤は黒い不透明の矩形になり、`add` などは半分、`subtract` は負になる | [#1447](https://github.com/mokume-metal/mokume/issues/1447) |
| `ellipticArc` | 楕円の `arc` の塗りの内外を中心から見た角で決め、辺は媒介変数の角で引いている。切り口の外へ三角の塗りがはみ出す | [#1448](https://github.com/mokume-metal/mokume/issues/1448) |
| `curveContour` | `curveVertex` の履歴が `beginContour` をまたいで残る。穴の書き始めが外周の点に引かれて欠ける | [#1449](https://github.com/mokume-metal/mokume/issues/1449) |
| `fillAlpha` | 不透明度が 0…255 に締まらない。α -100 で下地が負の値へ落ち (黒く抜け)、α 400 で白を越える | [#1450](https://github.com/mokume-metal/mokume/issues/1450) |
| `hairline` | 1 画素より細い線の濃さが置く位置で変わる。0.1px の線は、整数の座標で 0.55、半端な座標で 0.093 (期待は 0.1) | [#1451](https://github.com/mokume-metal/mokume/issues/1451) |
| `trailingSpace` | 流し込みの最後の行の末尾の空白が幅に数えられ、右揃えの行が左へずれる | [#1452](https://github.com/mokume-metal/mokume/issues/1452) |
| `lerpEnds` (テストだけ) | `lerp(1e8, 1, 1)` が 0 を返し、`lerp(-3e38, 3e38, 0.5)` が inf を返す。説明の約束 (1 なら `stop`、数でない値を返さない) と違う | [#1453](https://github.com/mokume-metal/mokume/issues/1453) |

### 起票しなかったもの

| 鍵 | 何が起きたか | 起票しなかった理由 |
| --- | --- | --- |
| `bevelJoin` | 太線の `bevel` が、`rect` では 45° の面取り、同じ 4 隅の `quad` では正方形の角になる | **既知の保留。** [mokume#931](https://github.com/mokume-metal/mokume/issues/931) の材料 1 で、`StrokeStyle` の説明も保留を名乗っている。`withKnownIssue` で包んで見張る |
| `spriteBleed` | 2 コマのシートの左のコマだけを拡大すると、右端の 9 列に隣のコマの青がにじむ | **手本と同じ。** HTML の canvas も、元の矩形の外で原本の画素を読むと決めている。にじむ幅が半コマを越えないことだけを押さえる |
| `clipTranslate` | `translate(60, 60)` の後の `clip(0, 0, 60, 60)` は、動かした先ではなく面の (0…60) を残す | **不具合ではなく、説明の欠け。** どちらの読み方にも手本がある。説明に書くよう [mokume#1445](https://github.com/mokume-metal/mokume/issues/1445) (docs) を起票し、テストはいまの振る舞いを押さえる |

### 約束どおりだったもの (v0.11.0 の変更の見張り)

| 鍵 | 確かめたこと |
| --- | --- |
| `ellipsoidScale` | `ellipsoid(60, 30, 20)` と `scale(60, 30, 20); sphere(1)` が、160x160 のうち 2 画素しか違わない。**法線は正しく、光の当たり方も一致する** |
| `cameraKeepsOrtho` | `ortho()` の後の引数なしの `camera()` が、平行投影を残す (v0.11.0 の修正)。1 画素も違わない。**検査が効いていることは、透視へ戻した絵と 100 画素以上違うことで確かめてある** |

## どうやって当たりを付けたか

v0.11.0 のソースを読み、次の条件で 14 件の当たりを付けた。

- 最近入った・変わった口を優先する (`ellipsoid`、`lerp` / `constrain`、`camera()`、文字の流し込み、貼る絵の畳み)。
- 同じ結果を 2 つの経路で作れるものを選ぶ (形の経路と三角形の経路、本体の面と別の面)。
- 開いている Issue に載っているものは除く。

14 件のうち、**v0.11.0 の後に main で直っていた 2 件** (`get()` の後の図形が次の `get` に写らない件と、段落末の空白で折ると空の行が増える件) は外した。

`save()` と `NSApplication.terminate` を同じ `draw()` で呼ぶ件は、窓の経路でしか起きないので、テストでは突いていない。

## 窓の重さ

`mokume run .` の窓は、観測で 35.7 fps (1 フレーム 28 ms) だった。24 枚の面へ毎フレーム
描き直しているうえ、`mokume run` は debug で組む ([Prism](https://github.com/mokume-metal/works/blob/main/Prism/README.md) が
release との差 3.2 倍を測っている)。**物差しなので、速くする手は入れていない。**

## どの mokume で測ったか

**`Package.resolved` が固定している版がそのまま答えで、コミットしてある** (`v0.11.0` =
`503082f`)。`from: "0.11.0"` は他の作品と同じく記録であって、留め金ではない。

版を上げたら `swift test` を回す。**赤くなったテストは、直った約束である。**
