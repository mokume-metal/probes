---
name: probes-file
description: "probes の物差しで見つけた破れを mokume へ Bug として起票するときに読む。起票の前に調べきる項目、mokume だけで閉じた再現を Repros/ に置いて単独で走らせること (scripts/filing.py repro)、本文の下書き (filing.py draft)、骨格の検め (filing.py check)、起票後に番号を書き戻すまでの段取り。Use when filing a mokume bug from a probes ruler, when adding a withKnownIssue that names a new mokume issue, when writing a repro under Repros/, or when filing.py check fails in pr-policy."
---

# mokume へ起票する

**約束の正本は [`docs/filing.md`](../../../docs/filing.md)**、理由は ADR-0012。ここにはコマンドの順だけを置く。
絵の出し方と上げ方は skill `probes-evidence`。

## 段取り

1. **重なりを先に見る。** 同じ根の Issue があれば起票しない。そちらにコメントで観察を足す。

   ```bash
   grep -rn '"mokume#' */Tests | grep -i <API 名>
   gh search issues --repo mokume-metal/mokume <API 名>
   ```

2. **再現を置く。** `<物差し>/Tests/<物差し>Tests/Repros/<鍵>.swift` に、1 行目 `// repro: mokume#未起票` で書く。
   - mokume と Foundation だけで閉じる。
   - `enum` を 1 つ置き、`static func reproduce() throws -> String?` を持たせる。
   - 手本は `Weave/Tests/WeaveTests/Repros/polylineJoin.swift`。
   - 物差しの `ReprosTests.swift` に、`withKnownIssue` で包んだテストを足す。

3. **単独で走らせる。** 版を固定したものと main の両方で走らせる。終了コードは 1 = 再現した・0 = 期待どおり・2 = 組めない。

   ```bash
   python3 scripts/filing.py repro <物差し> <鍵>
   python3 scripts/filing.py repro <物差し> <鍵> --mokume main
   ```

   - 2 になったら、probes の型に頼っていないかを見る。
   - main で 0 なら、もう直っている。起票せず、次の版を待つ。
   - 初回は mokume を組むので数分かかる。`.build/filing/` に置いて使い回す。

4. **反復・陰性対照・境界を確かめる。**
   - 反復は `swift test --filter` を回すか `stress.py` で見る。
   - 陰性対照と境界は、物差しの陰性対照の検査か、条件を振った一時の検査で押さえる。

5. **絵を出して GitHub の添付へ上げる** (skill `probes-evidence`)。画素に出ない事象なら飛ばし、本文に `不要: 理由` と書く。

6. **commit して push してから、下書きを組む。** 出どころのリンクは HEAD の commit で固定するので、push していないと開かない。

   ```bash
   python3 scripts/filing.py draft <物差し> <鍵> --shot <添付の URL> --search <API 名> > /tmp/draft.md
   ```

7. **`<!-- 書く: … -->` を埋める。** 事象・期待と実際 (出典と数)・確かめたこと・当たり (タグ固定の行) の欄である。

8. **検める。** 黙るまで直す。

   ```bash
   python3 scripts/filing.py check --body /tmp/draft.md --title 'fix(<領域>): `<API>` が …'
   ```

9. **起票する。**

   ```bash
   gh issue create -R mokume-metal/mokume --title '…' --body-file /tmp/draft.md
   ```

   - 本文の末尾には、署名の 1 行を区間の外に付ける。
   - 起票した後は、区間の中を書き換えない。補足はコメントに書く。

10. **番号を書き戻す。**
    - 再現の 1 行目を `// repro: mokume#NNNN` に直す。
    - `withKnownIssue("mokume#NNNN: …")` の文面を直す。
    - 物差しの README の表と既知の問題の件数を直す。
    - `python3 scripts/filing.py check` が黙ることを確かめる。

## pr-policy の `filing.py check` が落ちたら

- **`再現のファイル … が無い`**: 新しく名指しした番号に、`Repros/` の再現が無い。段取りの 2 から置く。
- **`区間の印` や `## … が無いか空`**: mokume 側の本文が骨格を欠いている。区間の中を骨格どおりに直す。直したことはコメントにも残す。
- **`起票してから入れる`**: `mokume#未起票` のままマージしようとしている。
- **台帳 (`docs/filing-baseline.txt`) には足さない。** 骨格より前の起票を猶予するためだけのものである。
