# Clause — mokume v0.22.1 の DocC・ADR が書いた約束の 1 文を、境界と陰性対照で突く

**作品ではなく物差しである。** 他の物差しは、同じ絵になるはずの 2 つの経路を画素で比べる。Clause は、mokume の
説明が 1 文で言い切っている約束を 1 つ選び、その文がいう値・ファイル・ポート・知らせの行をそのまま確かめる。

- 「1 つの datagram が 1 つのメッセージになる」(`UDPPort`)
- 「`1e400` のように `Double` に収まらない数は読めない」(`loadJSONObject`)
- 「`0 0 0` の面は巻き方から求め、両面として扱う」(`loadModel` の STL)

突いたのは、v0.17〜v0.22.1 で入り、他の物差しが 1 度も当てていない口である。ファイルを読む口 (CSV・JSON・XML・SVG・STL・OBJ)・
時刻を操る口 (`pauseTime`・`jumpTime`)・通信の口 (OSC・UDP・TCP・WebSocket)・粒の向き (`Emitter`・`Heading`) の 4 つ。
理由は [ADR-0015](../docs/decisions/0015-clause-documented-promises.md) にある。

## 何をしているか

**約束の 1 文ごとに、mokume だけで閉じた再現を 1 本置く** (`Tests/ClauseTests/Repros/`)。

- 再現は、まず**陰性対照**を確かめる。破れない隣の条件が約束どおりかを見て、崩れていたら `control broke` を返す。
  例: `-1e400` を突く前に、`1e400` が投げることを確かめる。
- そのうえで、**破れる条件**を確かめる。
- 起票の本文には、このファイルをそのまま貼る ([docs/filing.md](../docs/filing.md))。

| 確かめ方 | 何で見るか |
| --- | --- |
| `swift test` | `ReprosTests` が再現 18 本を `withKnownIssue` で包んで走らせ、`ControlsTests` が破れなかった境目を常に緑で押さえる |
| `mokume run .` | 窓は突いた口の群と件数を出すだけ。数で押さえるのはテストの側 |

- 通信はループバック (127.0.0.1) だけで確かめる。
- 知らせの行は、標準エラーを一時ファイルへ向けて拾う (`dup2`)。
- 絵を読む再現 (SVG・立体) は、画素の数か明るさの閾値で判定する。画素の指紋は読まないので、`scripts/stress.py` には入れていない。

## 走らせる

```bash
swift test                              # 21 本のテスト。既知の問題 18 件で緑
python3 ../scripts/filing.py repro Clause <鍵>               # 再現 1 本を mokume だけのパッケージで
python3 ../scripts/filing.py repro Clause <鍵> --mokume main  # 同じく mokume の main で
```

**`swift test` は緑で終わる。** 破れていたものは `withKnownIssue` で包んであり、「既知の問題」として数えられる
(`v0.22.1` では 21 本のテストで 18 件)。同じ機械で 3 回回し、3 回とも 18 件だった。

**mokume 側で直ると赤くなる。** 版を上げて直ったものがあると、そのテストは「Known issue was not recorded」で落ちる。
そのときは包みを外し、下の表を書き換える。

## 結果 — mokume `v0.22.1`

**7 領域を突き、18 件が約束を破っていた。** 18 件とも mokume の `main` (`e7af450`) でも単独で出たので、Bug として起票した。
面の向きの 2 件 (`objMixedNormals`・`stlZeroNormalMixed`) は同じ根に見えるので、根の Issue で束ねた。

### 破れていたもの

