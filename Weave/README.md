# Weave — mokume v0.12.0 で「機能を組み合わせたときだけ」崩れる継ぎ目を突く

**作品ではなく物差しである。** 他の物差しは、1 つの機能か 1 つの条件を見る。条件は、フレームの継ぎ目・
失敗の後・書き出し・資源である。こちらは、**1 つずつなら正しく動く機能を組み合わせたときの絵が、同じ機能を 1 つずつ
使って合成した絵と同じか**を見る。

組み合わせで崩れるバグは、1 つずつの検査を全部通っても残る。崩れ方は 3 つの型に分かれる。

- **状態の一部だけが、別の経路に届く** (または届かない)。例: 粒の板が利用者の `texture` を読む。
- **共有の写しを、別の組み合わせが上書きする。** 例: 1 フレームに 2 回描いた粒の 1 回目が消える。
- **フレームの途中の描き切りで、後段の仕組みが前半を取りこぼす。** 例: `get` を挟むと影が割れる。

## 何をしているか

**候補 1 件を、同じ絵になるはずの 2 つの経路で描く。**

- **左 (`suspect`)** は、機能を組み合わせて 1 回で描く。
- **右 (`reference`)** は、同じ機能を 1 つずつ使って、同じ絵になるよう合成する。例えば次のように書く。
  - 塗りだけの図形の上に、輪郭だけの図形を重ねる。
  - 同じ放出をした別の粒の群を使う。
  - 読み取りの行を抜く。
  - 切り抜きの中の `background` を、同じ色の矩形に置き換える。

食い違えば、組み合わせた片方の状態が、もう片方の経路へ漏れているか、届いていない。

| 確かめ方 | 何を通るか | 何で見るか |
| --- | --- | --- |
| `mokume run .` | 窓の経路。1 候補ずつ、左右に 2 経路の絵を並べる (← → で切り替える) | 目で見る |
| `swift test` | 窓を出さない経路。`SketchRuntime` を経路ごとに組み、N 枚回す | 画素を読んで数で比べる |

組み立てと比べ方は、[Aftermath](../Aftermath/) と同じである。

- **経路ごとに別の `SketchRuntime` で回す。** 組み合わせた側の状態が、面を分け合う隣の経路へ漏れて疑いに混ざらない
  ようにするためである。
- **比べるときの許容はほぼ 0 にする** (成分の差 0.004 = 表示の 1 段未満)。同じ機械・同じフレーム番号からは、
  バイト単位で同じ絵が出る約束 (mokume ADR-0001 原則 2) があるためである。
- **線の形の 2 件 (`polylineJoin`・`roundCapScale`) は、縁を 50% の被覆で白黒にした形で比べる。** 経路の違う
  同じ図形は、縁の濃さが違ってよく、形 (位置・大きさ・向き) が一致する約束だからである (mokume ADR-0039 決定 1)。
- **各検査は、比べる前に参照の側が描けていることを押さえる。** この押さえは `withKnownIssue` の外に置く。
  参照まで描けていないことを、既知の問題に数えないためである。
- **陰性対照を 3 件置く** (`blendFillStroke`・`clipAligned`・`textureSky`)。組み合わせても崩れないものを 0 画素差で
  押さえ、舞台と比べ方が効いていることを示す。

候補の定義は [`Sources/Weave/Tangles.swift`](Sources/Weave/Tangles.swift) の 1 か所にあり、窓もテストも同じ
定義を描く。

## 走らせる

```bash
mokume run .                          # 窓で並べて見る
swift test                            # 窓を出さずに回して、画素で比べる
WEAVE_DUMP=/tmp/weave swift test      # 比べた最後の絵を PNG で書き出す
```

**`swift test` は緑で終わる。** 破れていたものは `withKnownIssue` で包んであり、「既知の問題」として
数えられる (`v0.12.0` では 19 本のテストで 16 件)。

**mokume 側で直ると赤くなる。** 版を上げて直ったものがあると、そのテストは「Known issue was not recorded」で
落ちる。そのときは包みを外し、下の表を書き換える。

## 結果 — mokume `v0.12.0`

**19 件を突いて、16 件が約束を破っていた。** 16 件とも mokume へ Bug として戻した。陰性対照の 3 件は、
1 画素も違わなかった。

### 破れていたもの

