---
name: probes-bump
description: "mokume の新しい版に probes の物差し (Atlas・Probe・Drift・Routine・Reach・Soak・Aftermath・Imprint・Lattice・Weave) を追随させるときに読む。版上げ・Probe・Drift・Routine・Soak の既知の問題の読み方・Atlas の語彙の台帳の再判定・mokume への起票までの順序と、版上げでだけ踏む落とし穴。Use when mokume releases a new version, when a mokume watch issue is filed, when running scripts/bump.py or scripts/verify.py, when a withKnownIssue starts failing, or when a ruler's Package.resolved is behind."
---

# mokume の版上げに物差しを追随させる

**分岐と落とし穴だけを持つ。** 何をどう測るかは各物差しの README と `scripts/` にある。

## まず見る

```bash
python3 scripts/status.py      # どれが遅れているか・道具の版
python3 scripts/api-diff.py    # 何が消え、何が通らなくなり、何が増えたか
python3 scripts/upstream.py    # 戻した Issue がどうなったか
```

**リリースノートから始めない。** `v0.6.0` の `## 破壊的変更` に載っていたのは 2 件で、
`## 新機能` の中に太字で 2 件が埋まり、残り 4 件はノートに 1 度も出てこなかった。
`api-diff.py` は**署名 1 行**を単位に見るので、名前が同じまま型だけ変わったもの
(`isKeyDown(_ code: Int)` → `(_ key: Key)`) も出る。

