# 0002 — CI では物差しの検査を回さず、mokume の版は Dependabot に任せない

## 状態

採用 (2026-09-24)

## 文脈

物差しの本体の検査は、Probe・Drift の `swift test` である。mokume で窓を出さずに描き、
読み戻した画素を比べるので、**Metal が要る**。GitHub が用意する Linux の runner には
Metal が無く、macOS の runner でも GPU を使えるとは限らない。

一方、repo-standards は main の ruleset に必須チェックを求め、依存の見張りに Dependabot を
求める。どちらも、そのまま当てると物差しの手順とぶつかる。

- **必須チェック**: 物差しの検査を必須にすると、runner で回らないので、どの PR もマージできなくなる。
- **Dependabot**: Swift (mokume) を見張らせると、Package.resolved を 1 本ずつ上げる PR が立つ。ところが版上げは、`scripts/bump.py` で全部の物差しを一度に上げ、版だけ動かした基準線で測り直す手順を踏む (`.claude/skills/probes-bump/`)。1 本ずつ上がると、「版差か書き直しか」を切り分けられなくなる。

## 決定

- **CI で回すのは PR の決まりごとだけにする。** `pr-policy` ジョブが PR タイトルを
  Conventional Commits の形で検査し、main の ruleset はこのジョブだけを必須にする。
  物差しの検査は手元で回し、結果 (既知の問題の件数) を PR 本文に書く。
- **Dependabot が見張るのは GitHub Actions だけにする。** mokume の新しい版に気付くのは
  `mokume-watch.yml` で、日次で見に行って追随の Issue を立てる。版を上げるのは人
  (とエージェント) が `bump.py` で行う。

## 影響

- 物差しの検査が赤くなっても、PR のマージは止まらない。手元で回した結果を PR 本文に書く
  ことが、唯一の担保になる (PR テンプレートに欄を置いた)。
- Metal を使える runner (セルフホストの Mac など) を用意できたら、この ADR を置き換えて、
  `swift test` を必須チェックに足す。
