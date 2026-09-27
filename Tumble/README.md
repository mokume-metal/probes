# Tumble — mokume v0.12.1 を、乱数から作った呼び出しの列で突く

**作品ではなく物差しである。** 他の物差しは、突く候補を人が選ぶ (ソースを読んで継ぎ目に当たりを付ける・作品が
ふつう書く書き方を選ぶ・条件の格子を決める)。こちらは**候補を選ばない**。種 1 つから、口録の口と引数を乱数で
引いて呼び出しの列を作り、数千本を回して、破れたものだけを縮めて読む。

人が思い付かない組み合わせと、端の値 (0・負・とても大きい・とても小さい・数でない値・無限) の組み合わせで
はじめて出る破れを探すためのものである。判断は [ADR-0013](../docs/decisions/0013-tumble-generated-sequences.md)。

## 何をしているか

**列は種 1 つから決まる。** 乱数は SplitMix64 で、同じ種からはどの機械でも同じ列が出る。列は setup の口 0〜2 個と、
1〜4 枚のフレームにそれぞれ 1〜14 口を持つ。

- **口録** ([`Sources/Tumble/Catalog.swift`](Sources/Tumble/Catalog.swift)) は、作品がふつうに呼ぶ口を 111 並べる。
  塗り・線・変換・平面の形・`beginShape` / `beginContour`・字・絵と 9 引数の `image`・描き場所 (`beginDraw` の中へも
  描く)・`get` / `set` / `pixels`・混ぜ方・切り抜き・効果・`texture`・断片・`createShape`・粒・立体と光、それに
  v0.12.0 の新しい口 (`lerpColor`・`fill(color, alpha)`・`norm`・`smoothstep`・`weakeningBeyond`)。
- 引数は種類 (位置・大きさ・角度・色の成分・太さ・割合・倍率・個数・細かさ・選択肢) ごとに、ふつうの値の幅と
  端の値の袋を持つ。端の値は引数の 1 割前後に出る。
- 列の最後のフレームの後に、**番兵**のフレームを 1 枚描く。

**列を窓を出さずに回し、7 つで判定する。** どれも mokume の別の経路には頼らない。

| 判定 | 破れ | 出典 |
| --- | --- | --- |
| 落ちない | プロセスが signal で死ぬ (`crash`) | 描く口は投げない (mokume ADR-0020 決定 5) |
| 止まらない | 出力が 20 秒進まない (`hang`) | 同上 |
| 投げない | `advance()` が投げる (`threw`) | 同上 |
| 毎回同じ絵 | 同じ列を 2 回回して、どこかのフレームの画素がバイトで違う (`nondeterministic`) | mokume ADR-0001 原則 2 |
| 戻らない劣化が無い | 番兵の絵が、列を回さなかった番兵と違う (`sentinel`) | mokume ADR-0021 決定 4 |
| 絵が数である | 画素に数でない値か無限がある (`nonfinite`) | mokume ADR-0033 決定 9・ADR-0035 |
| 漏れない | 列を 240 枚繰り返して、footprint が 1 枚 32 KB を越えて増えるか GPU の確保量が増え続ける (`leak` / `gpuLeak`) | Soak と同じ (ADR-0005) |

- **番兵**は、列が触りうる状態のうちフレームを越えるもの (塗り・線・混ぜ方・字・貼る絵・断片・露出) を明示して
  既定へ戻してから、決まった絵を描く。フレームを越えない状態 (変換・切り抜き・光・効果・視点) は戻さない —
  mokume がフレームの境目で戻す約束だからである。
- **落ちる・止まるは子プロセスの終わり方で見る。** ドライバ ([`scripts/tumble.py`](scripts/tumble.py)) が種を束で
  子プロセスに回させ、回す前に種を名乗らせる。
- **破れた列は delta debugging で縮める。** フレームを落とす → 口を落とす → 端の値をふつうの値へ戻す、を
  変わらなくなるまで繰り返す。縮めた列は `tumble.py` が Swift の `setup()` / `draw()` として書き出す。

| 確かめ方 | 何を通るか | 何で見るか |
| --- | --- | --- |
| `mokume run .` | 窓の経路。種の列を回し、左に列 (最後が番兵)・右に列を回さなかった番兵を並べる (← → で種を替える) | 目で見る |
| `python3 scripts/tumble.py run` | 窓を出さない経路。種を束で子プロセスに回させる | 7 つの判定 |
| `swift test` | 陰性対照・固定の種の束・縮めた列・起票した再現 | 画素と判定 |

## 走らせる

```bash
mokume run .                                            # 窓で種の列を見る
python3 scripts/tumble.py run --seeds '0..<10000'       # 探す (20 分ほど)
python3 scripts/tumble.py run --seeds '0..<500' --soak  # 漏れを探す (1 種に 480 枚)
python3 scripts/tumble.py shrink 3161 --break hang      # 破れた種を縮めて Swift で出す
swift test                                              # 陰性対照・固定の束・縮めた列・再現
```

