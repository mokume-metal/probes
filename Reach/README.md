# Reach — Processing / p5.js のよく使う口に mokume v0.11.1 が届くか

**作品ではなく物差しである。** Atlas が Processing の *Examples* を全数で当てて「どの欠けが何本の例を止めるか」を数えるのに対し、Reach は *リファレンス* の側から**作品を作るときにまず使う口**を百余り並べ、1 口 1 タイルで実際に mokume で書いてみる。

Atlas の台帳は例に出てくる語彙しか見ない。角の丸い `rect`・`arc` の閉じ方・1 行の `bezier()`・`randomGaussian`・`cursor`・`filter(THRESHOLD)`・`erase` のように、**例には出てこないが授業や入門書では最初の数週で使う口**は、Atlas では測れていなかった。

## 何をしているか

- **口 1 つ = タイル 1 枚。** 一覧は [`Sources/Reach/Entries.swift`](Sources/Reach/Entries.swift) と区分ごとのファイルの 1 か所だけにあり、窓もテストもこの README の表も同じ一覧から起こす。
- **判定は Atlas と同じ 7 区分** (`Atlas/README.md`「判定の意味」)。上の 4 つが届き、下の 3 つが穴。
- **書けたものは実際に書いてある。** コンパイルが通ること自体が「口がある」の証明になる。呼ぶと走りが変わる口 (`noLoop`・`exit`・`save`) は、本体を型だけ確かめて呼ばない (`unreached`)。
- **書けないものは書けないまま残す。** `none` のタイルは口を呼ばず、赤い × を刷る — 動くように作り替えると、止まったこと自体が消えるため (Atlas と同じ態度)。
- **面の外に書き足したもの** (`write`) は [`Sources/Reach/Support.swift`](Sources/Reach/Support.swift) 1 つに集めた。このファイルの長さが「よく使う口を書くのに mokume の外へどれだけ書き足すか」の答えになる。

| 確かめ方 | 何を通るか | 何で見るか |
| --- | --- | --- |
| `mokume run .` | 窓の経路。タイルごとに `createGraphics` の面を持ち、縮めて貼る | 目で見る (16 列で並ぶ) |
| `swift test` | 窓を出さない経路。`SketchRuntime` で 1 枚ずつ本体の面へ、もう 1 度は窓と同じ格子で描く | 絵のタイルが下地以外の画素を置くか |

```bash
mokume run .                       # 窓で並べて見る
swift test                         # 窓を出さずに描いて確かめる
REACH_DUMP=/tmp/reach swift test   # タイルと格子を PNG で書き出す
REACH_WRITE_README=1 swift test    # 一覧を直したら、下の表を書き直す
```

**`swift test` が見ているのは「届くと判定した口が、描いて何かを置くか」まで。** 手本と同じ画素が出るかは見ない (mokume は手本の名前と引数の順序までを採り、画素は約束しない — mokume ADR-0020 決定 1 の改訂)。約束の破れを突くのは Probe・Drift の仕事である。

## 結果 — mokume `v0.11.1`

<!-- reach:summary -->
| 判定 | 件数 | |
| --- | ---: | --- |
| `same` | 55 | 同名・同じ引数の形がある |
| `renamed` | 25 | 口はあるが別名・別の形 |
| `host` | 7 | Swift・Foundation の語彙で当たる |
| `drop` | 2 | mokume では要らない |
| `write` | 15 | 面の外に書けば済む (`Support.swift`) |
| `bend` | 8 | 書けるが歪む |
| `none` | 14 | 口が無い |
| **合計** | **126** | |
<!-- /reach:summary -->

件数は一覧から起こしている (上の表は手で書かない)。

### 分かったこと

