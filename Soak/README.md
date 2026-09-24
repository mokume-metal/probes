# Soak — mokume v0.11.1 を長く回したときの「メモリ・重さ・落ちる」を突く

**作品ではなく物差しである。** Probe・Drift・Routine は「約束された**絵**が出るか」を比べてきた。
Soak が見るのは**資源**である。

- 1 枚ごとに増えて減らないメモリ
- 仕事の量に見合わない時間
- プロセスごと止まる口

どれも 1 枚目の絵には出ない。長く回すか、極端な値を渡してはじめて出る。

## 何をしているか

**候補 1 件を、同じ仕事になるはずの 2 つの経路で回す。**

- **左 (`suspect`)** は、疑っている口を通す。
- **右 (`reference`)** は、同じ量の仕事を疑いの入らない書き方で作る。
  - 例: 開いたままの `beginShape` ↔ 毎フレーム開いて閉じる。
  - 例: `textSize` で脈打つ字 ↔ 大きさを固定して `scale` で脈打つ字。
  - 例: 多角形の塗り ↔ 同じ形を中心からの扇で置く。

比べるのは絵ではなく、**フレームを重ねたときの増え方と時間**である。

| 確かめ方 | 何を通るか | 何で見るか |
| --- | --- | --- |
| `mokume run .` | 窓の経路。1 度に 1 候補の 1 経路だけを自前の `SketchRuntime` で回し、その絵を貼る | 目で見る。footprint と GPU の増分の折れ線、直近 60 枚の増え方、1 枚の時間 |
| `swift test` | 窓を出さない経路。経路ごとに `SketchRuntime` を組み、N 枚回す | 数で比べる |

**1 度に 1 経路だけ回す。** footprint も GPU の確保量もプロセス全体の値なので、2 つを同時に
回すとどちらの増え方か分からない。窓は ← → で候補を、スペースで経路を切り替える。

**落ちる候補はテストだけにある。** 窓に並べると窓ごと落ちるからで、`swift test` では exit test
(子プロセス) に閉じ込める。

候補の定義は [`Sources/Soak/Loads.swift`](Sources/Soak/Loads.swift) (メモリと時間) と
[`Sources/Soak/Crashes.swift`](Sources/Soak/Crashes.swift) (落ちる) にだけあり、窓もテストも
同じ定義を回す。

## 測り方

| 何を | どう読むか |
| --- | --- |
| メモリ | プロセスの `phys_footprint` (`task_info(TASK_VM_INFO)`)。活動モニタの「メモリ」と同じ値で、jetsam が殺す判断に使うのもこれ |
| GPU | mokume に渡したのと同じ `MTLDevice` の `currentAllocatedSize` ([`Meter.swift`](Sources/Soak/Meter.swift))。**別の装置を作って読んでも mokume の確保は見えない**ので、テストも窓も `RenderDevice(device: Meter.device)` で組む |
| 時間 | `advance()` 1 回の時間。暖機 (最初のシェーダの組み立て) の後だけを平均する |
| 落ちる | Swift 6.3 の exit test (`#expect(processExitsWith: .success)`)。本体の検査は巻き込まれない |

**窓と同じ条件で回す。** テストの舞台 ([`Stage.swift`](Tests/SoakTests/Stage.swift)) は、毎フレーム
次の 2 つをする。

- `autoreleasepool` で包む。
- `Task.yield()` で main actor を譲る。

窓では run loop がどちらもしている。譲らないと、mokume が GPU の完了を受けて main actor へ積む
後始末が走らない。すると、何もしないスケッチでも 1 枚あたり 1.45 KB ずつ増える。この回し方
そのものも、`headlessAdvance` として突いている。

**閾値は、機械に依らない形で置く。**

| 見るもの | 閾値 | 理由 |
| --- | --- | --- |
| メモリ | 疑いの増え方が「参照 + 32 KB/枚」を越えないこと | 参照はほぼ 0 だが、malloc の領域が 1 度だけ 2 MB 伸びる段を踏むと 300 枚で 10 KB/枚に見える。疑いの側はどれも 100 KB/枚を越える |
| 時間 | 仕事を倍にしたときの時間の比が 2.6 未満であること | 線形なら 2、二乗なら 4 に近づく。固定の費用があると 2 より小さく出る |
| 落ちる | 極端な値でも子プロセスが成功で終わること | 対照 (極端でない値) が通ることを先に押さえる |

増え方は、暖機の後の**頭の 1/4 と尻の 1/4 の中央値どうし**で測る。malloc は空きを一度に
まとめて OS へ返すことがあり、端の 1 点どうしの差だと、その 1 回で増え方の符号まで変わる。