**当たりは Swift だけで探さない。** 台帳 (`Atlas/ledger/*.jsonl`) と README も
mokume の口を名指しで持っている。works#21 が「該当ゼロ件」と誤ったのは Swift しか
見なかったためで、実際は台帳が触れていた (works#30)。

## 順序 — 3 つに分ける

| | PR | なぜ分けるか |
| --- | --- | --- |
| ① | `build:` 版だけ上げる。**中身は 1 行も変えない** | Probe・Drift・Routine・Soak・Aftermath・Imprint・Lattice・Weave の検査と Atlas の台帳が、ここで基準線を取る。②③で何かが動いたときに「版差か書き直しか」を言い切れる |
| ② | `test(probe|drift|routine|soak|aftermath|imprint|lattice|weave):` 直った約束の包みを外す | ①で赤くなったテストは、mokume 側で直った約束である |
| ③ | `feat(atlas):` 語彙の台帳の再判定 / `feat(reach):` 届く口の一覧の再判定 | 埋まった穴のぶんだけ `vocabulary.jsonl` と Reach の一覧の判定が変わる。見るものが②と違う |

```bash
python3 scripts/bump.py 0.12.0     # ① Package.swift と Package.resolved (全部)
python3 scripts/verify.py --check  # 台帳の版がずれていないか (台帳を持つ Atlas だけ)
(cd Probe && swift test)           # 赤くなったものを数える
(cd Drift && swift test)
(cd Routine && swift test)
(cd Soak && swift test)            # 時間の検査は比で見るので、機械を替えても判定は変わらない
(cd Aftermath && swift test)
(cd Imprint && swift test)         # mokume#1627 は稀にしか出ない。直ったかは stress.py の件数のゆれで見る
(cd Lattice && swift test)
(cd Weave && swift test)
(cd Reach && swift test)           # 届く口の一覧が描けること (①では緑のまま)
```

## 物差しごとの落とし穴

### Probe・Drift・Routine・Soak・Aftermath・Imprint・Lattice・Weave

**赤くなったテストは、直った約束である。** 破れていた約束は `withKnownIssue("mokume#NNNN: …")`
で包んであり、直ると「Known issue was not recorded」で落ちる。

- **包みを外す前に、mokume の Issue が閉じているかを見る。** 開いたまま赤くなったなら、
  直ったのではなく壊れ方が変わった可能性がある。検査の値を読み、閉じていなければ
  Issue にコメントする。
- 外したら、README の「破れていたもの」の表から「約束どおりだったもの」の表へ行を移す。
  **行は消さない** — 何を踏んで、どの版で塞がったかは記録である。
- 既知の問題の件数 (README の「`v0.11.0` では N 本のテストで M 件」) を書き直す。
  版入りの文は書き換えず、新しい版の文を足す。
- 新しい版で**新しく破れた**検査があれば、`Bug` として起票してから包む。
- **Routine には「いまの振る舞いを押さえる」検査が 3 件ある** (`trailBackground`・`negativeSize`・
  `polylineTrail`)。これが赤くなったのは直った約束ではなく、mokume が説明や ADR を改めた
  しるしである。変わった先を mokume の説明で確かめてから、検査と README を書き直す
  (probes の ADR-0003)。

### Reach

**版を上げても赤くならない。** Reach の検査が見るのは「届くと判定した口が描けるか」までで、
穴 (`write` / `bend` / `none`) が埋まったことは検査に出ない。**埋まったかは API の差分で見る。**

- `python3 scripts/api-diff.py <旧> <新>` で増えた口を、一覧の `none` / `write` / `bend` の行と
  突き合わせる。埋まった行は判定と書き方を直し、`Support.swift` から書き足しを消す
- 行に付けた mokume の Issue (`issue:`) が閉じていないかも見る (`python3 scripts/upstream.py`)
- 直したら `REACH_WRITE_README=1 swift test` で README の表を書き直す (手で書かない)

### Atlas

**絵を撮って突き合わせる仕組みは畳んである** (works#39)。`publish.py` / `serve.py` /
`shots.json` / `renders.txt` はもう無いので、版上げで撮り直すものも無い。
残っているのは語彙の台帳 (`ledger/`) である。

- **`vocabulary.jsonl` の再判定は人にしかできない。** 判定は手書きが優先されるので、
  `write` / `bend` / `none` → `same` の格上げは機械では起きない。`checked` を新しい版へ
  進めるのは、その行を実際に見直した印である
- **`checks.json` の `renders` は空のままにする。** 版の刻印と「ビルドが通るか」を見る
  ために残してある器で、絵の期待値を書き戻す先ではない
- **例パッケージの版は正本から流し込む。** 157 本の `Package.swift` は `exact` で釘を
  打ってあり、`python3 Atlas/scripts/examples.py` が `Atlas/Package.swift` から書き直す
  (ずれは `--check` が捕まえる)

## README を書き換えるとき

- **`vN.N.N` を一括置換しない。** 大半は「`v0.5.0` ではこうだった」という**歴史の記録**である
- **版入りの見出しは追記する。書き換えない。** 書き換えると、他から張られたアンカーも切れる
- **`<!-- verify:pins -->` と `<!-- verify:renders -->` の中は手で書かない。**
  `verify.py --write-readme` が書く。散文はその外に書く。**この印を持つのは Atlas だけ**

## 走らせると副作用が出ることがある

**版が上がると増える。** `v0.6.0` で押下を受け取れるようになった結果、当時の
`Atlas --motion` が `SaveOneImage` の例を押して `line.png` を書き出すようになった
(その口は works#39 で畳んだ)。スケッチが自分で書き出す例はまだあるので、**手で走らせたら
`git status` を見て、未追跡のファイルが増えていないか確かめる**。

## mokume へ戻す

判断の表はルート README にある (できない → `Feature` / 期待と違う → `Bug`)。
**版上げで新しく破れた `Bug` も、起票の約束 ([`docs/filing.md`](../../../docs/filing.md)) に従う。**
段取りは skill `probes-file` に置いた。調べきり、`Repros/` に再現を置いてから `filing.py draft` で組む。

**閉じた Issue は表から消さない。** `upstream.py --stale` が書き戻し漏れを出す。

## 済んだら

- ルート README の表と「全 N 本が mokume `vX.Y.Z` を引いている」の行
- `python3 scripts/verify.py --check` が黙ること
- `python3 scripts/upstream.py --stale` が黙ること
- `swift test` が Probe・Drift・Routine・Soak・Aftermath・Imprint・Lattice・Weave で緑になること (既知の問題の件数が README と一致する)
- `swift test` が Reach で緑になること (README の表が一覧と揃っている)