| 群 | 鍵 | 組み合わせ | 何が起きたか | mokume |
| --- | --- | --- | --- | --- |
| 混ぜ方・線 | `addFillStroke` | `blendMode(.add)` × 塗りと輪郭を両方持つ `rect` / `circle` | 不透明な輪郭の帯の内側半分で、塗りが足されない (2050 画素)。輪郭の不透明度 254 では足されるので、255 との間で絵が不連続に変わる | [#1643](https://github.com/mokume-metal/mokume/issues/1643) |
| 混ぜ方・線 | `polylineJoin` | 斜めの折れ線 × 太い線 | 一直線の 3 点の中点で、形の座標軸に沿った正方形が帯の外へはみ出す (白黒の形で 38 画素)。`rotate` して描くのと、回した座標で描くのとでも、形が違う | [#1644](https://github.com/mokume-metal/mokume/issues/1644) |
| 混ぜ方・線 | `roundCapScale` | `scale(20)` × 折れ線の丸い端 | 円板の分割数を拡大前の半径で決めるので、端が三角形になる (白黒の形で 116 画素) | [#1645](https://github.com/mokume-metal/mokume/issues/1645) |
| 状態 | `shapeCurveDetail` | `createShape` × `curveDetail` | 組み立ての中で変えた細かさが外へ漏れ、後の曲線が折れ線になる (1627 画素) | [#1646](https://github.com/mokume-metal/mokume/issues/1646) |
| 切り抜き | `clipFraction` | `clip` × 小数の座標 | 右端・下端を切り捨てて、切り抜きの内側の半分覆われた列と行を削る (81 画素) | [#1647](https://github.com/mokume-metal/mokume/issues/1647) |
| 切り抜き | `clipBackground` | `clip` × `background` | 切り抜きを無視して面全体を塗り、先に置いた図形も捨てる (12800 画素)。Processing と p5 は内側だけを塗る | [#1648](https://github.com/mokume-metal/mokume/issues/1648) |
| 粒 | `particlesTexture` | `particles` × `texture` | 白い粒が、貼った絵の赤に染まる (400 画素)。CPU の経路は記録した面を張り直すが、既定の GPU の経路は張り直さない | [#1649](https://github.com/mokume-metal/mokume/issues/1649) |
| 粒 | `particlesShader` | `particles` × `shader` | 粒が利用者の断片で塗られる (400 画素)。同じく GPU の経路だけが、記録した塗りを当て直さない | [#1650](https://github.com/mokume-metal/mokume/issues/1650) |
| 粒 | `particlesTwice` | 1 フレームに同じ群を 2 回 `particles` | 置き場所の写しが 1 つで、1 つ目の雲が消える (400 画素) | [#1651](https://github.com/mokume-metal/mokume/issues/1651) |
| 断片 | `shaderSetGraphics` | 本体で作った断片 × 描き場所で `set` を挟む | 描き場所の列が閉じず、全部が最後の値で塗られる (12800 画素) | [#1652](https://github.com/mokume-metal/mokume/issues/1652) |
| 断片 | `shaderSurfaceRedraw` | 断片の面の描き場所 × 置いた後の描き換え | 先に置いた図形が、描き換えた後の絵で塗られる (12800 画素) | [#1653](https://github.com/mokume-metal/mokume/issues/1653) |
| 描き場所 | `graphicsSetOutside` | `beginDraw` の外の `set` × `image` | `get` は書いた値を返すのに、`image` には出ない (12800 画素) | [#1654](https://github.com/mokume-metal/mokume/issues/1654) |
| 描き場所 | `effectsOffFrameSet` | 描き場所の効果 × フレームの外の `set` | 値を変えない 1 画素の書き戻しで、次のフレームに効果が 2 回掛かる (22400 画素) | [#1655](https://github.com/mokume-metal/mokume/issues/1655) |
| 途中の描き切り | `midFrameShadow` | フレームの途中の `get` × 影 | 読む前に置いた立体の影が、後に置いた床に落ちない (262 画素) | [#1656](https://github.com/mokume-metal/mokume/issues/1656) |
| 途中の描き切り | `loadPixelsSky` | 立体 → `loadPixels` → `background(.sky)` | 立体が空の上に残る (5929 画素)。`loadPixels` を抜くと空が置き換える | [#1657](https://github.com/mokume-metal/mokume/issues/1657) |
| 周囲 | `addSky` | `blendMode(.add)` × `background(.sky)` | 背景が前のフレームに足され、2 枚目で 2 倍になる (25600 画素) | [#1658](https://github.com/mokume-metal/mokume/issues/1658) |

### 崩れなかったもの (陰性対照)

| 鍵 | 組み合わせ | 約束の出典 |
| --- | --- | --- |
| `blendFillStroke` | `blendMode(.blend)` × 塗りと輪郭を両方持つ図形 | 基本図形は塗りの上に線の順で混ぜる |
| `clipAligned` | `clip` × 整数の座標 | `clip` の説明「描くものを、この矩形の中だけに収める」 |
| `textureSky` | `texture` × `background(.sky)` | 周囲の背景の説明 (貼る絵を見ない) |

### 落ちたもの

`createShape { }` の中で、同じフレームで先に置いた描き場所を描き換えると、プロセスごと落ちる
(`Range requires lowerBound <= upperBound`)。

- 原因は、記録中の描き切りが溜め場を空にすることで、mokume#1588 (`createShape` の中の `background` / `get`) と同じ根である。
- 入口が違うだけなので、新しい Issue にせず、[#1588 へ入口を足した](https://github.com/mokume-metal/mokume/issues/1588#issuecomment-5845167835)。
- 落ちる口の検査は Soak が持つ (ADR-0008)。Soak の `createShapeDiscard` が同じ根を見ているので、Weave には
  置いていない。

## どうやって当たりを付けたか

mokume `v0.12.0` のソースを 3 方面に分けて読んだ。方面は次のとおりである。

- 2D の状態 × 描き場所・絵
- 変換・形・線・字・色
- 効果・断片・立体・粒・数

読んだのは、**状態をどこに持ち、どこで保存・復元・張り直しするか**と、**控えや写しを誰と共有するか**である。
組み合わせると破れそうな継ぎ目に当たりを付け、公開の口だけで画素から判定できるものを選んだ。約束の出典は、
次のいずれかが書けるものに限った。

- 説明文
- ADR
- 実装のコメントが名乗る約束 (例: `createShape` の「記録の間に触った状態は外へ出さない」)
- 手本 (Processing・p5)

破れのうち 5 件は、mokume 自身の別の経路が約束どおりに描くことが、判定の拠り所になった。

- 粒の 2 件: CPU の経路 (「速い側を照らす物差し」)
- 断片の 1 件: 描き場所で作った断片
- 線の 2 件: `line()`

同じ関数の中で、片方の経路だけが状態を張り直していた。組み合わせの破れの典型的な形である。

### 当たりを付けたが突かなかったもの

| 当たり | 突かなかった理由 |
| --- | --- |
| `push` / `pop` が `curveDetail` / `curveTightness` を戻さない | Processing の `pushStyle` も曲線の細かさを持たない。手本と同じなので、`createShape` の漏れ (`shapeCurveDetail`) だけを突いた |
| 9 引数の `image` の切り出し × 拡大で、切り出しの外の画素が縁ににじむ | 食い違いは出た (256 画素) が、説明は「重なった分だけが、同じ倍率で指した場所に出る」としか書いていない。HTML の canvas の `drawImage` も、切り出しの外を標本に使うことを許している。約束が一意に決まらない |
| 細長い楕円 × 太い輪郭で、長軸の端の帯が膨らむ | 距離場の近似の精度の話で、#1562 (三角形の経路の細長い楕円) と近い。組み合わせの破れとして切り出せる形が定まらない |
| 自分自身を置く (`g.image(g, …)`) | 読み書きが同じ面に同居するので、判定が「非決定に乱れるか」になる。反復で見る `scripts/stress.py` の側の話である |
| 本体で頼んだ計算 × 同じフレームで描き場所が読む | 読む値が 1 フレーム前になる見込みだが、参照を数の並びと断片の組で書く形が重い。次の版で足す候補 |
| erase・mask・filter・colorMode・描き場所の `pixelDensity` | mokume `v0.12.0` に口が無い |

## どの mokume で測ったか

**`Package.resolved` が固定している版がそのまま答えで、コミットしてある** (`v0.12.0` = `bab3b4a`)。
`from: "0.12.0"` は他の物差しと同じく記録であって、留め金ではない。

版を上げたら `swift test` を回す。**赤くなったテストは、直った約束である。**
