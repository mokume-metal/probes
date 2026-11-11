# probes

[mokume](https://github.com/mokume-metal/mokume) を**外から測る物差し**を置く。作品ではない。

**目的は、mokume に実装されたものが適切に動くことを徹底的に確かめ、mokume へ戻すことである。**
見た目の小さなずれより、ハング・クラッシュ・データ破壊・戻らない劣化・GPU 同期を先に測る
([ADR-0006](docs/decisions/0006-thorough-verification.md))。観点の地図は
[#26](https://github.com/mokume-metal/probes/issues/26) にある。

mokume で作った作品は [works](https://github.com/mokume-metal/works) にある。物差しは
もともと works に置いていたが、2026-09 にこちらへ移した (works の `68306a8` まで)。**作品を
読みに来た人が最初に出会うものではない**からで、works の README が「作品は測る口を持たない」と
決めていた (works#39・works#40) のに、物差しが増えるたびに例外の但し書きが増えていた。
移す前の履歴は works 側で辿れる。

## mokume との関係

**依存は一方向で、こちらが mokume を使う。** mokume はこのリポジトリを参照しない — あちらの
`Package.swift` にも CI にも入らない。だから**ここが赤くなっても mokume は赤くならない**。
物差しが赤くなるのは、約束の破れを見つけたか、直った約束に気付いたかのどちらかで、
故障ではなく情報である。

測って踏んだことは、mokume 側の Issue 1 本にして戻す。

| 踏んだもの | mokume 側 |
| --- | --- |
| 約束されていないことが**できない** | `Feature` の Issue。どの物差しで何を測ろうとして何ができなかったかを書き、こちらへリンクを張る |
| 約束されていることが**期待と違う** | `Bug` の Issue。mokume だけで走る再現・比べる絵・環境を、決まった骨格で載せる ([docs/filing.md](docs/filing.md)) |

体制の正典は mokume 側の [ADR-0022](https://github.com/mokume-metal/mokume/blob/main/docs/decisions/0022-production-track.md)。

## 物差し

| | |
| --- | --- |
| [Atlas](Atlas/) | Processing の Examples を全数で当てた台帳と、[公式ページ](https://processing.org/examples/)の 162 本のうち移せる 157 本の実測。**作品ではなく物差し**で、1 本ずつでは出ない「どの欠けが何本の例を止めるか」を数える。**mokume `v0.6.0` で 26 本が `clean` へ移り、台帳が重いと数えた欠けから順に埋まった**。`v0.14.0` で数の口、`v0.16.0` で `QUADS` が入り、`clean` は 108 本になった |
| [Routine](Routine/) | mokume `v0.11.1` を、**作品がふつう書く書き方**で動かして突いた記録。Probe・Drift と違って**中身を読まずに**、Processing・p5 の作品が当たり前に書く組み合わせ (`setup` で決めた描き方・残像・画素の読み書き・層・脈打つ大きさ・お絵描き・押し続けるキー…) を 25 通り選び、フレームを重ねて 2 つの経路で比べる。**25 件を突いて約束の破れは 0 件**。期待と違った 3 件は説明か ADR が決めている振る舞いで、説明に無かった 1 件 (`background` の不透明度) を docs として戻した。**`v0.22.1` で基本の口の組み合わせを約 150 通り広く当て、約束の破れは 1 件だけだった** (`textBounds` が絵文字の墨を囲まない [mokume#2308](https://github.com/mokume-metal/mokume/issues/2308)。絵文字の合成列が部品に分かれることを docs として [mokume#2311](https://github.com/mokume-metal/mokume/issues/2311) へ) |
| [Reach](Reach/) | Processing / p5.js で**作品を作るときにまず使う口**を百余り、リファレンスの側から並べ、1 口 1 タイルで mokume `v0.11.1` で書いた記録。**作品ではなく物差し**で、Atlas が Examples に出てくる語彙しか見ないのに対して、例に出てこない口 (角の丸い `rect`・`erase`・`cursor`・`millis` など) も測る。穴のうち、**works の作品 2 本以上が手で書いていたもの**と規範から導けるものだけを mokume へ戻した (QUADS・`lerpColor`・`fill(rgb, alpha)`・`millis`・`deltaTime` の単位・名前の棚卸し)。`v0.16.0` で `beginShape(QUADS)` が `.quads` で入った |
| [Clause](Clause/) | mokume `v0.22.1` の **DocC・ADR が書いた約束の 1 文**を、境界と陰性対照で突いた記録。**作品ではなく物差し**で、他の物差しが同じ絵になるはずの 2 経路を画素で比べるのに対し、約束の文がいう値・ファイル・ポート・知らせの行をそのまま確かめる。v0.17〜v0.22.1 で入り、まだ誰も当てていなかった口 (CSV・JSON・XML・SVG・STL・OBJ の読み込み・`pauseTime` / `jumpTime`・OSC・UDP・TCP・WebSocket・粒の `Emitter` / `Heading`) を 7 領域で突き、**18 件が約束を破っていたので mokume へ 18 件の Bug ([mokume#2324](https://github.com/mokume-metal/mokume/issues/2324)〜[#2341](https://github.com/mokume-metal/mokume/issues/2341)) と根の Issue 1 件 ([#2342](https://github.com/mokume-metal/mokume/issues/2342)) を戻した** (空の datagram で続く datagram が消える・9216 B を超える datagram が切れる・`jumpTime(.nan)` で時刻が戻らない・`-1e400` を -inf で読む・字下げした文字の STL をバイナリとして読む・`vn` が混ざった OBJ の向き ほか)。粒の向きは 0 件。**`v0.35.0` へ上げ、17 件が直ったのを確かめた** (`v0.23.0`〜`v0.25.0`)。残る 1 件 (mokume#2325) は、9216 B 以上を丸ごと捨てて数える約束に改まったので、検査をその約束に合わせた。v0.23〜v0.35 の新しい口を約 170 通り当て、`mokume render` が高さ 1 の作品の `.mp4` を 0 バイトで書き、子が名乗らず 0 で終わる件を [mokume#3223](https://github.com/mokume-metal/mokume/issues/3223) へ戻した |

### 畳んだ物差し

次の 9 本は、突いた候補を人が選んだ 1 回きりの記録か、版上げの手間に見合うほど新しい口を拾えないので畳んだ
([ADR-0016](docs/decisions/0016-fold-rulers.md)・#84)。名指ししていた mokume の Issue 76 件はすべて閉じており、直した Bug は
mokume の `Tests/` が回帰を見張っている (確かめた表は [#84](https://github.com/mokume-metal/probes/issues/84#issuecomment-6792884961))。
中身は、畳む直前のコミット `9b771a1` の木で読める。要るときは `git checkout 9b771a1 -- <物差し>` で戻す。

| 物差し | 測ったこと | 最後に測った版 | 名指ししていた mokume の Issue |
| --- | --- | --- | --- |
| [Probe](https://github.com/mokume-metal/probes/tree/9b771a1/Probe) | 同じ絵になるはずの 2 経路の継ぎ目 | `v0.16.2` | 10 件 (mokume#931・mokume#1445〜1453) |
| [Drift](https://github.com/mokume-metal/probes/tree/9b771a1/Drift) | フレームをまたぐ継ぎ目 | `v0.16.2` | 7 件 (mokume#1366・mokume#1467〜1472) |
| [Soak](https://github.com/mokume-metal/probes/tree/9b771a1/Soak) | 長く回したときの資源 (メモリ・時間・落ちるか) | `v0.16.2` | 11 件 (mokume#754・mokume#1342・mokume#1431・mokume#1587・mokume#1588・mokume#1591〜1596) |
| [Aftermath](https://github.com/mokume-metal/probes/tree/9b771a1/Aftermath) | 失敗を起こした後のフレーム | `v0.16.2` | 7 件 (mokume#342・mokume#1065・mokume#1179・mokume#1469・mokume#1587・mokume#1622・mokume#1623) |
| [Imprint](https://github.com/mokume-metal/probes/tree/9b771a1/Imprint) | 書き出したファイルの中身 | `v0.16.2` | 15 件 (mokume#911・mokume#927・mokume#1219・mokume#1282・mokume#1456・mokume#1457・mokume#1626〜1628・mokume#2024〜2027・mokume#2307・mokume#2313) |
| [Lattice](https://github.com/mokume-metal/probes/tree/9b771a1/Lattice) | 条件の格子の上で成り立つはずの関係 | `v0.16.2` | 6 件 (mokume#1637〜1642) |
| [Weave](https://github.com/mokume-metal/probes/tree/9b771a1/Weave) | 機能を組み合わせたときだけ崩れる継ぎ目 | `v0.16.2` | 18 件 (mokume#1588・mokume#1641・mokume#1643〜1646・mokume#1648〜1658・mokume#1681) |
| [Tumble](https://github.com/mokume-metal/probes/tree/9b771a1/Tumble) | 乱数から作った呼び出しの列 | `v0.16.2` | 10 件 (mokume#1065・mokume#1587・mokume#1589・mokume#1591・mokume#1594・mokume#1595・mokume#1604・mokume#1622・mokume#1691・mokume#1692) |
| [Churn](https://github.com/mokume-metal/probes/tree/9b771a1/Churn) | 足し・消し・動かし続けた絵の履歴・数・同一性 | `v0.22.0` | 2 件 (mokume#2305・mokume#2306) |

代償として、これらの観点 (フレームをまたぐ継ぎ目・条件の格子・機能の組み合わせ・資源・書き出し・乱数の列など) は、
新しい版の上ではもう測られない。

測り方は 4 通りある。

- **Atlas** は語彙の台帳 (`ledger/`) を持ち、`checks.json` に版の刻印を持つ。
  `python3 scripts/verify.py --check` が「道具を上げたのに測り直していない」を捕まえる。
- **Routine** は、同じ結果になるはずの 2 つの経路で描いて画素で比べる検査
  (`Tests/`) を持つ。破れていた約束は `withKnownIssue` で包んであり、**mokume 側で直ると
  赤くなって知らせる。**
- **Reach** は届く口の一覧 (`Sources/Reach/Entries*.swift`) を持ち、`swift test` で「届くと判定した
  口が描けるか」と「README の表が一覧と揃っているか」を見る。**穴が埋まったことは赤くならない**
  ので、版上げでは `python3 scripts/api-diff.py` で増えた口を一覧と突き合わせる。
- **Clause** は、DocC・ADR が書いた約束の 1 文ごとに、mokume だけで閉じた再現を置き、それを検査にする (`Tests/`)。
  再現は陰性対照 (破れない隣の条件) を先に確かめてから破れる条件を見るので、突けていないのに破れと数える取り違えが無い。
  判定は画素の指紋ではなく値・ファイル・ポート・知らせの行で行う。破れは Routine と同じく `withKnownIssue` で包んである。

**画素を見る 2 本 (Routine・Reach) は、条件を変えて何度も回せる。**
[`scripts/stress.py`](scripts/stress.py) が、次の条件で同じ検査を繰り返す。

- そのまま
- Metal の検証レイヤを有効にする
- 同じ物差しを数本同時に回す

見るのは次の 2 つである。

- **終わり方** — 落ちた・止まった・既知の問題の件数がゆれた
- **描いた絵の指紋** — 同じフレーム番号からはバイト単位で同じ絵が出る約束 (mokume ADR-0001
  原則 2) なので、実行をまたいで食い違えば、許容誤差の内のずれでも破れである

稀にしか出ない GPU 同期と並行性の破れを捕まえるための道具である
([ADR-0007](docs/decisions/0007-stress-and-determinism.md))。

## 並べ方

**1 本 = 1 フォルダ = 1 SwiftPM パッケージ。** これは `mokume` の単位である — `run` /
`watch` はディレクトリ直下の `Package.swift` を求め、実行ファイルの名前を `products` から取る。
道具 ([`scripts/pieces.py`](scripts/pieces.py)) も、直下に `Package.swift` を持つ
ディレクトリを 1 本として数える。

```
<物差し>/
  Package.swift        products に実行ファイルを 1 つ宣言する (Atlas は持たない)
  Package.resolved     どの mokume で測ったか。コミットする
  README.md            その物差しの記録
  Sources/<物差し>/     スケッチ
  Tests/<物差し>Tests/  画素で比べる検査 (Routine・Reach)・約束の 1 文を確かめる検査 (Clause)
```

**Atlas だけがこの形に収まらない。** Processing の例 157 本を**それぞれ独立した mokume の
スケッチ**として持ち、1 フォルダの中に 157 個の `Package.swift` がある。引数で例を選ぶ形を
やめたのは、`mokume watch` が通らないためである。`Atlas/Package.swift` は例が引く共有の面と
版の正本を持つ (executable は無い)。入れ子の 157 枚は `pieces.py` が拾わないので、Atlas は
1 本と数えられる。

```bash
mokume watch Atlas/Examples/Basics/Input/Mouse2D
```

## 走らせる

```bash
mokume run Routine                    # 窓で 2 つの経路を並べて見る
(cd Routine && swift test)            # 窓を出さずに描いて、画素で比べる
(cd Reach && swift test)
(cd Clause && swift test)             # 約束の 1 文を値・ファイル・ポートで
python3 scripts/verify.py --check     # Atlas の台帳の版がずれていないか
python3 scripts/stress.py             # 画素を見る 2 本を反復・検証レイヤ・同時実行で
(cd Routine && PROBES_SHOTS=/tmp/shots swift test)   # 読んだ絵を /tmp/shots/Routine/<名前>-<フレーム>.png に書き出す
python3 scripts/shots.py /tmp/shots/Routine glyphChurn --frames 1-2   # 経路 2 つと差分を 1 枚 (2 枚以上なら GIF) に組む
```

画素を見る 2 本は、`PROBES_SHOTS` を付けると読んだ絵を指紋と同じ名前で書き出す。mokume へ起票する
ときに添える比べる絵の元で、組み方と上げ方は [`.claude/skills/probes-evidence/`](.claude/skills/probes-evidence/SKILL.md)
にある。

道具は Homebrew で入る:

```bash
brew install mokume-metal/tap/mokume
```

## 版を追う

```bash
python3 scripts/status.py      # どれが遅れているか
python3 scripts/api-diff.py    # 何が変わったか
python3 scripts/upstream.py    # 戻した Issue がどうなったか
```

新しい版が出ると、`mokume watch` の workflow が日次で気付いて追随の Issue を立てる。
手順は [`.claude/skills/probes-bump/`](.claude/skills/probes-bump/SKILL.md) にある。

**Atlas・Routine・Reach は mokume `v0.16.2`、Clause は `v0.35.0` を引いている。** Routine・Reach は `v0.11.1`、
Clause は `v0.22.1` で始め (測る版で始めた)、Atlas・Routine・Reach は `v0.16.2` へ、Clause は `v0.35.0` の破れを起票するために
1 本だけ `v0.35.0` へ上げた (#80)。
