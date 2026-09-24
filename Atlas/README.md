# Atlas — Processing の Examples を全数で mokume に当てる

制作トラック ([mokume ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)) の 5 本目。**これは作品ではなく物差しである** — 既存 4 本が「作品であると同時に物差し」だったのに対して、こちらは測ることしかしない。

Garden・Solids・Ring は p5.js の例を 1 本ずつ写し、その 1 本で踏んだ穴を対応表にして mokume へ戻してきた。**この形では穴の重みが分からない。** Ring は「`map` と `radians` が無い」を [#883](https://github.com/mokume-metal/mokume/issues/883) にしたが、それが Ring 1 本の都合なのか、Processing の例の 4 分の 1 が止まる話なのかは、1 本ずつ写している限り出てこない。

[Processing 公式の Examples](https://processing.org/examples/) を全数で当てると、穴ごとに**何本の例を止めるか**が出る。台帳は processing-examples の 254 本を机上で当て、**実測は公式ページに並ぶ 162 本を全部移して**原典と並べる。

## 台帳

| 区分 | 例数 | `v0.6.0` のとき | `v0.5.0` のとき | |
| --- | ---: | ---: | ---: | --- |
| `clean` | **100** | 90 | 64 | そのまま届く |
| `write-only` | **10** | 8 | 23 | 書けば届く |
| `bend` | **54** | 54 | 63 | 書けるが歪む |
| `blocked` | **39** | 51 | 53 | 口が無くて止まる |
| `out-of-scope` | 51 | 51 | 51 | 測らないと決めた |
| **合計** | **254** | **254** | **254** | |

**`v0.6.0` で 26 本が `clean` へ移った。** works が戻した Issue が 3 本まとめて閉じたためで、
これは**台帳が予測した重みの答え合わせ**にあたる — 下の表で `map` (33 例) と `radians`
(23 例) と `mousePressed` (18 例) と `keyPressed` (11 例) が上位から消えている。

**`v0.9.0` で動いたのは 1 つの穴だけで、12 本が `blocked` から出た。** 進行を止める口
([#900](https://github.com/mokume-metal/mokume/issues/900)) が入り、`noLoop` / `loop` /
`redraw` の 3 行が `none` から `same` になった。**ここでも台帳が「いちばん重い」と数えて
いた穴が先に埋まっている** — `noLoop` は 18 例を止めていて、`none` の中で最多だった。

`out-of-scope` は GLSL を書く例 (`Topics/Shaders` ほか)・性能測定と処理系の試験 (`Demos/Performance` / `Demos/Tests`)・ファイル入出力とネットワークが主題の例。**台帳から消さずに理由を持たせて残している** — 消すと「測っていない」と「測ったが届かない」の区別が付かなくなる。

### 何本の例を止めるか

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 25 | `PVector` | `bend` | SIMD2\<Float\> / SIMD3\<Float\> |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate — 起動時だけ。**代入は黙って無視される** |
| 12 | `colorMode` | `bend` | color(hue:saturation:brightness:) — **目盛りは張り替えられない** |
| 10 | `dist` | `write` | — |
| 10 | `updatePixels` | `none` | — |
| 9 | `constrain` | `write` | — |
| 8 | `QUADS` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 7 | `mag` | `write` | — |
| 6 | `QUAD_STRIP` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 6 | `createFont` | `none` | — |

全 20 行は [`ledger/summary.md`](ledger/summary.md)。

**`v0.5.0` のときの上位 4 つは、この表から消えた。**

| 語彙 | `v0.5.0` の判定 | 止めていた例数 | `v0.6.0` |
| --- | --- | ---: | --- |
| `map` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | 33 | `same` — 同名・同じ引数の形 |
| `radians` | `write` ([#883](https://github.com/mokume-metal/mokume/issues/883)) | 23 | `same` |
| `mousePressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | 18 | `same` — 出来事の口が入った |
| `keyPressed` | `bend` ([#723](https://github.com/mokume-metal/mokume/issues/723)) | 11 | `same` |

**`v0.9.0` でもう 1 つ消えた。**

| 語彙 | `v0.6.0` の判定 | 止めていた例数 | `v0.9.0` |
| --- | --- | ---: | --- |
| `noLoop` | `none` ([#900](https://github.com/mokume-metal/mokume/issues/900)) | 18 | `same` — 同名・引数なし。`loop` / `redraw` も一緒に入った |

**台帳がいちばん重いと数えたものから順に埋まった。** 1 本ずつの移植では出なかった重みが、
実際に直す順番と一致していたことになる。

### 判定の意味

**上の 4 つは届く。下の 3 つが穴。**

| | |
| --- | --- |
| `same` | mokume に同名がある。機械が置く |
| `renamed` | 口はあるが別名・別の形 (`CENTER` → `ShapeMode.center`) |
| `host` | mokume ではなく Swift の語彙で当たる (`PI` → `Float.pi`) |
| `drop` | 原典にはあるが mokume では要らない (`P3D` — 描き方のモードを持たない) |
| `write` | 面に無いが、面の外に書けば済む (`map` / `radians` / `dist`) |
| `bend` | 書けるが歪む。原典の形が保てない (`TRIANGLE_STRIP` / `mousePressed()`) |
| `none` | 口が無い (`loadFont` / `loadShape`) |

**`write` と `bend` を分けるのが肝。** どちらも「mokume に無い」だが、前者は不便なだけで、後者は原典の構造が壊れる。ADR-0022 決定 3 が Feature Issue に求める「書けなかったか、書けたが歪んだか」がこの区別そのものである。

### 台帳は予測であって、検証ではない

見ているのは**名前と定数だけ**なので、同名で当たってしまう違い (引数の形・既定値・振る舞い) は写らない。**移してみると、当たっていたのは半分ほどだった** — 下の「移して分かったこと」がその一覧である。だから台帳は移すたびに直す。

## 実測 — 公式ページの 162 本

**移せる 157 本を全部移した。** 残る 5 本 (`Basics/Shape` の SVG を読むもの) は `loadShape` に口が無く、形そのものが来ないので面が空になる。作り替えず 1 行ずつ写し、**書けない口は書けないまま残している** — 動くように書き替えると、止まったこと自体が消えるため (ADR-0022 決定 4)。

### 面の外に書き足したもの

Processing にあって mokume に無い語彙のうち、**面の外に書けば済むもの**は [`Sources/Support/Processing.swift`](Sources/Support/Processing.swift) 1 つに集めてある。**このファイルの長さがそのまま「Processing の例を書くのに mokume の外へどれだけ書き足す必要があるか」の答え**になる。

**`v0.6.0` で 177 行から 98 行になった。** 12 個が面へ移り、呼ぶ側の 150 ファイル・390 箇所が
原典の字面へ近づいた。

| 面へ移ったもの | 面の口 |
| --- | --- |
| `gray` / `rgb` / `hex` | `fill(_:)` / `fill(_:_:_:)` / `color(hex:)` — **目盛りは 0–255 で原典と同じ** |
| `hsb` | `color(hue:saturation:brightness:)` — 目盛りは 360/100/100 |
| `map` / `radians` / `degrees` | 同名・同じ引数の形 |
| `red` / `green` / `blue` / `brightness` | 同名。0–255 と 0–100 で返る |

| まだ外に要るもの | なぜ |
| --- | --- |
| `dist` / `constrain` / `lerp` / `norm` / `sq` / `mag` | 面に無い |
| `lerpColor` | 面に無い。**混ぜる空間が違う**ので、書いても原典と中間色が変わる |
| `second` / `minute` / `hour` / `millis` | 壁時計が無い。**値は Foundation が持っている**ので、無いのは読む口だけ |
| `asset` | 資材はリポジトリに置けないので、束の外から読む |

### 移して分かったこと

台帳が名前しか見ていないために写らなかったもの。**どれも「名前は当たるのに形が違う」**。

| | 何本に効くか |
| --- | --- |
| ~~**数を 1 つ / 2 つで渡す色が書けない**~~ (`fill(153)` / `fill(255, 204)`) — **`v0.6.0` で書ける**。150 ファイルが原典の字面に戻った | ほぼ全部 |
| **自分で描けるクラスが書けない。** 原典のクラスは `PApplet` の内側にいるので `fill` も `ellipse` もそのまま呼べるが、mokume の描く口は `Sketch` の上にあるので面を持ち回る | クラスを持つ例すべて |
| **`PVector` に当たるメソッドが 1 つも無い** (`add` / `sub` / `mult` / `div` / `normalize` / `limit` / `mag` / `dist` / `heading` / `rotate` / `setMag` / `copy` / `random2D`) | Motion / Vectors / Simulate の 17 本 |
| ~~**キーの出来事を受ける口が無い**~~ — **`v0.6.0` で入った** ([#723](https://github.com/mokume-metal/mokume/issues/723) 閉じた) | 11 本 |
| ~~**押した瞬間を受ける口が無い**~~ — 同上。ポーリングの足場を撤去した本もある (`Handles` / `Scrollbar`) | 18 本 |
| **立体の `line` が無い。** 原典の 1 行が `beginShape(.lines)` + 3 次元の `vertex` で 4 行になる | `MoveEye` |
| **`Image` に `pixels` の 1 次元の並びが無い**。`createImage` も形式の引数を取らない | Image Processing の 6 本 |
| **`background()` に絵を渡す形が無い** | `BackgroundImage` |
| **書体ファイルを読む口が無い。** システムの書体へ置き換えれば絵は出るが、字形が環境で決まる | 6 本 |
| **`scale` の引数 1 つの一様な拡大が無い** / **`spotLight` の集中度が渡せない** / **鏡の反射 (`specular`) が書けない** / **均しを切る口 (`noSmooth`) が無い** | それぞれ 1〜3 本 |
| **光は `setup()` に置けない。** 「光はフレームごとに置き直すもの」なので、静止形の例を `setup()` へ写すと光だけが無視される | `Primitives3D` |

**台帳を覆したものもある。** `Basics/Shape/LoadDisplayOBJ` は「絵が出せない」と判定されていたが、`loadShape` に口が無いのは本当でも **OBJ に限れば `loadModel` がある**。Processing が SVG と OBJ を 1 つの名前で受けているのに対し、mokume はそこを分けているためで、**語彙の名前 1 つに判定を 1 つ持たせている限り、同じ名前で 2 つのものを読む語彙は正しく測れない**。`mask` も同じで、`get` / `set` で画素を移し替えれば書ける (`none` ではなく `write`)。

### 原典と同じ見た目になっているか

**移した 157 本を、原典と並べて画素で突き合わせた。** 原典は processing-website が例ごとに配る `liveSketch.js` (Processing 版と 1 行ずつ対応した p5.js) をブラウザで走らせたもので、**mokume と条件を揃えてある** — マウスを動かさない (`mouseX` = 0)・決めた枚数で止める・等倍 (`pixelDensity(1)`) の 3 つ。

**画素の完全一致では測れない。** 目には同じ絵でも数字だけが落ちる原因が 3 つあるので、4 つの数を出す。**半画素ずらして合うかを測る**のが肝で、ずらすと合うなら違いの正体は線の載せ方だと言い切れる (ぼかしでは言い切れない)。

| | 何を見るか |
| --- | --- |
| その場で一致 | そのままの位置で、色が差 8 以内 (目で見て同じ色) |
| 半画素ずらして | mokume を半画素動かしてよいとしたとき |
| 形が一致 | 明るさの縁だけを取り出し、1 画素の幅を許して比べたもの |
| 完全一致 | 1 画素も違わない |

**測れない例には数を出さない。** 乱数・時計・書体を使う例は原典と mokume で列が違うので、一致率は「入っている乱数と書体」を測っているだけになる。並べた 1 枚は作るが、数字の代わりに理由を絵に刷る。

**どれが「同じ絵」かは決めていない。** 数と並べた 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。

**止まった 1 枚では判断できないものには、動くものを併載してある。** 決まった道すじでマウスを流しながら 24 枚撮り、原典と並べたアニメーション WebP にしたもので、**123 本に付いている**。置き換えではない — 細かい差は静止画のほうが向いている。

道すじは式で決めてあった (移植側と原典側の 2 か所に同じ式を置いた)。**揃っていないと、動きの違いなのか入力の違いなのか分からなくなる。** 原典の側では `mousePressed()` などの出来事も起こしていた — 本物のブラウザなら呼ばれるものなので、呼ばないと原典だけ手加減したことになる。

**動きが付いていない 34 本**は、道すじを流しても絵が 1 枚も変わらなかったもの (Processing の静止形)。

**`v0.5.0` のときは 117 本だった。** 増えた 6 本は、出来事の口が入って**マウスの道すじに反応するようになった**例である — 動きの証跡の本数そのものが、口が増えたことの目盛りになっている。

| その場で一致 | 本数 |
| --- | ---: |
| 100% | 13 |
| 99% 以上 | 50 |
| 95% 以上 | 14 |
| 90% 以上 | 6 |
| 90% 未満 | 24 |
| 数を出さない | 50 |

移した 157 本ぶん。うち 1 本は原典が静止画しかなく、縮めて比べているので参考値。**どれが「同じ絵」かは決めていない** — 数と並べた 1 枚を出すところまでが機械の仕事で、見て決めるのは人である。

**数を出さない理由は 1 つではない** — 乱数・雑音・時計 30 本・字を組む 7 本・原典が 2 つ食い違う 10 本・原典が 1 画素も描かない 2 本・面の大きさが違う 1 本。原典どうしが食い違う例と、原典が 1 画素も描かない例には数を出さなかった (前者は機械で探していた)。

**157 枚を並べた一覧は畳んだ** (「測るのをやめたもの」)。下に残してあるのは、そのうちの代表である。

![Basics/Form/Bezier — 原典と mokume](https://i.gyazo.com/6ff2bfe81e2ad2ff547000e2a668fe74.png)

![Basics/Math/Map — 原典と mokume](https://i.gyazo.com/46af99de5c9d9aa743e8e51aed426371.png)

![Topics/Drawing/ContinuousLines — 原典と mokume](https://i.gyazo.com/43f8b666348bc84787692376db7652b5.png)

**形と位置はよく合っている。** 157 本のうち 68 本が「その場で一致 99% 以上」で、差が出たものも輪郭の均し・色の作り方・線の載せ方の 3 つにほぼ収まる。

#### 1. 半透明を重ねると色が変わる (`Mouse2D`)

![Basics/Input/Mouse2D — 原典と mokume](https://i.gyazo.com/b0043f7a48c18cfe0199553b20dd3a8f.png)

原典の `fill(255, 204)` — 白を 80% の濃さで、51 の背景へ重ねる 1 行。**出てくる色が違う。**

| | 矩形の色 |
| --- | --- |
| 原典 (p5) | `214` |
| mokume | `232` |

**mokume は線形の空間で混ぜ、p5 は表示値のまま混ぜている。** `255 × 0.8 + 51 × 0.2 = 214` が p5 で、線形へ直してから混ぜて戻すと 232 になる。型の名前 (`LinearRGBA` = 「作業空間の色」) が言うとおりの振る舞いなので**これは mokume の意図**だが、**同じコードから違う絵が出る**ことは記録しておく。一致率が 92.1% まで落ちているのは、矩形が面の 7% を占めるためである (背景は 1 画素も違わない)。

#### 2. 同じ数から違う色が出る (`StatementsComments`)

![Basics/Structure/StatementsComments — 原典と mokume](https://i.gyazo.com/eccfb4d17f8f621dffdc23708a3865f0.png)

原典は `background(204, 153, 0)` の 1 行だけの例で、**面ぜんぶが 9 ずれる。**

| | 面の色 |
| --- | --- |
| 原典 (p5) | `204, 153, 0` |
| mokume | `213, 150, 0` |

**mokume の書き出しは Display P3 として刻まれる** (`sips -g profile` で確かめられる)。同じ数を渡しても原色が違うので、彩度のある色ほどずれる。**灰色は 1 画素も違わない** — 赤と緑と青が等しい色は原色の取り方に依らないからで、この節の他の例で灰色が合っているのはそのためである。`WidthHeight` の `fill(129, 206, 15)` は `101, 208, 0` になり、28 ずれる。

型の名前 (`LinearRGBA` = 「作業空間の色」) は空間を名乗っているが、**どの原色の空間かは名乗っていない**。半透明の合成 (下記 1) と同じで、これも mokume の意図した振る舞いだと思われるが、**同じコードから違う色が出る**ことは記録しておく。

#### 3. 1px の線をピクセルに載せるか、またがせるか (`NoLoop`)

![Basics/Structure/NoLoop — 原典と mokume](https://i.gyazo.com/a57a486bad51f567042a317a4f0adcdf.png)

`line(0, 180, width, 180)` の 1 本が、**p5 では 2 行に 128 ずつ・mokume では 1 行に 255** で出る。p5 は線をピクセルの境界にまたがらせて均し、mokume はピクセルに載せる。線 1 本ぶん (640 画素 = 面の 0.28%) の差なので一致率は 99.2% に留まる。

**この 3 つは台帳では絶対に出ない。** 語彙の名前は当たっていて、絵だけが違う。

### 止まったところ

**完成していない例がある。止まった形のまま残してある。** ADR-0022 決定 4 の言うとおり、作ろうとして止まったこと自体が実需だからである。

**`v0.6.0` で 27 本・`v0.9.0` でさらに 3 本が動くようになった。** 残っているのは次のとおり。

| 例 | 何が無くて止まっているか |
| --- | --- |
| ~~`Basics/Structure/NoLoop` / `Loop` / `Redraw`~~ | 進行を握る 3 本。**`v0.9.0` で動くようになった** ([#900](https://github.com/mokume-metal/mokume/issues/900) — 閉じた)。止める口・動かす口・描き直しを頼む口が同じ版でまとめて入った |
| `Basics/Web/LoadingImages` | `loadImage()` に URL を渡す口が無い。読めないので面が黒いまま |
| `Basics/Lights/Reflection` | 鏡の反射 (`lightSpecular` / `specular`) を書く口が無い。2 行を落とした。**`v0.9.0` にも無い** (あるのは材質の側の `shininess` / `metalness` で、光の側へ色を渡す口が無い) |
| `Basics/Web/EmbeddedLinks` | 押されたことは受け取れるが、`link()` でページを開く口が無い。**口が 1 つ埋まっても主題が移らない例** |
| `Basics/Shape` の 5 本 | `loadShape` に口が無い。**移していない** — 形が来ないので面が空になる |

**「段階の違い」がここに出ている。** 同じ `blocked` でも、口が 1 つ増えれば動く例 (27 本)・
2 つ揃わないと動かない例 (`Loop`)・別の口を待っている例 (`EmbeddedLinks`) がある。
**`Loop` は `v0.9.0` で 2 つ目が入って動いた** — 押される側だけが `v0.6.0` で埋まっていた
3 版のあいだ、この例は押す前から線が流れていて主題が移らなかった。**口の数を数えるだけでは
「あと何割で届くか」は出ない**ということが、この 1 本に残っている。

## 走らせる

**例 1 本ずつが、独立した mokume のスケッチである。** 見たい例を直に指す:

```bash
mokume run   Examples/Basics/Input/Mouse2D    # 作って走らせる
mokume watch Examples/Basics/Input/Mouse2D    # 保存したら作り直して差し替える
mokume mcp   Examples/Basics/Input/Mouse2D    # 走っているスケッチを外から観測する
```

`swift` から直に叩いてもよい:

```bash
swift run --package-path Examples/Basics/Input/Mouse2D
```

**Atlas そのものは走らない。** `Package.swift` に executable が無く、持っているのは例が引く共有の面 (`Sources/Support`) と版の正本 (`Package.resolved`) だけである。

移した例を並べるには:

```bash
ls -d Examples/*/*/*    # 157 本
```

**群の名前からは空白を詰めてある** (`Cellular Automata` → `CellularAutomata`)。打つパスにクォートが要らなくなるためで、**台帳の例名は原典どおり空白を保つ**。対応は [`scripts/examples.py`](scripts/examples.py) が持つ。

各例の `Package.swift` と `main.swift` は**生成物**である。置き場から組み直す:

```bash
python3 scripts/examples.py          # 書き直す
python3 scripts/examples.py --check  # 実体とずれていたら 1 で終わる (verify から呼ばれる)
```

**157 枚を手で並べない。** 足したのに書き忘れた 1 本は、`mokume watch` で開こうとするまで気付けない。

台帳を組み直すときは:

```bash
python3 scripts/fetch.py     # 上流を取ってくる (upstream/ は gitignore 済み)
python3 scripts/ledger.py    # ledger/ を組み直す
```

## 測るのをやめたもの

**絵を撮って突き合わせる仕組みを畳んだ。** 3 つが互いに噛み合っていたので、まとめて外した:

| 畳んだもの | 何だったか |
| --- | --- |
| `--render` / `--frames` / `--render-all` / `--motion` | 移した例を PNG へ書き出す口。全数のハッシュを一度に取り直すためにあった |
| `scripts/compare/` | 原典 (p5) と mokume を横に並べた 1 枚をブラウザで作り、Gyazo へ上げて台帳と文書へ書き戻す仕組み |
| `ledger/renders.txt` / `ledger/shots.json` / `ledger/comparison.md` | 155 枚の指紋、撮影の台帳、157 枚を並べた一覧 |

**失うものははっきりしている。** 絵のハッシュは、**版を上げたときに描画が黙って変わったことを捕まえる唯一の手段**だった。`v0.7.0` で `fill(255, 255 * 50 / 100)` が 127.5 から 127 になった件 ([mokume#1018](https://github.com/mokume-metal/mokume/issues/1018)) は `additivewave-1.png` が動いて初めて気付いたもので、**指紋を持っていなければ「そういう絵だった」で通り過ぎていた**。これからは通り過ぎる。

やめたのは、Atlas を**例 1 本ずつが独立した mokume のスケッチである**形へ変えるため。撮影は「1 つの実行ファイルが 157 本を抱えている」ことに強く寄りかかっており、両立させるより畳むほうが素直だと判断した。**消したものは git 履歴に残る**ので、また測りたくなったら取り戻せる。

下の「原典と同じ見た目になっているか」は、畳む前に測った結果の記録である。**もう一度回すことはできない**が、何をどう測って何が分かったかは残す。

## 検証する

<!-- verify:pins -->
| | |
| --- | --- |
| probes | この物差しのコミット (`Package.resolved` が同じツリーにある) |
| mokume | `v0.9.0` / `d88a280b0569f922612ff85dbc9e9f91bbaf6dc2` (`Package.resolved` が固定している) |
| 原典 | `processing/processing-examples` @ `b10c9e9a05a0d6c20d233ca7f30d315b5047720e` ([`ledger/sources.json`](ledger/sources.json) が刻む) |
<!-- verify:end -->

**絵は測らない。** `checks.json` の `renders` は空で、検証が見るのは**ビルドが通るか**と**版の刻印が合っているか**だけである。

<!-- verify:renders -->

<!-- verify:end -->

**先に上流を取る** (`python3 scripts/fetch.py`)。取っていないと**資材を読む 21 本が絵を出せない** — 画像・データ・OBJ を読む例は、資材が無いと原典と違うものを描く。

台帳が再現できることは、上流の版を固定してあるので確かめられる。

```bash
python3 scripts/fetch.py && python3 scripts/ledger.py
git diff --stat ledger/    # 差分が出なければ、同じ版から同じ台帳が組める
```

## 台帳の作り

**原典はリポジトリにコミットしていない。** 254 例のうち 37 例は原作者に著作権が残り (Processing の `examples/README.md` — クレジット行の無いものと Daniel Shiffman のものだけがパブリックドメイン)、`data/` の資材にはライセンス表記が無い。台帳が要るのは中身ではなく「どの例がどの語彙を使うか」なので、上流の版を [`ledger/sources.json`](ledger/sources.json) へ刻んで、中身は `upstream/` (gitignore 済み) へ置く。

**移せるのはパブリックドメインの 217 本まで** (測る対象に入るものに限れば 168 本)。台帳の判定 (読むだけ) は 254 本すべてにかけられるが、移植物は原典の翻訳物なので、クレジット行を持つ 37 本は移さない。`ledger/examples.jsonl` の `license` 欄がその区別を持つ。

| ファイル | 何を持つ | どの版に依存するか |
| --- | --- | --- |
| [`ledger/examples.jsonl`](ledger/examples.jsonl) | 例 → 使う語彙・区分・権利 (254 行) | Processing |
| [`ledger/vocabulary.jsonl`](ledger/vocabulary.jsonl) | 語彙 → mokume の対応 (213 行) | mokume |
| [`ledger/demand.jsonl`](ledger/demand.jsonl) | まだ判定していない語彙と、それを使う例 | 両方 |
| [`ledger/sources.json`](ledger/sources.json) | 上流 3 リポのコミットと mokume の版 | — |

**2 つに割ってあるのは、片方だけ見直せるようにするため。** mokume が上がったら `vocabulary.jsonl` の `checked` が古い行だけを、Processing が上がったら `examples.jsonl` だけを見直す。

`vocabulary.jsonl` に**行が無い語彙は未判定**である。番人の値 (`"unknown"`) を置いていないのは、集計側が数え忘れて静かに嘘の数字を出すのを防ぐため — 未判定を含む例は届く / 届かないのどちらにも数えない。いま未判定が 25 語あるが、どれも `out-of-scope` の例にしか出ないので区分には効いていない。

### 引数で例を選ぶのをやめた

**もとは 1 product に例を N 本持ち、実行ファイルへ渡した引数で選んでいた** (`swift run Atlas Mouse2D`)。書き出しの口 (`--render` / `--frames`) は Ring から写したもので、Ring は Solids から、Solids は Garden から、Garden は Grain から写しており、**5 つを diff すると違うのはコメントと識別子だけ**という状態だった。

**この形では `mokume watch` が通らない。** `run` / `watch` / `mcp` は引数を通さず、宣言順で最初の executable product を無条件に採る (mokume の `SwiftPM.swift`)。つまり**窓の経路は台帳の先頭 1 本に固定**され、手元で 1 本ずつ挙動を見ることができない。product を選ぶ口はオプションにも環境変数にも無い。

**だから例 1 本ずつをパッケージにした。** 1 本が 1 つの実行単位である以上、SwiftPM 上は 157 モジュールになる。これは避けられない。

組み替えで踏んだことが 2 つある:

| 踏んだもの | どうしたか |
| --- | --- |
| **`mokume watch` は `Sources/` 配下しか見ない** — 世代印が `Package.swift` と `<パッケージ>/Sources` の `.swift` だけから作られるので (`SourceStamp.swift`)、パッケージ直下に置くと**保存しても差し替わらない** | `Sources/<型名>/` の慣例配置にした。`mokume new` が作る形と同じ |
| **`@main` は移植の側に付けられない** — 同じモジュールにトップレベルコードがあると衝突する | エントリを生成物の `main.swift` 1 行に分けた。移植のファイルは 1 文字も触っていない |

**モジュール名は例名ではなく型名にした。** `Basics/Arrays/Array` をモジュール名にすると `Swift.Array` を隠す。product 名だけ例名にすれば `mokume run` の側は変わらない。

## 版を上げたときに動いたもの — `v0.6.0` → `v0.7.0`

**155 枚のうち 3 枚が動いた。** 理由は 2 通りで、どちらも mokume 側の変更である。

| 動いた絵 | 理由 |
| --- | --- |
| `colorvariables-1.png` / `pointslines-1.png` | **`setup()` に書いた `translate()` が、警告して無視されるようになった** ([mokume#970](https://github.com/mokume-metal/mokume/issues/970) / [#974](https://github.com/mokume-metal/mokume/issues/974))。図形が原点へ寄る。**原典は `setup()` で描く例なので、`draw()` へ移す書き直しが要る** |
| `additivewave-1.png` | `fill(255, 255 * 50 / 100)` の透かしが 127.5 から 127 になった ([mokume#1018](https://github.com/mokume-metal/mokume/issues/1018))。**目には見えない 1 階調ぶん**で、指紋が無ければ気付けなかった |

**ビルドも 22 箇所で落ちた。** `rotateX(.pi)` のような暗黙メンバ参照が総称の引数で解決できなくなったためで ([mokume#1017](https://github.com/mokume-metal/mokume/issues/1017))、`Float.pi` へ書き換えた。移した先で `.pi` と書くのは、原典が `PI` と書いているからである。

**155 枚の指紋は `v0.6.0` のまま更新されなかった。** 撮り直しに語彙の再判定とブラウザ撮影という人手が要り、版上げとは別の PR へ回していたところで、指紋ごと畳んだ (「測るのをやめたもの」)。**上の 3 枚が、この作品が絵の変化を捕まえた最後の記録である。**

## 版を上げたときに動いたもの — `v0.7.0` → `v0.9.0`

**157 枚とも 1 行も直さずに建った。** `v0.7.0` のときに 22 箇所を `Float.pi` へ書き換えたような手直しは、この版上げでは 1 つも要らなかった。`scripts/api-diff.py` が挙げた「直さないと通らないもの」23 件は、どれも `@MainActor` の隔離が外れた変化で、Atlas が触れている口には当たっていない。

```
建った 157 / 157  失敗 0
```

**絵が動いたかどうかは測っていない。** 指紋は [#39](https://github.com/mokume-metal/works/pull/39) で畳んであるので、ここで言えるのは**建つことと版の刻印が揃っていること**だけである — それがこの作品の検証の全部になったのは、承知のうえの決定である (「測るのをやめたもの」)。

**動いているはずではある。** `v0.9.0` は[下の 4 つ](#mokume-へ戻したもの)をまとめて塞いでおり、そのうち 3 つは Atlas 自身が 157 本を並べて見つけたものである — 色 ([#911](https://github.com/mokume-metal/mokume/issues/911)・32 本が「形は合うが色が違う」に落ちていた)、太さ 1 の線 ([#912](https://github.com/mokume-metal/mokume/issues/912)・9 本)、光の明るさ ([#913](https://github.com/mokume-metal/mokume/issues/913)・13 本)。**一致率が上がったことを数で言うには、語彙の台帳を `v0.9.0` で見直す必要がある** ([#77](https://github.com/mokume-metal/works/issues/77))。

**作品の側では、この版上げで何が動いたかを画素まで追ってある。** 時計を読まない 4 本 (Garden / Grain / Ring / Solids) は同じ版で 2 回撮ると 1 ビットも違わないので、版差をまるごと取り出せた — [Garden](https://github.com/mokume-metal/works/blob/main/Garden/README.md#v090-で動いたもの) が背景 1 画素で色の変化を、[Solids](https://github.com/mokume-metal/works/blob/main/Solids/README.md#v090-で動いたもの) が球に出た線を記録している。

### 語彙の台帳を `v0.9.0` で見直した

213 行が全部 `checked: "0.6.0"` のままだったので、[#77](https://github.com/mokume-metal/works/issues/77) で 1 行ずつ見直した。**届いている 145 行は API 一覧との突き合わせで足り**、`same` 14 行は同名が全部残り、`renamed` / `drop` の指し先も全部残っていた (退行ゼロ)。

**動いたのは 7 行。**

| 行 | | |
| --- | --- | --- |
| `noLoop` / `loop` / `redraw` | `none` → `same` | [#900](https://github.com/mokume-metal/mokume/issues/900) が塞がった。**止まってから `loop()` / `redraw()` を呼べるのは入力の呼び出しからだけ**で、`draw()` の中や別の Task から頼んでも効かない (最小のスケッチで実測) |
| `DOWN` / `UP` / `ENTER` | `bend` → `renamed` | `Key.arrowDown` ほか。`v0.6.0` で Int から Key 型になったことへの追随 ([#30](https://github.com/mokume-metal/works/issues/30)) |
| `CODED` | `bend` → `drop` | `keyCode` が `Key?` を直に返すので、文字にならないキーの印を挟む形そのものが要らない |

**色・太さ 1 の線・光の明るさで判定は動かなかった。** [#911](https://github.com/mokume-metal/mokume/issues/911) / [#912](https://github.com/mokume-metal/mokume/issues/912) / [#913](https://github.com/mokume-metal/mokume/issues/913) が塞いだのは**同じ名前から出てくる絵**であって、名前が届くかどうかではない。`colorMode` は `v0.9.0` でも口が無く (#911 が変えたのは数と色の対応で、目盛りではない)、`lightSpecular` / `specular` も光の側へ鏡面反射の色を渡す口が無いままである。**台帳は「語彙が届くか」しか測らないので、一致率が上がったことはここからは言えない。**

**据え置いた行にも実測の根拠を足した。** `frameRate` は走っている最中に `settings.frameRate` へ代入しても黙って無視される — 値は書き換わるが枚数は 60 のままである。

## mokume へ戻したもの

台帳が出した重みは、既に立っている実需の**順位**の材料になる。新しく起票するのは、実測で 1 本以上踏んだものに限る — 机上の数字だけで起票すると「一般にそういう API があるから」に落ちる (ADR-0022 決定 6 が禁じている)。

**初めに戻した 6 本は全部閉じた** (4 本が `v0.6.0`・1 本が `v0.8.0`・1 本が `v0.9.0`)。**消さずに残す** — 何を踏んで、どの版で塞がったかは記録である。下の 2 本は `v0.9.0` の再判定で実測して足したもの。

| 踏んだもの | | いま |
| --- | --- | --- |
| `map` / `radians` が無い — 台帳では **33 例 / 23 例**を止める。`Basics/Math/Map` を移して踏んだ | [mokume#883](https://github.com/mokume-metal/mokume/issues/883) | **閉じた** (`v0.6.0`) |
| 帯・扇・四角の並べ方が無い — `QUADS` 8 例・`QUAD_STRIP` 6 例 | [mokume#882](https://github.com/mokume-metal/mokume/issues/882) | **閉じた** (`v0.6.0`)。ただし入ったのは**帯と扇だけ**で、四角の 14 例は止まったまま |
| 入力が出来事として届かない — `mousePressed` 18 例・`keyPressed` 11 例・`mouseDragged` 6 例 | [mokume#723](https://github.com/mokume-metal/mokume/issues/723) | **閉じた** (`v0.6.0`)。27 本が動くようになった |
| 色空間を切り替える口が無い — `colorMode` 12 例 | [mokume#778](https://github.com/mokume-metal/mokume/issues/778) | **入った** (`v0.6.0`)。ただし**目盛りは張り替えられない**ので `colorMode` は `bend` のまま |
| **`SketchApplication` が投げる失敗を、外から人に見せられない** — `RenderFailure.message` が internal なので、`Sketch.main()` と同じ文面が書けない | [mokume#899](https://github.com/mokume-metal/mokume/issues/899) | **閉じた** (09-08 → `v0.8.0`) |
| **進行を止める口が無い** — `noLoop` 18 例・`redraw`。`Basics/Structure/NoLoop` がここで止まった | [mokume#900](https://github.com/mokume-metal/mokume/issues/900) | **閉じた** (09-15 → `v0.9.0`)。`noLoop` / `loop` / `redraw` が同名で入り、**12 本が `blocked` から出た** |
| **走っている最中に枚数を変える口が無い** — `frameRate` **20 例**。`settings.frameRate` への代入は通って値も残るが、枚数だけ変わらない | [mokume#1323](https://github.com/mokume-metal/mokume/issues/1323) | 開いたまま。`frameRate` は `bend` のまま |
| **`redraw()` / `loop()` を呼び出しの外から頼むと、走っている最中でも「the sketch is not running」と断られる** — 断り方が事実と違う | [mokume#1322](https://github.com/mokume-metal/mokume/issues/1322) | 開いたまま。判定には効かない (口はある) |

157 本を並べて撮って、**台帳では原理的に見えなかった差が 4 つ出た**。どれも語彙の名前は当たっていて、絵だけが違う。

**この 4 つは、`v0.9.0` までに全部閉じた。** 閉じた日がどのリリースの間に挟まるかで、効き始める版が決まる (`v0.8.0` = 2026-09-12 / `v0.8.1` = 09-14 04:39 / `v0.9.0` = 09-21)。

| 踏んだもの | | いま |
| --- | --- | --- |
| **書き出しが Display P3 で刻まれ、同じ数から違う色が出る** — `background(204,153,0)` が `213,150,0` になる。灰色は 1 画素も違わないので気付かれにくい。**32 本が「形は合うが色が違う」に落ちる** | [mokume#911](https://github.com/mokume-metal/mokume/issues/911) | **閉じた** (09-15 → `v0.9.0`)。数を sRGB の原色として受けるようになった。works の作品側では [Garden](https://github.com/mokume-metal/works/blob/main/Garden/README.md#v090-で動いたもの) が背景 1 画素で追えている |
| **太さ 1 の線が半画素ずれた画素に載る** — p5 は 2 列に 77+77、mokume は 1 列に 153。**半画素ずらすと 99.9% 合う**ので、正体は言い切れる。9 本がこれだけで落ちる | [mokume#912](https://github.com/mokume-metal/mokume/issues/912) | **閉じた** (09-14 17:41 → `v0.9.0`)。画素の格子が「塗りは角、線は中心」へ揃った ([ADR-0039](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0039-pixel-grid-and-edge-antialiasing.md)) |
| **同じ光の指定で、Processing より明るい陰影が出る** — `directionalLight` で 59 対 103。立体を扱う 13 本がまとめて落ちる | [mokume#913](https://github.com/mokume-metal/mokume/issues/913) | **閉じた** (09-14 17:59 → `v0.9.0`)。`v0.9.0` のリリースノートは破壊的変更として挙げていない |
| **半透明の合成が線形空間で起きる** — `fill(255, 204)` が 214 ではなく 232 になる | [mokume#669](https://github.com/mokume-metal/mokume/issues/669) へ材料として | **閉じた** (09-08 → `v0.8.0`) |

**どれも「一致率が上がったはず」であって、上がったことは測っていない。** 原典との画素の一致を出す仕組みは [#39](https://github.com/mokume-metal/works/pull/39) で畳んであり、この版上げでは**ビルドが通ることと版の刻印しか見ていない**。下の 107 本の表は `v0.6.0` までの記録である。

出来事の口 ([#723](https://github.com/mokume-metal/mokume/issues/723)) と進行を止める口 ([#900](https://github.com/mokume-metal/mokume/issues/900)) には、157 本を移して分かった**段階の違い**を書き足した — 同じ「口が無い」でも、ポーリングで書き直せるもの・前のフレームを覚えれば作れるもの・**例そのものが移せない**ものの 3 段階がある。

### 絵の差の 4 つは、`v0.6.0` でも埋まっていない

**語彙の判定は大きく動いたのに、原典との画素の一致はほとんど動かなかった。**

3 つの版すべてで数を出した 107 本で並べる (11 本は**原典どうしが食い違う**と分かって
数を出さなくなった。[#18](https://github.com/mokume-metal/works/issues/18))。

| | 平均一致率 | 動かない | 下がった | 上がった |
| --- | ---: | ---: | ---: | ---: |
| `v0.5.0` | 88.91% | — | — | — |
| `v0.6.0` + 書き直し | **89.80%** | 90 本 | 13 本 | 4 本 |
| 透明も差に入れたいま | **88.80%** | 102 本 | 5 本 | 0 本 |

`v0.6.0` で下がった 13 本は、**塗りの縁の均しが変わったため**である。`v0.6.0` は縁が半端な
画素に載るときに被覆どおり均すようになった ([works#22](https://github.com/mokume-metal/works/pull/22)
で切り分けた) — **絵としては素直になったが、p5 の均し方と揃ったわけではない**ので、
縁の画素を多く持つ例ほど差が開く。

**最後の 1% は mokume が変わったのではなく、測り方の甘さが取れたぶんである。**
差の取り方が alpha を見ておらず、**何も塗っていない透明な面と `background(0)` の黒が
完全一致になっていた** ([#17](https://github.com/mokume-metal/works/issues/17))。
`Basics/Web/LoadingImages` の「100%」がそれで、いまは 0.0% と出る。

**上の 4 つが閉じるまで、この数字は動かない。** 一致を止めているのは語彙ではなく、
Display P3・線の載り方・光の強さ・線形空間での合成だからである。**台帳の判定と画素の一致は
別の物差しで、片方が良くなっても片方は動かない** — 今回それが実測で出た。
