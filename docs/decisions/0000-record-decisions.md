# 0000 — 設計の判断は ADR に残す

## 状態

採用 (2026-09-24)

## 文脈

物差しの形 (なぜ 2 つの経路で描くのか、なぜ CI で検査を回さないのか、なぜ scripts を
写しているのか) は、コードにも履歴にも理由が残らない。squash merge なので、PR の中の
やり取りも main の履歴からは読めない。書かなければ、次に触る人 (記憶がリセットされた
エージェントを含む) が同じ検討をやり直す。

## 決定

設計の判断は `docs/decisions/NNNN-<短い名前>.md` に、状態・文脈・決定・影響の 4 節で書く。
番号は 0000 から連番で振り直さない。決定が変わったら、古い ADR の状態を「置換 (NNNN)」か
「廃止」にして、新しい ADR を足す。

mokume 自身の体制 (依存は一方向、踏んだものは Issue で戻す) の正典は mokume 側の
[ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)
で、ここには写さない。ここに書くのは probes に固有の判断だけである。

## 影響

- 判断を伴う PR (feat / refactor / CI や依存の方針) は、同じ PR で ADR を足すか直す。
- README は「何があって、どう動かすか」を持ち、ADR は「なぜそうしたか」を持つ。
