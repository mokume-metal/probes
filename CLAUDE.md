# probes

mokume を外から測る物差し (Atlas・Probe・Drift・Routine) を置く。何を置くか・並べ方・走らせ方は
[README.md](README.md) が正本で、ここでは繰り返さない。ここに置くのは、作業するときに
踏みやすいことだけである。

## 確かめるコマンド

```bash
(cd Probe && swift test)              # 既知の問題の件数が Probe/README.md と一致すること
(cd Drift && swift test)              # 同じく Drift/README.md と
(cd Routine && swift test)            # 同じく Routine/README.md と
python3 scripts/verify.py --check     # Atlas の台帳の版と Package.resolved が揃っていること
python3 Atlas/scripts/examples.py --check   # 例 157 本の Package.swift が正本と揃っていること
```

## 踏みやすいこと

- **`swift test` は CI では回らない。** 画素を読むので Metal が要り、GitHub の Linux の
  runner には無い。CI (`pr-policy`) が見るのは PR タイトルだけなので、Probe・Drift・Routine を
  触った PR は手元で回した結果 (既知の問題の件数) を本文に書く。
- **赤くなった `withKnownIssue` は、直った約束である。** 壊したのではない。版上げの後なら
  `.claude/skills/probes-bump/` の手順で包みを外す。版を上げていないのに赤いなら、検査の
  側を疑う。
- **生成物を手で書かない。**
  - Atlas の例 157 本の `Package.swift` は `python3 Atlas/scripts/examples.py` が書く。
  - `Atlas/README.md` の `<!-- verify:… -->` の区間は `python3 scripts/verify.py --write-readme` が書く。
- **書き込むスクリプトがある。**
  - `scripts/bump.py` は全部の `Package.swift` と `Package.resolved` を書き換える。しかも引数を版として検めない (`--help` も版とみなす。#6)。
  - `scripts/watch.py` は `--dry-run` を付けないと Issue を立てる。
- **`scripts/` は mokume-metal/works の写しである。** 特に `mokume_api.py` の名前の起こし方は、
  works の側と同じでないと台帳の区分がずれる。変えるときは両方を直す。
- **mokume の不具合は mokume 側へ起票する。** 再現は数行のスケッチにして載せ、こちらの検査は
  `withKnownIssue("mokume#NNNN: …")` で包んで名指しする。
- **絵と動きの証跡は GitHub の添付に上げる。** Gyazo に置いた絵は一斉に 404 になった
  (mokume-metal/works#80・#5)。リポジトリには画像をコミットしない。
- **設計の判断は [`docs/decisions/`](docs/decisions/) に残す。**
