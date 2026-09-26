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
| [Atlas](Atlas/) | Processing の Examples を全数で当てた台帳と、[公式ページ](https://processing.org/examples/)の 162 本のうち移せる 157 本の実測。**作品ではなく物差し**で、1 本ずつでは出ない「どの欠けが何本の例を止めるか」を数える。**mokume `v0.6.0` で 26 本が `clean` へ移り、台帳が重いと数えた欠けから順に埋まった** |
| [Probe](Probe/) | mokume `v0.11.0` の継ぎ目を突いた記録。**作品ではなく物差し**で、候補 1 件を同じ絵になるはずの 2 つの経路で描き、窓では左右に並べて目で、`swift test` では画素で比べる。**13 件を突いて 8 件が約束を破っており、mokume へ 8 件の Bug と 1 件の docs を戻した** (鏡映した立体の裏面・透明な下地の上の混ぜ方・楕円の `arc`・`curveVertex` の穴・範囲外の不透明度・細い線の濃さ・右揃えの末尾の空白・`lerp` の端)。直ると `withKnownIssue` が赤くなって知らせる |
| [Drift](Drift/) | mokume `v0.11.0` の**フレームをまたぐ**継ぎ目を突いた記録。Probe と同じく**作品ではなく物差し**で、候補 1 件を同じ動きになるはずの 2 つの経路で描き、窓では左右に並べた動きで、`swift test` では `SketchRuntime` で N 枚回して画素で比べる。**6 件を突いて 6 件とも約束を破っており、mokume へ 6 件の Bug を戻した** (描き場所の時刻・噴き口どうしの繰り越し・残像への効果の焼き込み・`numbers` の寿命・低い fps の `drag`・止まっている間の変換)。1 枚目では食い違わず、フレームを重ねてはじめてずれる |
| [Routine](Routine/) | mokume `v0.11.1` を、**作品がふつう書く書き方**で動かして突いた記録。Probe・Drift と違って**中身を読まずに**、Processing・p5 の作品が当たり前に書く組み合わせ (`setup` で決めた描き方・残像・画素の読み書き・層・脈打つ大きさ・お絵描き・押し続けるキー…) を 25 通り選び、フレームを重ねて 2 つの経路で比べる。**25 件を突いて約束の破れは 0 件**。期待と違った 3 件は説明か ADR が決めている振る舞いで、説明に無かった 1 件 (`background` の不透明度) を docs として戻した |
| [Reach](Reach/) | Processing / p5.js で**作品を作るときにまず使う口**を百余り、リファレンスの側から並べ、1 口 1 タイルで mokume `v0.11.1` で書いた記録。**作品ではなく物差し**で、Atlas が Examples に出てくる語彙しか見ないのに対して、例に出てこない口 (角の丸い `rect`・`erase`・`cursor`・`millis` など) も測る。穴のうち、**works の作品 2 本以上が手で書いていたもの**と規範から導けるものだけを mokume へ戻した (QUADS・`lerpColor`・`fill(rgb, alpha)`・`millis`・`deltaTime` の単位・名前の棚卸し) |
| [Soak](Soak/) | mokume `v0.11.1` を**長く回したときの資源**を突いた記録。**作品ではなく物差し**で、他の物差しが絵を比べるのに対し、1 枚ごとに増えて減らないメモリ・仕事に見合わない時間・プロセスごと落ちる口を見る。候補 1 件を同じ仕事になるはずの 2 つの経路で回し、footprint と GPU の確保量の増え方・時間の比・exit test の終わり方で比べる。**11 件の破れを見つけ、mokume へ 10 件の Bug と perf を戻し、1 件を既知の Issue ([mokume#1431](https://github.com/mokume-metal/mokume/issues/1431)) へ足した** (閉じ忘れた `beginShape`・`beginDraw` の外の描き場所・`loadModel` の控え・main を譲らない `advance()`・多角形の分割・立体の既定の線・巨大な `textSize` と数でない `textOutline`・`createShape` の中の `background`・`makeNumbers` のあふれ・`DisplayImage` の範囲外) |
| [Aftermath](Aftermath/) | mokume `v0.11.2` で**失敗を起こした後のフレーム**が汚れないかを突いた記録。**作品ではなく物差し**で、資源の生成が投げる・フレームの途中で放り出す・数でない値を渡す、といった失敗を途中のフレームで起こし、その後の絵を失敗させなかった参照と画素で比べる。**16 件を突き、2 件が約束を破っていたので mokume へ 2 件の Bug を戻した** (`endDraw` の無い描き場所で変換が積み上がる・数でない力で生きている粒が消える)。資源の生成が投げる 8 通りは、どれも 1 画素も汚さなかった |
| [Imprint](Imprint/) | mokume `v0.11.2` が**書き出したファイルの中身**を突いた記録。**作品ではなく物差し**で、各フレームに番号を 2 値の升で焼き、`save`・連番・`.mov` を読み戻して、枚数・順序・時刻の間隔・色の刻印・バイトの一致を見る。**10 件を突き、3 件が約束を破っていたので mokume へ 3 件の Bug を戻した** (録画中の `save` の失敗で動画が途切れる・同じ名前への `save` の順序が崩れる・`.mov` の容れ物の時刻でバイトが一致しない)。後の 2 件は `stress.py` で反復してはじめて見えた |
| [Lattice](Lattice/) | mokume `v0.12.0` を**条件の格子**の上で動かし、**成り立つはずの関係**で突いた記録。**作品ではなく物差し**で、他の物差しが 160²・細かさ 1・30 fps の 1 点で mokume の別経路と比べるのに対し、面の大きさ・縦横比・`pixelDensity`・fps を振り、鏡映・90° 回転・切り抜き・細かさと縮小・fps をまたいだ 1 秒などの関係で比べる。**14 通りの関係を突き、6 通りが約束を破っていたので mokume へ 6 件を戻した** (細かさ 0.5 で三角形の経路の細い線が消える・拡大段が乗算済みの決まりを破る・利用者の効果の `Pixel.position`・fps 25/50/100 の `emit`・`clip` の小数の丸め・`frameRate` 0 を断らない)。6 件とも細かさか fps を 1 点から動かした所で出た |
| [Weave](Weave/) | mokume `v0.12.0` で**機能を組み合わせたときだけ崩れる継ぎ目**を突いた記録。**作品ではなく物差し**で、1 つずつなら正しく動く機能を組み合わせて 1 回で描き、同じ機能を 1 つずつ使って合成した絵と画素で比べる。**19 件を突き、16 件が約束を破っていたので mokume へ 15 件の Bug を戻し、1 件を Lattice の起票 (mokume#1641) へ足した** (加算の混ぜ方で輪郭の内側の塗りが消える・粒が `texture` / `shader` に染まる・1 フレームに 2 回描いた粒が消える・本体の断片の `set` が描き場所に効かない・`get` を挟むと影が割れる・`clip` の中の `background` が面全体を塗る ほか)。落ちる組み合わせ 1 件を mokume#1588 へ足した |

測り方は 6 通りある。

- **Atlas** は語彙の台帳 (`ledger/`) を持ち、`checks.json` に版の刻印を持つ。
  `python3 scripts/verify.py --check` が「道具を上げたのに測り直していない」を捕まえる。
- **Probe・Drift・Routine・Aftermath・Weave** は、同じ結果になるはずの 2 つの経路で描いて画素で比べる検査
  (`Tests/`) を持つ。破れていた約束は `withKnownIssue` で包んであり、**mokume 側で直ると
  赤くなって知らせる。**
- **Reach** は届く口の一覧 (`Sources/Reach/Entries*.swift`) を持ち、`swift test` で「届くと判定した
  口が描けるか」と「README の表が一覧と揃っているか」を見る。**穴が埋まったことは赤くならない**
  ので、版上げでは `python3 scripts/api-diff.py` で増えた口を一覧と突き合わせる。
- **Soak** は、同じ仕事になるはずの 2 つの経路を N 枚回して**資源**で比べる検査 (`Tests/`) を持つ。
  メモリは参照との増え方の差、時間は仕事を倍にしたときの比で見るので、機械に依らない。落ちる口は
  exit test (子プロセス) に閉じ込める。破れは Probe と同じく `withKnownIssue` で包んである。
- **Imprint** は、各フレームに番号を焼いて書き出させ、**ファイルを読み戻して**枚数・順序・時刻・
  色・バイトを比べる検査 (`Tests/`) を持つ。稀にしか出ない破れは `isIntermittent` で包んであり、
  直ったかどうかは `stress.py` で反復して見る。
- **Lattice** は、条件 (面の大きさ・細かさ・fps) を振った絵どうしを、**成り立つはずの関係**
  (鏡映・回転・切り抜き・縮小…) で比べる検査 (`Tests/`) を持つ。関係は mokume のどの経路にも
  頼らない。破れは Probe と同じく `withKnownIssue` で包んである。

**画素を見る 7 本 (Probe・Drift・Routine・Reach・Aftermath・Lattice・Weave) と Imprint は、条件を変えて何度も回せる。**
[`scripts/stress.py`](scripts/stress.py) が、次の条件で同じ検査を繰り返す。

- そのまま
- Metal の検証レイヤを有効にする
- 同じ物差しを数本同時に回す

見るのは次の 2 つである。

- **終わり方** — 落ちた・止まった・既知の問題の件数がゆれた
- **描いた絵の指紋** — 同じフレーム番号からはバイト単位で同じ絵が出る約束 (mokume ADR-0001
  原則 2) なので、実行をまたいで食い違えば、許容誤差の内のずれでも破れである (画素を見る 7 本だけ)

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
  Tests/<物差し>Tests/  画素で比べる検査 (Probe・Drift・Routine)・資源で比べる検査 (Soak)
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
mokume run Probe                      # 窓で左右に並べて見る
(cd Probe && swift test)              # 窓を出さずに描いて、画素で比べる
(cd Drift && swift test)
(cd Routine && swift test)
(cd Reach && swift test)
(cd Soak && swift test)               # メモリ・時間・落ちるか (30 秒ほど)
(cd Aftermath && swift test)          # 失敗の後のフレームが汚れないか
(cd Imprint && swift test)            # 書き出したファイルの中身
(cd Lattice && swift test)            # 条件を振った絵どうしの関係
(cd Weave && swift test)              # 機能を組み合わせたときだけ崩れる継ぎ目
python3 scripts/verify.py --check     # Atlas の台帳の版がずれていないか
python3 scripts/stress.py             # 画素を見る 7 本と Imprint を反復・検証レイヤ・同時実行で (数十分)
(cd Weave && PROBES_SHOTS=/tmp/shots swift test)   # 読んだ絵を /tmp/shots/Weave/<名前>-<フレーム>.png に書き出す
python3 scripts/shots.py /tmp/shots/Weave addSky --frames 1-2   # 経路 2 つと差分を 1 枚 (2 枚以上なら GIF) に組む
```

画素を見る 7 本は、`PROBES_SHOTS` を付けると読んだ絵を指紋と同じ名前で書き出す。mokume へ起票する
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

**Atlas は mokume `v0.9.0`、Probe と Drift は `v0.11.0`、Routine・Reach・Soak は `v0.11.1`、Aftermath・Imprint は `v0.11.2`、Lattice・Weave は `v0.12.0` を引いている**
(後の 9 本は、測る版で始めた)。