| 領域 | 鍵 | 約束 | 何が起きたか | mokume |
| --- | --- | --- | --- | --- |
| 通信 | `udpEmptyDatagram` | 1 つの datagram が 1 つのメッセージになる (`UDPPort`)・落とさない列 (mokume ADR-0028) | 同じ送り元から `"a"`・`""`・`"b"`・`"c"` を続けて送ると `["a"]` だけが届く。空の datagram で繋ぎを閉じ、続けて届いた分を数えずに捨てる。OSC も 6 通中 1 通 | 未起票 |
| 通信 | `udpLargeDatagram` | 同上 | 9217・20000・65507 B の datagram が、どれも 9216 B に切れた文字列として届く (素の socket は全長を受ける)。OSC の 12000 B の blob は捨てられる | 未起票 |
| 通信 | `sendRefusedWarns` | 受け手のいない宛先への `send` は 1 度だけ診断に出す (`OSCPort`・`UDPPort` の `send`) | 10 回送って、どちらも 5 回知らせる | 未起票 |
| 時刻 | `jumpTimeNonFinite` | フレームごとに呼ぶ口は値を検め、安全な既定へ倒す (mokume ADR-0020 決定 5)・兄弟の `Movie.jump` は数でない値を断る | `jumpTime(.nan)`・`(.infinity)`・`(-.infinity)` の後、`time` がずっと非有限。止めて再開しても戻らず、知らせも無い | 未起票 |
| 時刻 | `pauseTimeObserved` | 観測の指定秒はずれに触れない。撮った後は作者の時計へ戻る (`Clock.swift`) | 時刻を指定した観測の枚で `pauseTime()` を呼ぶと、観測の秒 5.0 で止まる (期待 0.05) | 未起票 |
| JSON | `jsonNegativeOverflow` | `1e400` のように `Double` に収まらない数は読めない (`loadJSONObject`) | `1e400` は投げるが、`-1e400`・`-1.8e308` は投げずに -inf で読める | 未起票 |
| JSON・XML・表 | `floatText` | 数でない文字は NaN にし、キーごとに 1 度知らせる。前後の空白は落とす (`getFloat`) | `"nan"` は知らせずに NaN、`"inf"`・`"0x10"` は inf・16 として読む (3 種とも)。表のセル `"3\n"` は NaN (Processing は 3) | 未起票 |
| XML | `xmlCarriageReturn` | 壊れた行を添えて投げる。行は LF・CRLF・CR のどれで数えてもよい (`XMLFile`) | 4 行目で壊れた XML が、LF と CRLF なら line 4、CR だけなら line 1 | 未起票 |
| XML | `xmlEncodingDecl` | 文字は UTF-8 (`loadXML`) | UTF-8 として正しく読めたファイルを、宣言の `encoding="Shift_JIS"`・`"ISO-8859-1"` で解き直して投げる | 未起票 |
| SVG | `svgWidthOnly` | `width` / `height` と `viewBox` が書いてあれば、その大きさへ写す (`loadShape`) | 根に `width` だけ (または `height` だけ) を書くと、欠けた側が viewBox の大きさになり、等倍のままずれる (5000 画素のはずが 200) | 未起票 |
| SVG | `svgUniversalSelector` | 優先の順は CSS のとおり (`SVGFile`) | `rect{fill:red} *{fill:blue}` で矩形が青になる。`*` を要素名と同じ詳細度で、書いた順に上書きする | 未起票 |
| 立体 | `stlSmallAscii` | 文字の STL も読む。読めないとするのは 84 B に満たないファイルなど (`ModelFile+STL`) | 面が 1 つの文字の STL が、127 B なら投げ、末尾に空白を 1 つ足した 128 B なら読める (Model I/O が 128 B 未満を断る) | 未起票 |
| 立体 | `stlIndentedAscii` | `solid` で始まらない文字の STL (前に空白) は読めないとして返す (同上) | 前に空白 2 つの文字の STL がバイナリとして読まれ、三角形 5 枚・大きさ 1.86e34 のでたらめな形が返る | 未起票 |
| 立体 | `objMixedNormals` | 面の向きが書かれていなければ形から求める (`ModelFile`) | `vn` のある面と無い面が混ざると、無い面の向きが (0,0,1) になる (明るさ 0.707、期待 1.0) | 未起票 |
| 立体 | `stlZeroNormalMixed` | `0 0 0` の面は巻き方から求め、両面として扱う (`ModelFile+STL`) | 同じファイルに向きを書いた面があると片面になり、見る側と逆に巻いた面が真っ黒になる | 未起票 |
| 立体 | `objBadCorners` | 読み飛ばした行は `skippedLines` に数える | 5 角の面の 1 角だけが読めない (範囲外・0・数でない) と、その角を黙って落として四角形で読み、読み飛ばしは 0 | 未起票 |
| 表 | `saveTableBom` | 書いたファイルを `loadTable` で読み直すと、同じ表に戻る (`saveTable`) | 頭のセルが U+FEFF で始まると、読み直しで BOM として落ちる。1 列の表では行が 1 つ消える | 未起票 |
| 文字 | `textFileDirectory` | `.unreadable` は「見つかったが UTF-8 の文字として読めない」(`DataFailure`) | ディレクトリや読む権利の無いファイルも `.unreadable` になり、「UTF-8 で保存されているか確かめよ」と的外れに勧める | 未起票 |