- **形・色・変換・字・3D の原形は、ほぼ手本の綴りのまま届く。** `rect` から `torus` まで、授業の 1〜2 週目に並ぶ口で `none` は無い。
- **穴は「1 行で済むはずの便利な口」に寄っている。** 1 行の `bezier()` / `curve()`・角の丸い `rect`・`dist` / `mag`・`randomGaussian`・`scale(s)` — どれも面の上の口を組めば書けるが、手本の 1 行が数行になる。
- **`none` は環境・画像の加工・3D の材質に固まっている。** 窓の大きさ (`resizeCanvas` / `fullscreen` / `cursor`)・絵を抜く (`erase`)・絵を縮める (`resize`)・書体と SVG の読み込み (`loadFont` / `loadShape`)・鏡の反射と面の向きの塗り (`specularMaterial` / `normalMaterial`)・u, v の扱い (`textureMode` / `textureWrap`)。
- **手本と同じ名前で、別の体系の数を運ぶ口がある。** `deltaTime` は秒 (手本はミリ秒) で、p5 のコードを写すと黙って 1000 倍ずれる。`mouseButton` は `LEFT` / `RIGHT` ではなく番号を返す。
- **`filter(INVERT)` に当たる `.invert()` は線形の値で反転する。** 灰 128 は 127 ではなく 229 になる。色の計算を線形で行う規範 (mokume ADR-0011) から来るもので、手本と画素が違うことは mokume の約束の外にある。

## mokume へ戻したもの

