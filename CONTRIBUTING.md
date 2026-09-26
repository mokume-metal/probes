# 手を入れるとき

このリポジトリは mokume を外から測る物差しを置く ([README.md](README.md))。作品は
[mokume-metal/works](https://github.com/mokume-metal/works) にある。

## 流れ

1. `main` から `<type>/<短い説明>` のブランチを切る。
2. 手元で確かめる (下)。**CI では物差しの検査は回らない** — Probe・Drift・Routine・Soak・Aftermath・Imprint・Lattice・Weave の `swift test` は
   画素を読むので Metal が要り、GitHub の Linux の runner には無い。
3. PR を出す。
   - **タイトル**は Conventional Commits の形 `<type>(<scope>): <要約>` にする。type は feat / fix / docs / refactor / test / chore / ci / perf / build。`pr-policy` が検査する。
   - **本文**には目的・変更点・確認方法を書く (テンプレートがある)。
   - マージは squash だけで、タイトルと本文がそのまま main のコミットになる。
4. 設計の判断を伴うなら、同じ PR で [`docs/decisions/`](docs/decisions/) に ADR を足す。

## 確かめる

```bash
(cd Probe && swift test)
(cd Drift && swift test)
(cd Routine && swift test)
(cd Soak && swift test)
(cd Aftermath && swift test)
(cd Imprint && swift test)
(cd Lattice && swift test)
(cd Weave && swift test)
(cd Reach && swift test)
python3 scripts/verify.py --check
python3 Atlas/scripts/examples.py --check
python3 -m unittest discover -s scripts -p 'test_*.py'
```

`scripts/stress.py` を触ったとき、画素を見る物差しの `Stage.swift` を触ったときは、
`python3 scripts/stress.py --repeat 2` も回して要約の表を PR に貼る ([ADR-0007](docs/decisions/0007-stress-and-determinism.md))。

どの `swift test` も緑で終わる。約束の破れは `withKnownIssue` で包んであり、件数は
各 README の「既知の問題」と一致する。Reach は README の表が一覧と揃っていることも見る。**件数が変わったら、その理由を PR に書く。**

## 見つけたものの行き先

| 見つけたもの | 行き先 |
| --- | --- |
| mokume の約束が期待と違う | mokume に `Bug` として起票する。再現は数行のスケッチにして載せ、こちらの検査は `withKnownIssue("mokume#NNNN: …")` で名指しする |
| mokume にできないことがある | mokume に `Feature` として起票する。**手本にあるだけでは足りない** — works の作品 2 本以上が手で書いたことを示す ([ADR-0004](docs/decisions/0004-reach-reference-coverage.md)) |
| 物差しや道具の不具合・改善 | このリポジトリに起票する |

絵や動きの証跡は、PR や Issue のコメント欄から GitHub の添付として上げる。リポジトリには
画像をコミットしない。
