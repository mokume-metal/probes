## 目的

<!-- なぜこの変更が要るか。関連 Issue があれば Closes #NN -->

## 変更点

-

## 確認方法

<!-- 手元で回したもの。Routine・Reach・Clause を触ったら swift test の結果 (既知の問題の件数) を書く。
     CI では回らない (Metal が要る) -->

| | 結果 |
| --- | --- |
| `(cd Routine && swift test)` | |
| `(cd Reach && swift test)` | |
| `(cd Clause && swift test)` | |
| `python3 scripts/verify.py --check` | |
| `python3 -m unittest discover -s scripts -p 'test_*.py'` | |
| `python3 scripts/filing.py check` | |