毎フレーム同じだけ積む疑い (`modelSequence`) は、**1 枚ごとの増分の中央値**で見る。連番の OBJ
では、35 枚目前後で 40 MB が一度に返る。`malloc_zone_pressure_relief` を挟んでも消えなかった。

**各検査は、疑いを確かめる前に参照の側が動いていることを押さえる。** 参照が描いていること、
参照が増えていないこと、対照が落ちないことである。参照まで増えていたら、比べても何も言えない。

## 走らせる

```bash
mokume run .      # 窓で 1 候補ずつ回す (← → で候補、スペースで経路、r で回し直す)
swift test        # 窓を出さずに回して、数で比べる (15 秒ほど)
```

**`swift test` は緑で終わる。** 破れていたものは `withKnownIssue` で包んであり、「既知の問題」
として数えられる。`v0.11.1` では 12 本のテストで 15 件になる。

**mokume 側で直ると赤くなる。** 版を上げて直ったものがあると、そのテストは「Known issue was not
recorded」で落ちる。そのときは包みを外し、下の表を書き換える。

## 結果 — mokume `v0.11.1`

**mokume の `origin/main` (`1536271`、2026-09-24) でも全件同じ結果が出た。** v0.11.1 の後に
直ったものは無い。数字は debug 組み (`mokume run` と同じ) の M 系の Mac での実測である。

### 破れていたもの (起票した)

#### メモリ