**「一般にそういう API があるから」は起票の理由にしなかった。** mokume は機能を実需で足すと決めていて ([ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md) 決定 6)、Atlas の計数だけを根拠にした [mokume#902](https://github.com/mokume-metal/mokume/issues/902) (QUADS) は not planned で閉じている。Reach で見つけた穴は、次のどちらかを満たすものだけを起票した (probes の [ADR-0004](../docs/decisions/0004-reach-reference-coverage.md))。

- **works の作品 2 本以上が、同じものを手で書いている** — mokume ADR-0020 が `lerp` / `constrain` を足したときの先例と同じ数え方。Reach の `write` / `bend` / `none` の行を、mokume-metal/works の 13 作品 (`22387ce`) と突き合わせて数えた
- **既にある規範から導ける欠け** — 手本と名前・値の体系がずれていて、理由がどこにも書かれていないもの (mokume ADR-0020 決定 1)

| mokume | 型 | 何を戻したか | 根拠 |
| --- | --- | --- | --- |
| [#1551](https://github.com/mokume-metal/mokume/issues/1551) | Feature | `beginShape(QUADS)` | 5 作品 (Apex・Cast・Prism・Quarry・Tempo) が四角を三角形 2 枚へ手で割っている |
| [#1552](https://github.com/mokume-metal/mokume/issues/1552) | Feature | `lerpColor` | 2 作品 (Apex・Grain)。mokume ADR-0033 決定 7 が「足す日の表」を用意していた |
| [#1553](https://github.com/mokume-metal/mokume/issues/1553) | Feature | `fill(rgb, alpha)` | 3 作品 (Cast・Tempo は 1 字違わず同じ `Palette.fade`、Apex は成分に割る) |
| [#1554](https://github.com/mokume-metal/mokume/issues/1554) | Feature | `millis()` | 4 作品 (Apex・Cast・Quarry・Tempo) が `Date()` の差で準備の時間を測っている |
| [#1555](https://github.com/mokume-metal/mokume/issues/1555) | Bug | `deltaTime` の単位・`mouseButton` の値 | 同じ名前で別の体系の数 — `keyCode` を直した mokume ADR-0034 と同じ形 |
| [#1556](https://github.com/mokume-metal/mokume/issues/1556) | Task | `isKeyDown`・`isMousePressed`・`textOutline`・`makeShader`・`beginRecord` ほかの名前 | 手本とずれていて理由が見当たらない |
| [#1283](https://github.com/mokume-metal/mokume/issues/1283#issuecomment-5815642122) (コメント) | — | `norm` / `smoothstep` | 既存の 2 作品に加え、Grain・Quarry・Apex も手で書いていた |

### 起票しなかったもの

| 穴 | 起票しなかった理由 |
| --- | --- |
| `none` の口 (`resizeCanvas`・`cursor`・`erase`・`loadFont`・`specularMaterial`・`textureMode` ほか) | works の作品で手で書いたものが 0〜1 本。実需が来たら作品の側から立つ |
| `dist` / `mag` / `normalize` / `heading` / `fromAngle` (`PVector` 相当) | 6〜7 作品が使うが、ほとんどは Swift の `simd` で足りている。自分で書いたのは 2 作品ずつで、`PVector` 相当を面に持つかは設計の判断が要る |
| `scale(s)` | 2 作品が `scale(e, e)` と同じ値を 2 度渡しているだけで、手で書いたものは無い |
| 3 次元の `line` / `point` | 2 作品が `beginShape(.lines)` で書けていて、歪みは出ていない |
| 角の丸い `rect`・`arc` の閉じ方・1 行の `bezier()` / `curve()`・`randomGaussian` | works で 0 本 |
| `colorMode` | 持たないと決めている (mokume ADR-0033 決定 4) |
| `.invert()` の色 | 線形で計算する規範から来るもので、手本と画素が違うことは約束の外 (mokume ADR-0020 決定 1 の改訂) |

## 全件

<!-- reach:table -->
#### 構造と環境

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `setup() / draw()` | `same` | setup() / draw() |  |
| `noLoop() / loop()` | `same` | noLoop() / loop() / redraw() | v0.9.0 で入った (mokume#900) |
| `frameCount` | `same` | frameCount |  |
| `deltaTime` | `bend` | deltaTime * 1000 | 同じ名前で単位が違う (手本はミリ秒、mokume は秒)。p5 のコードを写すと黙って 1000 倍ずれる — [mokume#1555](https://github.com/mokume-metal/mokume/issues/1555) |
| `millis()` | `bend` | time * 1000 | `time` はそのフレームの時刻で、フレームの途中では進まない。処理の時間を測る使い方 (`millis() - t0`) は書けず、works の 4 作品が Date() で書いている — [mokume#1554](https://github.com/mokume-metal/mokume/issues/1554) |
| `frameRate(fps)` | `bend` | SketchSettings(frameRate:) | 起動のときだけ決まる。走っている最中の代入は黙って効かない — [mokume#1323](https://github.com/mokume-metal/mokume/issues/1323) |
| `createCanvas(w, h)` | `renamed` | SketchSettings(width:height:) | Processing の size() |
| `width / height` | `same` | width / height | Float で返る |
| `pixelDensity(d)` | `renamed` | SketchSettings(pixelDensity:) | 起動のときだけ決まる |
| `resizeCanvas() / windowResized()` | `none` | — | 面の大きさは起動のときに決まり、窓の大きさが変わったことを受ける口も無い |
| `fullscreen()` | `none` | — | Processing の fullScreen()。SketchSettings に全画面の指定が無い |
| `cursor() / noCursor()` | `none` | — | カーソルの形を変える口・隠す口が無い (一人称で捕まえる話は mokume#1144) |
| `second() / hour() / year()` | `write` | clockField(.second) | 壁時計の値は Foundation の Calendar が持つ |
| `push() / pop()` | `same` | push() / pop() |  |
| `exit()` | `host` | Foundation.exit(0) | 後始末を通らずに止まる。窓を閉じる口は mokume に無い |

#### 2D の形

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `point()` | `same` | point(x, y) |  |
| `line()` | `same` | line(x1, y1, x2, y2) |  |
| `rect()` | `same` | rect(x, y, w, h) |  |
| `rect(x, y, w, h, r)` | `write` | roundedRect (Support) | 角を丸める 5〜8 番目の引数が無い。quadraticVertex で書けるが、角は円弧でなく 2 次曲線になる |
| `square()` | `same` | square(x, y, s) |  |
| `ellipse() / circle()` | `same` | ellipse / circle |  |
| `arc()` | `same` | arc(x, y, w, h, start, stop) |  |
| `arc(…, PIE / CHORD / OPEN)` | `none` | — | 閉じ方の 7 番目の引数が無い。扇 (PIE) の形しか描けない |
| `triangle()` | `same` | triangle(…) |  |
| `quad()` | `same` | quad(…) |  |
| `bezier()` | `write` | bezier (Support) | 1 行で曲線を描く口が無い。beginShape + bezierVertex の 4 行になる |
| `curve()` | `write` | curve (Support) | 1 行で描く口が無い。curveVertex 4 つで書く |
| `bezierPoint() / curvePoint()` | `write` | bezierPoint (Support) | 曲線の上の点・接線を返す口が無い |
| `beginShape() / vertex()` | `same` | beginShape / vertex / endShape(.close) |  |
| `beginShape(TRIANGLE_STRIP)` | `renamed` | beginShape(.triangleStrip) | POINTS / LINES / TRIANGLES / TRIANGLE_FAN も同じ形 |
| `beginShape(QUADS / QUAD_STRIP)` | `bend` | beginShape(.triangles) | 四角の並べ方が無い。2 枚の三角形に割って並べ直す。works の 5 作品が同じ割り方を手で書いている (mokume#902 は実需待ちで閉じていた) — [mokume#1551](https://github.com/mokume-metal/mokume/issues/1551) |
| `beginContour()` | `same` | beginContour / endContour |  |
| `bezierVertex() / quadraticVertex()` | `same` | bezierVertex / quadraticVertex |  |
| `curveVertex()` | `same` | curveVertex |  |
| `rectMode(CENTER)` | `renamed` | rectMode(.center) | ellipseMode / imageMode も同じ ShapeMode |
| `strokeWeight()` | `same` | strokeWeight |  |
| `strokeCap() / strokeJoin()` | `renamed` | strokeCap(.round) / strokeJoin(.bevel) |  |
| `noSmooth()` | `none` | — | 縁の均しを切る口が無い (Atlas の Pixelate ほかで踏んだ) |
| `createShape() / shape()` | `renamed` | createShape { … } / shape(_:x:y:) | 形を組む手順を閉包で渡す。PShape の子 (getChild / addChild) や setFill は無い |

#### 色

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `background() / fill() / stroke()` | `same` | 同名。1〜4 個の数 | 目盛りは 0–255 で手本と同じ。混ぜる空間は線形なので、半透明の重ねは手本と色が違う |
| `noFill() / noStroke()` | `same` | noFill() / noStroke() |  |
| `color() / "#ff8800"` | `renamed` | color(r, g, b) / color(hex: 0xff8800) | 文字列の色は受けない (mokume#745 で実需待ち) — [mokume#745](https://github.com/mokume-metal/mokume/issues/745) |
| `fill(rgb, alpha)` | `write` | fill(color, alpha) (Support) | Processing の、色の値 1 つに不透明度を添える形が無い。works の 3 作品が色を薄める口を手で書いている — [mokume#1553](https://github.com/mokume-metal/mokume/issues/1553) |
| `red() / hue() / brightness()` | `same` | red / green / blue / alpha / hue / saturation / brightness |  |
| `colorMode(HSB)` | `bend` | color(hue:saturation:brightness:) | 目盛りを張り替える口は持たないと決めている (mokume ADR-0033 決定 4)。HSB で書く行ごとにラベルを付ける |
| `lerpColor()` | `write` | lerpColor (Support) | 面に無い。混ぜる空間が違うので、書いても中間色は手本と変わる。works の 2 作品が手で書いている (mokume#745 は実需待ちで閉じていた) — [mokume#1552](https://github.com/mokume-metal/mokume/issues/1552) |
| `clear()` | `renamed` | background(LinearRGBA.transparent) |  |
| `erase() / noErase()` | `none` | — | 描いたところを透明へ抜く口が無い。blendMode(.replace) の α 0 は mokume#1542 で不具合として扱われている |
| `blendMode(ADD)` | `renamed` | blendMode(.add) | BLEND / ADD / MULTIPLY / SCREEN / DIFFERENCE ほか 10 種 |

#### 変換

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `translate() / rotate()` | `same` | translate / rotate |  |
| `scale(x, y)` | `same` | scale(x, y) |  |
| `scale(s)` | `write` | scale(s, s) | 引数 1 つの一様な拡大が無い |
| `shearX() / shearY()` | `same` | shearX / shearY |  |
| `applyMatrix()` | `renamed` | applyMatrix(Transform) | 6 つ / 16 個の数ではなく、Transform の値を組んで渡す |
| `resetMatrix()` | `same` | resetMatrix() |  |

#### 画像と画素

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `loadImage()` | `same` | try loadImage(path) | 失敗を throws で返す。資材を置かないので、タイルでは画素から作った絵を使う |
| `image()` | `same` | image(img, x, y, w, h) |  |
| `image(img, dx, dy, dw, dh, sx, sy, sw, sh)` | `same` | 同じ 9 引数 | Processing の copy() もこの形で当たる |
| `imageMode(CENTER)` | `renamed` | imageMode(.center) |  |
| `tint() / noTint()` | `same` | tint / noTint |  |
| `createImage()` | `same` | try createImage(w, h) | 形式 (RGB / ARGB / ALPHA) の引数は取らない |
| `get() / set()` | `same` | get(x, y) / set(x, y, c) | 領域を切り出す get(x, y, w, h) は無い |
| `pixels[] / loadPixels()` | `bend` | pixels[x, y] | 1 次元の並び (pixels[y * width + x]) が無く、2 次元の添字で読む。Image には pixels 自体が無い |
| `updatePixels()` | `drop` | — | pixels へ書いた時点で面へ届くので要らない |
| `filter(GRAY / INVERT / BLUR)` | `renamed` | effects([.monochrome(), .invert(), .blur(radius:)]) | 面ごとの効果として当たる。Image 1 枚に掛ける口ではない |
| `filter(THRESHOLD / POSTERIZE / ERODE / DILATE)` | `write` | threshold (Support) | 効果に閾値・階調の削減・膨張収縮が無い。画素を 1 つずつ書く |
| `img.mask()` | `write` | mask (Support) | get / set で画素を移し替えれば書ける |
| `img.resize()` | `none` | — | 絵そのものの大きさを変える口が無い。image() で置く大きさを変えるだけなら書ける |
| `createGraphics()` | `same` | try createGraphics(w, h) → beginDraw / endDraw |  |
| `save() / saveCanvas()` | `same` | save(path) | 本体の面だけ。createGraphics の面を書き出す口は無い |
| `saveFrame("f-####.png")` | `renamed` | beginRecord("f-####.png") / endRecord() | 連番と .mov を綴りで分ける |

#### 字

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `text() / textSize()` | `same` | text / textSize |  |
| `textAlign(CENTER, CENTER)` | `renamed` | textAlign(.center, .center) |  |
| `text(s, x, y, w, h)` | `same` | text(s, x, y, w, h) → TextFlow | textWrap(WORD / CHAR) も同名 |
| `textWidth() / textAscent()` | `same` | textWidth / textAscent / textDescent / textLeading |  |
| `textStyle(BOLD)` | `renamed` | textStyle(.bold) |  |
| `textFont("Helvetica")` | `same` | textFont(name) | この環境にある書体の名前で引く |
| `loadFont("x.ttf")` | `none` | — | 書体ファイルを読む口が無い。字形が環境で決まる (Atlas で 6 本を止める) |
| `font.textToPoints()` | `renamed` | textOutline(s, x, y) → [TextContour] | 点の間隔 (sampleFactor) は取らない — [mokume#1556](https://github.com/mokume-metal/mokume/issues/1556) |

#### 数

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `random() / randomSeed()` | `same` | random(low, high) / randomSeed |  |
| `random(array)` | `host` | array.randomElement() | 手本の乱数列 (randomSeed) には乗らない |
| `randomGaussian()` | `write` | randomGaussian (Support) | 正規分布の乱数が無い。random() から Box–Muller で書く |
| `noise() / noiseSeed() / noiseDetail()` | `same` | noise(x, y, z) / noiseSeed / noiseDetail |  |
| `map() / constrain() / lerp()` | `same` | map / constrain / lerp | constrain / lerp は v0.11.0 で入った |
| `dist() / mag()` | `write` | dist / mag (Support) | 面に無い。simd_distance は import simd を要し、アンブレラは通さない |
| `sq() / norm()` | `write` | sq / norm (Support) |  |
| `abs() / floor() / pow() / sqrt()` | `host` | Swift の abs / floor / pow / squareRoot | floor / pow は Foundation を import する |
| `sin() / cos() / atan2()` | `same` | sin / cos / tan / asin / acos / atan / atan2 | アンブレラが名指しで通す 7 本 (mokume ADR-0020 決定 7) |
| `radians() / degrees()` | `same` | radians / degrees |  |
| `PI / TWO_PI / HALF_PI` | `host` | Float.pi |  |
| `angleMode(DEGREES)` | `drop` | — | 持たないと決めている。単位は呼んだ 1 行から読めるべき (mokume ADR-0020 決定 7 の改訂) |
| `createVector() / PVector` | `bend` | SIMD2<Float> / SIMD3<Float> | 型は当たるが、add / mult は演算子で書き、normalize / limit / setMag / heading / fromAngle / rotate は 1 つも無い |
| `PVector.normalize() / limit() / heading()` | `write` | extension SIMD2 (Support) |  |
| `nf() / str() / int()` | `host` | String(format:) / String() / Int() |  |
| `shuffle() / sort() / append()` | `host` | Array の shuffled / sorted / append |  |

#### 入力

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `mouseX / mouseY` | `same` | mouseX / mouseY |  |
| `pmouseX / pmouseY` | `same` | pmouseX / pmouseY |  |
| `mouseIsPressed` | `renamed` | isMousePressed | Processing の変数 mousePressed は関数と同名になり Swift では並べられない。p5 の mouseIsPressed でもない綴りになっている — [mokume#1556](https://github.com/mokume-metal/mokume/issues/1556) |
| `mouseButton === LEFT` | `renamed` | mouseButton (Int) | 同じ名前で値の体系が違う。LEFT / RIGHT / CENTER ではなく番号 (0 = 主釦) — [mokume#1555](https://github.com/mokume-metal/mokume/issues/1555) |
| `mousePressed() / mouseReleased() / mouseClicked()` | `same` | 同名の関数を書く | mouseMoved() も同名。v0.6.0 で入った (mokume#723) |
| `mouseDragged()` | `renamed` | mouseDragged(deltaX:deltaY:) | 引数で動いた量を受ける |
| `mouseWheel(event)` | `renamed` | mouseWheel(deltaX:deltaY:) |  |
| `doubleClicked()` | `none` | — | 2 度押しを受ける口が無い。mouseClicked() の間隔を自分で測れば書ける |
| `key / keyCode` | `renamed` | key (String) / keyCode (Key?) | keyCode は手本の数ではなく Key の値 (mokume ADR-0034) |
| `keyIsDown(LEFT_ARROW)` | `renamed` | isKeyDown(.arrowLeft) | 引数を Key で受けるのは mokume ADR-0034。語順が手本と違う理由は見当たらない — [mokume#1556](https://github.com/mokume-metal/mokume/issues/1556) |
| `keyPressed() / keyReleased() / keyTyped()` | `same` | 同名の関数を書く |  |
| `keyIsPressed` | `write` | keyPressed / keyReleased で数える | 何かのキーが押されているかを読む値が無い。Processing は変数の keyPressed |

#### 3D

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `box()` | `same` | box(size) / box(w, h, d) | WEBGL / P3D の指定は要らない (描き方のモードを持たない) |
| `sphere() / ellipsoid()` | `same` | sphere(r) / ellipsoid(x, y, z) |  |
| `plane() / cone() / cylinder() / torus()` | `same` | 同名 |  |
| `sphere(r, detailX, detailY)` | `renamed` | sphere(r, detail:) | 細かさは 1 つの数。Processing の sphereDetail() も同じ |
| `3 次元の line() / point()` | `bend` | beginShape(.lines) + vertex(x, y, z) | line / point は 2 次元の引数しか取らない。1 行が 4 行になる (Atlas の MoveEye) |
| `camera() / perspective() / ortho()` | `same` | 同名・同じ引数 |  |
| `frustum()` | `none` | — | 視錐台を 6 つの数で渡す口が無い |
| `orbitControl()` | `same` | orbitControl() |  |
| `lights() / ambientLight() / directionalLight()` | `same` | 同名 |  |
| `pointLight() / spotLight()` | `same` | 同名 (spotLight の角は angle:) | spotLight の集中度 (concentration) は渡せない |
| `specularMaterial() / specular()` | `none` | — | 鏡の反射の色を指定する口が無い。shininess / metalness / emissive はある |
| `shininess() / emissiveMaterial()` | `renamed` | shininess / emissive / metalness |  |
| `normalMaterial()` | `none` | — | 面の向きを色にする塗りが無い (断片の側では書ける) |
| `texture()` | `same` | texture(img) |  |
| `textureMode(NORMAL) / textureWrap(REPEAT)` | `none` | — | u, v の目盛りと繰り返しを選ぶ口が無い |
| `loadModel() / model()` | `same` | try loadModel(path) / model(m) | OBJ だけ。loadShape (SVG) は無い |
| `loadShape("a.svg")` | `none` | — | SVG を読む口が無い (Atlas で 6 本を止める) |

#### データと部品

| 手本 | 判定 | mokume | 注 |
| --- | --- | --- | --- |
| `loadStrings() / loadJSON()` | `host` | String(contentsOf:) / JSONDecoder | Foundation で読む。スケッチの置き場から読む口 (資材の場所) は mokume に無い |
| `createSlider()` | `renamed` | @Param | DOM の部品ではなく、外から動かせる値として名乗る (mokume ADR-0013) |
<!-- /reach:table -->

## 版を上げたら

1. `python3 scripts/api-diff.py` で増えた口を見て、`none` / `write` / `bend` の行が届くようになっていないかを確かめる。
2. 届いたものは一覧の判定と書き方を直し、`Support.swift` から書き足しを消す。
3. `REACH_WRITE_README=1 swift test` で表を書き直し、上の「結果」の見出しの版と数を直す。