### 起票しなかったもの

約束の文が無いか、極端な値でしか出ない。直す価値の判断は mokume 側に要るので、観察として残す。

| 領域 | 何が起きたか | 起票しなかった理由 |
| --- | --- | --- |
| JSON・XML | 正規化だけが違うキー (`é` の NFC と NFD) が 1 つに潰れ、片方の値を失う | DocC に約束が無い。Swift の `String` の比べ方そのままで、利点もある |
| SVG | `viewBox` の幅か高さが 0 でも描く (SVG 1.1 では描かない) | 外の規格だけが出典 |
| SVG | 読めない `preserveAspectRatio` が `xMidYMid` でなく `xMinYMin` に寄せる | 同上 |
| SVG | 全角の 16 進 (`#ＦＦ0000`) を色として読む | 同上。作品で踏むことが少ない |
| SVG | 長さ 0 の部分パス `M x y z` に丸い端が付かない (`M x y L x y` には付く) | 実装のコメントが意図と書いている |
| OBJ | `#text` (空白なし) のコメントを読み飛ばしに数える | 数の違いだけで、絵は変わらない |
| OBJ | 行継続 (行末の `\`) を読まない | DocC に約束が無い |
| OBJ | 座標の幅が Float の上限を越えると、整えた `size` が NaN | 極端な値 (±1.8e38) |
| 粒 | 加算で光らせた粒でも、奥行きの違う奥の粒が消える | mokume#1565 で採らなかった判断 |

### 破れなかったもの

主な境目は `ControlsTests` と各再現の陰性対照が押さえている。突いて約束どおりだったもの:

- **CSV・文字:**
  - 引用符の中の `,`・改行・`""`、CRLF・CR・LF の混在。
  - 壊れた行の行番号、14 種の値の往復、20 万行。
- **JSON・XML:**
  - 入れ子の上限 (512 段)、実体参照・内部 DTD・billion laughs の停止。
  - サロゲートペア、URL の 404・500・リダイレクト。
- **SVG:**
  - 数の書き方 (`1.5.5`・`-1-2`・指数)、暗黙の命令、弧 (大きい弧・掃引・半径の拡大)。
  - transform の合成順、evenodd と nonzero の穴、currentColor、CSS のクラス。
- **STL・OBJ:**
  - `solid` で始まるバイナリ、面の数の欄と長さの食い違い、`.STL`、法線の長さ。
  - OBJ と STL と `beginShape(.triangles)` の絵の一致。
- **時刻:**
  - `setup` の中の `pauseTime`・`jumpTime`、同じフレームの pause → play・jump 2 回、負の秒。
  - 再開の最初の 1 枚、止めている間の粒・録画・動画。
- **粒:**
  - `Emitter.circle`・`.sphere`・`.line` の一様さ、`Heading.plane` の角度 (0 をまたぐ・2π 超・幅 0)。
  - `Heading.sphere` の等方性、`rate` の繰り越し、寿命の枚数、変換の下の位置。
- **通信:**
  - OSC の符号化と復号 (詰め・blob・bundle)、TCP の行の分割と多バイト文字。
  - WebSocket の拡張長・マスク・分割フレーム・ping、ポートの取り合い、閉じた後の送信。

## どの mokume で測ったか

**`Package.resolved` が固定している版がそのまま答えで、コミットしてある** (`v0.22.1` = `c364136`)。
`from: "0.22.1"` は他の物差しと同じく記録であって、留め金ではない。18 件は mokume の `main` (`e7af450`) でも再現が単独で
出ることを確かめた (`python3 scripts/filing.py repro Clause <鍵> --mokume main`)。

版を上げたら `swift test` を回す。**赤くなったテストは、直った約束である。**