| 鍵 | 何が起きたか | mokume |
| --- | --- | --- |
| `unclosedShape` | `setup()` で開いた `beginShape()` に毎フレーム 1000 点足すと、約 170 KB/枚ずつ増え続ける。何も描かれず、警告も出ない (毎フレーム閉じる参照は 0) | [#1591](https://github.com/mokume-metal/mokume/issues/1591) |
| `offFrameGraphics` | `beginDraw()` を付けずに描き場所へ円を 1000 個置くと、約 130 KB/枚ずつ増え続ける。何も描かれず、警告も出ない (挟む参照は 0) | [#1592](https://github.com/mokume-metal/mokume/issues/1592) |
| `modelSequence` | 連番の OBJ (1681 頂点) を 1 枚ずつ `loadModel` すると、読んだモデルが控えに残り、1 枚ごとに 464 KB 増える。画像の控え (64 MiB) と違って上限が無い | [#1593](https://github.com/mokume-metal/mokume/issues/1593) |
| `headlessAdvance` (テストだけ) | main actor を譲らずに `advance()` を回すと、GPU の完了の後始末 (`Task { @MainActor in releaseFinished }`) が走れずに溜まる。何もしないスケッチで 1.45 KB/枚、毎フレーム `createGraphics` すると 5.8 KB/枚 (譲れば 0) | [#1594](https://github.com/mokume-metal/mokume/issues/1594) |

#### 時間

| 鍵 | 何が起きたか | mokume |
| --- | --- | --- |
| `polygonFill` | 多角形の塗りの三角形分割が頂点数の二乗。1000 → 2000 頂点で時間が 3.7〜4.0 倍 (500・1000・2000 頂点で 13・49・188 ms/枚)。同じ形を扇で置く参照は 2.6 倍に届かない | [#1595](https://github.com/mokume-metal/mokume/issues/1595) |
| `solidStroke` | 既定の線のままの `sphere()` 100 個で 465 ms/枚・GPU +183 MB (`noStroke()` なら 0.4 ms/枚)。稜線の帯と頂点ごとの円板を、立体ごと・毎フレーム CPU で組み直す。個数には比例する | [#1596](https://github.com/mokume-metal/mokume/issues/1596) |

#### 落ちる (テストだけ)

[ADR-0020](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0020-api-naming-and-surface.md) 決定 5 は、失敗の伝え方を呼ばれ方で決めている。

- 描く口は、投げずに既定へ倒す。
- 資源の生成は、型のついたエラーを投げる。
- 読み取りは、決して落ちない。

次の件は、どれにも当たらずプロセスごと止まる。

| 鍵 | 何が起きたか | mokume |
| --- | --- | --- |
| `hugeTextSize`・`textOutline` | 次の 3 通りが、Int への変換でトラップする。`textSize(400)` の対照は通る。<br>・`textSize(1e20); text("M", …)`<br>・`textOutline("o", .nan, 100)`<br>・`textSize(1e21); textOutline("o", 0, 0)` | [#1587](https://github.com/mokume-metal/mokume/issues/1587) |
| `createShapeDiscard` | 図形を溜めた後に次のどちらかを書くと、`Range requires lowerBound <= upperBound` で落ちる。中で呼ばなければ通る。<br>・`createShape { background(255); … }`<br>・`createShape { get(5, 5); … }` | [#1588](https://github.com/mokume-metal/mokume/issues/1588) |
| `makeNumbersHuge` | `try? makeNumbers(count: .max)` が投げずに、バイト数の掛け算のあふれで落ちる。`1 << 40` は上限の検査で投げる | [#1589](https://github.com/mokume-metal/mokume/issues/1589) |
| `displayImageOutside` | `encodeForDisplay()` で得た `DisplayImage` を `[width, 0]` で読むと、precondition で落ちる。`PixelBuffer` は [#1436](https://github.com/mokume-metal/mokume/issues/1436) で透明を返すようになった | [#1590](https://github.com/mokume-metal/mokume/issues/1590) |

### 既知の問題へ足したもの

| 鍵 | 何が起きたか | mokume |
| --- | --- | --- |
| `pulsingText` | `textSize(14 * (1 + 0.3 * sin(t)))` で漢字 12 字を描くと、約 100 KB/枚ずつ増え続ける。同じ脈を `scale` で付ける参照は 0。書体の控えが大きさごとに増える件の、作品の書き方での実害である | [#1431](https://github.com/mokume-metal/mokume/issues/1431) (実害待ち) へ数字を足した |

### 踏んだが起票しなかったもの

| 当たり | 起票しなかった理由 |
| --- | --- |
| 光を足すたびに列が閉じ、光の写しが二乗で増える | **仮説違い。** 光の数を 1〜400 に変えても時間も GPU も変わらなかった。重かったのは立体の線 (`solidStroke`) |
| 毎フレーム `createGraphics` / `createImage` を作る | main actor を譲れば頭打ちになる。増えるのは譲らないときだけで、`headlessAdvance` と同じ根 |
| 1 フレームだけ極端な数を描くと、置き場がそのピークのまま縮まない (円 100 万個で GPU 2.3 GB が残る) | **設計どおり** ([mokume#754](https://github.com/mokume-metal/mokume/issues/754)・[#734](https://github.com/mokume-metal/mokume/issues/734) で「取り直しは寿命に対して稀」と決めた) |
| 1 フレームで使う字が字形の頁 (4096²) を越えると、毎フレーム頁を焼き直す (96 pt の漢字 4000 字で 1.4 s/枚) | **設計どおり** ([mokume#1342](https://github.com/mokume-metal/mokume/issues/1342)・[#1492](https://github.com/mokume-metal/mokume/issues/1492))。画面に収まる字数では踏まない |
| `curveDetail` に上限が無い (20 万で GPU 6.8 GB) | 極端な入力でしか踏まない。円 (1024 辺) や球 (128) のような丸めが無いことは記録に留める |
| 走っていないところから `width` などを読むと `fatalError` | 説明どおりの挙動 (`requireRuntime` の文面が「init から呼ぶな」と名乗る) |
| 巨大な画像を展開してから大きさを検める・上げ荷の置き場の合計に上限が無い | 確かめるのに GB 単位の確保が要り、検査に置けない |

## どうやって当たりを付けたか

v0.11.1 と main のソースを 3 つの範囲に分けて読み、約 25 件の当たりを付けた。

- 描画と置き場
- 画像・字・書き出し
- 実行時・形・入力・観測

公開の口だけで踏めて、確かめるのに GB 単位の確保が要らない 17 件を使い捨ての舞台で 1 件ずつ踏んだ。
本物だった 11 件のうち 10 件を起票し、1 件を既知の Issue へ足した。立体の線 (`solidStroke`) は
当たりに無く、光の当たりを外したときの切り分けで見つかった。既に Issue があるものは新しく起票せず、実害の数字を足すか (書体の控え = [#1431](https://github.com/mokume-metal/mokume/issues/1431))、
当たりから外した (シェーダの重複した組み立て = [#728](https://github.com/mokume-metal/mokume/issues/728) など)。probes は mokume を外のパッケージとして引いているので、
`@testable import` には頼らない。

## どの mokume で測ったか

**`Package.resolved` が固定している版がそのまま答えで、コミットしてある** (`v0.11.1`)。
`from: "0.11.1"` は他の物差しと同じく記録であって、留め金ではない。

版を上げたら `swift test` を回す。**赤くなったテストは、直った約束である。** 時間の検査は比で
見ているので、機械を替えても同じ判定になるはずである。赤くなったら、まず版差を疑う。
