---
name: probes-evidence
description: "mokume へ Bug を起票するとき・起票した Issue に絵が無いときに読む。物差しが読んだ絵を PROBES_SHOTS で書き出し、scripts/shots.py で 3 枚並び (経路 2 つと差分)・拡大・GIF に組み、Chrome で GitHub の添付へ上げて本文に差し込むまでの手順。Use when filing a mokume bug from a probes ruler, when attaching comparison images or GIFs to a GitHub issue, or when running scripts/shots.py."
---

# 起票に比べる絵を添える

**mokume へ起票する破れには、比べる絵を添える。** 数と再現のスケッチだけでは、読む人が破れの形を
描き直さなければならない。絵は GitHub の添付に上げる (Gyazo は一斉に 404 になった。
mokume-metal/works#80)。リポジトリには画像をコミットしない。

## 1. 物差しに絵を書き出させる

```bash
(cd Weave && PROBES_SHOTS=/tmp/shots swift test --filter addSky)
ls /tmp/shots/Weave        # addSky-suspect-1.png addSky-reference-1.png …
```

- 画素を見る 7 本 (Probe・Drift・Routine・Reach・Aftermath・Lattice・Weave) の `Stage.swift` は、
  `fingerprint` に通した絵を、同じ名前とフレームで `<PROBES_SHOTS>/<物差し>/<name>-<frame>.png` に書く
  (`shoot`)。**書き出されるのは、検査が読んだフレームだけ**である。動きを見せたいフレームが要るなら、
  検査の `reading` を広げるか、候補の枚数を増やす。
- 書くのは出す面 (`writePNG` = 表示に符号化した絵)。Lattice の `runDrawn` (`draw()` の中で描く面を
  読む) は、出す面と中身が違うので書き出さない。
- 変数を付けなければ何も書かず、指紋と既知の問題の件数も変わらない。

## 2. 3 枚並びと GIF に組む

```bash
python3 scripts/shots.py /tmp/shots/Weave addFillStroke --issue 1643 \
  --title "blendMode(.add) × 塗りと輪郭" --note "左: … / 中: …。何が起きているか" \
  --left-label "組み合わせて 1 回で描く (suspect)" --right-label "1 つずつ使って合成 (reference)"
python3 scripts/shots.py /tmp/shots/Weave polylineJoin --crop 60,60,100,100      # 拡大の段を足す
python3 scripts/shots.py /tmp/shots/Weave addSky --frames 1-2                    # 2 枚以上は GIF
python3 scripts/shots.py /tmp/shots/Lattice k --left mirror-a --right mirror-b   # 経路以外の対
```

- 出力は `/tmp/shots/composed/<物差し>-<key>.png` (または `.gif`)。版の刻印は `<物差し>/Package.resolved` から入る。
- **1 画素の列や縁の形のように、3 倍では見えない破れには `--crop` を付ける。** 差分の桃色の数は、縁の AA の違いも数える。形で比べる検査 (ADR-0039 決定 1) の画素数とは一致しない。
- **動きで見せる破れ (フレームごとに積もる・1 枚だけ崩れる) は GIF にする。**
- 組んだ絵は、貼る前に 1 度目で見る。見出しの Issue 番号が、貼る先と合っていることも確かめる。
- Pillow が要る。無ければ `shots.py` が入れ方を名乗って止まる (venv に入れてよい)。

## 3. Chrome で GitHub の添付へ上げる

組み込みのブラウザにはファイルを渡す口が無いので、GitHub にログインした Chrome (Claude in Chrome) を使う。

1. 貼る先の Issue (mokume 側) を開く。
2. **添付ボタンは押さない。** OS のファイル選択の窓が開き、操作できない。代わりにページへ入力を足す。

   ```js
   const i = document.createElement('input');
   i.type = 'file'; i.multiple = true; i.id = 'probes-shots';
   document.body.appendChild(i);
   ```

3. `find` でその入力の ref を取り、`file_upload` に組んだ絵を渡す (1 回で 10 MB まで)。
4. コメント欄へ `drop` として流し込む。GitHub が `user-attachments` に上げて、欄に `<img … src="…">` を差し込む。

   ```js
   const ta = document.querySelector('textarea[placeholder="Use Markdown to format your comment"]');
   const dt = new DataTransfer();
   for (const f of document.getElementById('probes-shots').files) dt.items.add(f);
   for (const t of ['dragenter', 'dragover', 'drop'])
     ta.dispatchEvent(new DragEvent(t, { bubbles: true, cancelable: true, dataTransfer: dt }));
   await new Promise(r => setTimeout(r, 8000));
   [...ta.value.matchAll(/src="([^"]+)"/g)].map(m => m[1])
   ```

5. URL を控えたら、**欄は送信せずに空へ戻す**。足した入力も消す。

   ```js
   Object.getOwnPropertyDescriptor(HTMLTextAreaElement.prototype, 'value').set.call(ta, '');
   ta.dispatchEvent(new Event('input', { bubbles: true }));
   document.getElementById('probes-shots').remove();
   ```

## 4. 上がったものを検める

URL の並びは渡した順になるが、**バイトで突き合わせてから使う**。投稿する前の添付は、未認証の取得だと 404 になる。

```bash
curl -sL -H "Authorization: token $(gh auth token)" -o /tmp/got.png https://github.com/user-attachments/assets/<id>
shasum -a 256 /tmp/got.png /tmp/shots/composed/Weave-addFillStroke.png
```

## 5. 本文へ差し込む

- **絵は「事象」の再現のスケッチのすぐ下に置く。** 本文は `gh issue edit --body-file` で書き換える。
- 絵の下に、3 枚が何か (左・中・右) を 1 行で書く。
- 自分のものでない Issue (他の物差しが立てたものなど) へ寄せるときは、本文ではなく自分のコメントに置く。
- 置いたら Issue を開き、絵が読み込まれていることを確かめる (`img.naturalWidth > 0`。画像は遅れて読み込まれるので、見える所まで流してから見る)。
