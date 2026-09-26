# mokume へ起票する

物差しで見つけた破れを、mokume へ `Bug` として戻すときの約束。理由は [ADR-0012](decisions/0012-filing-quality.md)、
コマンドの段取りは skill [`probes-file`](../.claude/skills/probes-file/SKILL.md) にある。`Feature` (できないこと) の行き先は
[CONTRIBUTING.md](../CONTRIBUTING.md) の表に従う。

**読み手は 2 種類いる。** 1 つは probes を知らない mokume の開発者、もう 1 つは Issue だけを渡された AI である。
本文だけで、再現・何が違うか・どこが怪しいかを確かめられるようにする。

## 1. 起票の前に調べきる

次の 5 つを確かめ、本文の「確かめたこと」に 1 行ずつ書く。確かめられなかったものは空欄にせず、
`未確認: 理由` と書く。

| 項目 | 確かめること |
| --- | --- |
| 単独の再現 | `Repros/` の再現が、mokume だけのパッケージで破れを出す (`filing.py repro`) |
| main | mokume の `main` でも出る (`filing.py repro … --mokume main`)。出なければ起票しない。直った版を待つ |
| 反復 | 何回回して何回出たか。決定論なら「同じ機械で N 回・毎回同じ」。稀なら条件と頻度 (ADR-0007) |
| 陰性対照・境界 | 破れない隣の条件 (例: `.blend` なら 0 画素) と、破れ始める境目 (例: 不透明度 254 と 255) |
| 重複 | 次の 2 つを探し、同じ根が無いこと。見つかったら新しく起票せず、そちらに観察を足す (mokume#1647 の轍)<br>・mokume の Issue を API 名で検索する<br>・他の物差しの `withKnownIssue` の文面 (`filing.py draft --search`) |

**読んだだけで起票しない。** 走らせて破れが出たものだけを起票する (mokume#1607 の轍)。

## 2. 再現を置く

置き場は `<物差し>/Tests/<物差し>Tests/Repros/<鍵>.swift` (手本: [`Weave/Tests/WeaveTests/Repros/polylineJoin.swift`](../Weave/Tests/WeaveTests/Repros/polylineJoin.swift))。

- 1 行目は `// repro: mokume#未起票` にする。起票して番号が付いたら `// repro: mokume#NNNN` に直す。
- 読み込むのは `mokume` と `Foundation` だけ。`@testable import` も probes の `Stage`・`Picture`・`fingerprint` も使わない。比べる道具は、ファイルの中に数行で書く。
- 最上位に `enum` を 1 つだけ置き、`static func reproduce() throws -> String?` を持たせる。
  - 期待どおりなら `nil` を返す。
  - 破れていれば、数を入れた説明を返す。
  - 落ちる事象なら、その中で落ちる。
- 描くのは `SketchRuntime(sketch:gpu:)` → `advance()` → `target.readPixels()` だけで足りる。
- 物差しの `ReprosTests.swift` に、この再現を名指しするテストを足す。

  ```swift
  let broken = try PolylineJoin.reproduce()
  withKnownIssue("mokume#NNNN: …") { #expect(broken == nil, "\(broken ?? "")") }
  ```

**再現は `fingerprint` を通さない。** mokume だけで閉じるためである。決定論の判定 (ADR-0007) は、
同じ鍵の物差しの検査が押さえる。再現を置いても、物差しの検査は外さない。

**最小にする。** 物差しの検査は探すための形なので、再現はそこから破れに要る呼び出しだけを残す。
本文に貼るのはこのファイルそのもので、手で写し直さない (mokume#1638 の轍)。

## 3. 本文の骨格

`python3 scripts/filing.py draft <物差し> <鍵>` が雛形を出す。機械が埋めるのは次の欄である。

- 再現
- 出力
- main の結果
- 出どころ
- 環境

残る `<!-- 書く: … -->` を埋めて、`filing.py check --body` が黙るまで直す。

| 見出し | 書くこと |
| --- | --- |
| 事象 | 何が起きるかを 2〜3 文で。API の識別子は `…` で囲む |
| 再現 | `Package.swift`・`main.swift`・再現のファイルと、走らせた出力 (機械が埋める) |
| 期待と実際 | 期待には出典を付ける (mokume の ADR・DocC、Processing / p5.js の振る舞い)。実際は数と測り方で書く |
| 証跡 | GitHub の添付の絵。画素に出ない事象なら `不要: 理由` |
| 確かめたこと | 1 の 5 行 |
| 当たり | タグで固定したソースの行 (`v0.12.0` の `path:line`)。無ければ `未確認: 理由` |
| 出どころ | commit で固定した、再現のファイルと物差しへのリンク (機械が埋める) |
| 環境 | macOS・チップ・Xcode・Swift・mokume・組み方の表 (機械が埋める) |

**本文は `<!-- probes-filing:begin v1 -->` と `<!-- probes-filing:end -->` の区間に収める。** 区間の中は、
起票したときの報告である。後から分かったことや判断は、コメントか区間の後ろに書き、区間の中を
書き換えない。書き換えるのは、報告そのものが誤っていたときだけにする。直したことはコメントに残す。

## 4. 証跡

| 事象 | 添えるもの |
| --- | --- |
| 見た目 (形・色・位置) | 比べる絵。経路 2 つと差分を並べ、縁の破れなら拡大の段も付ける |
| 動き・時間 (フレームをまたぐ・1 枚だけ崩れる) | GIF (`shots.py --frames`) |
| 画素に出ない (落ちる・値・資源・ファイル) | `不要: 理由`。数表や出力を「期待と実際」に置く |

出し方と上げ方は skill [`probes-evidence`](../.claude/skills/probes-evidence/SKILL.md) にある。上げ先は GitHub の添付だけにする。
Gyazo は一斉に 404 になった (mokume-metal/works#80)。

## 5. タイトル

`fix(<mokume の領域>): <何が・どう違う>` の形にする。**API の識別子を 1 つ以上、`…` で囲んで入れる**
(例: ``fix(stroke): `beginShape()` の太い折れ線の折れ目が帯の外へはみ出す``)。日本語を読まない人や、
API 名で検索する AI が引けるようにするためである。

## 6. 起票の後

1. 再現の 1 行目と `withKnownIssue` の文面に番号を書く。
2. 物差しの README の破れの表に行を足し、既知の問題の件数を直す。
3. `python3 scripts/filing.py check` が黙ることを確かめる。

CI (`pr-policy`) は、検査が名指しする番号のうち台帳 (`filing-baseline.txt`) に無いものを検める。
再現のファイルか骨格を欠けば落とす。**台帳には足さない。**
