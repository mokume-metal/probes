## 目的

<!-- なぜこの変更が要るか。関連 Issue があれば Closes #NN -->

## 変更点

-

## 確認方法

<!-- 手元で回したもの。Probe・Drift・Routine・Soak・Aftermath・Imprint・Lattice を触ったら swift test の結果 (既知の問題の件数) を書く。
     CI では回らない (Metal が要る) -->

| | 結果 |
| --- | --- |
| `(cd Probe && swift test)` | |
| `(cd Drift && swift test)` | |
| `(cd Soak && swift test)` | |
| `(cd Aftermath && swift test)` | |
| `(cd Imprint && swift test)` | |
| `(cd Lattice && swift test)` | |
| `python3 scripts/verify.py --check` | |