**`swift test` は緑で終わる。** 破れていたものは `withKnownIssue` で包んであり、「既知の問題」として数えられる
(`v0.12.1` では 13 本のテストで 3 件)。うち 2 件は、起票に貼った再現 (`Tests/TumbleTests/Repros/`) をそのまま走らせる
`ReprosTests` の分、1 件は縮めた列 (`Findings/`) の分である。

**mokume 側で直ると赤くなる。** そのときは包みを外し、下の表を書き換える。起票済みの破れを踏む引数は、生成で
避けている (`Catalog.avoidKnown`)。直ったらそこからも外して、見張りに戻す。

## 結果 — mokume `v0.12.1`

<!-- 数は最終の実行で差し替える -->

### 破れていたもの

| 鍵 | 縮めた列 | 何が起きたか | mokume |
| --- | --- | --- | --- |
| `backgroundOverflow` | `background(1e9, α)` (1 口) | 白を越える明るさの `background` が、色を締めずに Float16 の面へ置き、面が +inf を持つ。その上に不透明な図形を描くと、図形の中が NaN になり表示では黒く抜ける。`fill` + `rect` の経路は 65504 で止まる | 起票予定 |
| `curveDetailUnbounded` | `curveDetail(Int.max)` → `bezierVertex` (2 口) | `curveDetail` が下限しか締めず、渡した数だけ曲線の点を作る。フレームが戻らず、130 秒で 21 GB を確保した。立体の分け方は 128 へ丸める | 起票予定 |

### 既知の Issue へ足したもの

| 縮めた列 | 何が起きたか | mokume |
| --- | --- | --- |
| `textLeading(Float.infinity)` → `textAlign(.center, .bottom)` → `textOutline` (3 口) | 座標は有限でも、無限の行送りが輪郭の座標を無限にし、Int への変換で落ちる | [#1587 へ入口を足した](https://github.com/mokume-metal/mokume/issues/1587#issuecomment-5854954443) |
| `g.beginDraw()` → `g.torus(…)` を毎フレーム (2 口) | `endDraw()` の無い描き場所に立体が積まれ続け、1 枚 6.7 MB 増える。main では #1622 の直しで止まっている | [#1622 へ観察を足した](https://github.com/mokume-metal/mokume/issues/1622#issuecomment-5854955893) |

### 既知の破れを踏んだもの

- `textOutline` に数でない座標を渡すと落ちる (mokume#1587)。1 回目の 400 種で 3 種が踏んだ。生成で避けている。
- `curveDetail(10000)` で刻んだ曲線を塗ると、三角形分割が頂点数の二乗 (mokume#1595) なので止まる。`curveDetail` の
  上限が無いことと重なる。生成では 1000 を越える値を避けている。
- 既定の線を持つ `sphere(detail: 128)` は debug で 1 枚 183 ms かかる (線を止めると 8.3 ms)。立体の稜線を毎フレーム
  CPU で組むため (mokume#1604)。漏れを測る 480 枚が止まったように見えたので、`--soak` の止まったとみなす時間を 180 秒にした。

### 調べて起票しなかったもの

- **0–1 の口で直に作った NaN の色** (`LinearRGBA(straightRed: .nan, …)`) は、`fill(color, alpha)` や `set` を通って絵に届く。
  mokume は数値の口 (0–255) の手前で弾くと決め、直に作った値の扱いは変えないとしている (mokume ADR-0033 決定 3)。
  約束の外なので、袋から外した。
- **断片に NaN を渡す** と、断片が返す色が NaN になる。利用者のコードの値なので、袋を 0…1 に限った。
- **毎フレーム `createGraphics` して捨てる** と、footprint が 0〜13 KB/枚でゆれながら増えることがある。捨てた描き場所は
  弱い参照で解放を確かめた。描いて置いてから捨てても同じくゆれたので、割り当て器か Metal の側の溜め方と見た。
- **毎フレーム `makeParticles(count: 1_048_576)`** は 1 枚 4.7 秒 (debug) かかるが、メモリも GPU の確保量も増えない。
  重い仕事を毎フレーム頼んでいるだけとみた。
- **`endDraw()` の無い描き場所の漏れ** は、main では直っていた (上の #1622)。

## 構成

```
Sources/Tumble/
  Program.swift     乱数 (SplitMix64)・引数・口・列。列を Swift に書く
  Catalog.swift     口録 111 口と、引数の袋・既知の破れの回避
  Played.swift      列を回すスケッチと番兵
  Examine.swift     判定 (2 回回す・番兵・数でない画素・漏れ)
  Tumble.swift      窓と、窓を出さない走り方 (--headless / --emit / --swift)
scripts/tumble.py   ドライバ (束で回す・止まったら殺す・縮める)
Findings/           縮めた列 (JSON)
Tests/TumbleTests/  陰性対照・固定の種の束・縮めた列・起票した再現
```
