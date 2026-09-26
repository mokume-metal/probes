#!/usr/bin/env python3
"""物差しが書き出した絵から、mokume へ起票するときに添える**比べる絵**を組む。

画素を見る物差しは、環境変数 `PROBES_SHOTS=<dir>` を付けて `swift test` を回すと、読んだ絵を
`fingerprint` と同じ名前とフレームで `<dir>/<物差し>/<name>-<frame>.png` に書き出す
(`Stage.swift` の `shoot`)。ここでは 2 つの経路の絵を対にし、1 枚に組む。

- 3 枚並び: 左の経路・右の経路・差分 (成分が 1/255 を越えて違う画素を桃色で塗る)
- 見出し (mokume#番号と題)・条件の説明・版の刻印 (`<物差し>/Package.resolved` から読む)
- `--crop` を渡すと、その範囲を拡大した段を下に足す
- `--frames` に 2 枚以上を渡すと、フレームを進める GIF にする

    PROBES_SHOTS=/tmp/shots swift test                                   # (cd Weave で) 絵を書き出す
    python3 scripts/shots.py /tmp/shots/Weave addFillStroke --issue 1643 --title "…" --note "…"
    python3 scripts/shots.py /tmp/shots/Weave polylineJoin --crop 60,60,100,100
    python3 scripts/shots.py /tmp/shots/Weave addSky --frames 1-2         # GIF
    python3 scripts/shots.py /tmp/shots/Lattice x --left mirror-a --right mirror-b

対の名前は、既定で `<key>-suspect` と `<key>-reference` (比べる物差しの経路の名前)。それ以外の
対は `--left` / `--right` で名前を渡す。組んだ絵は既定で `<dir>/../composed/<物差し>-<key>.png`
(GIF なら `.gif`) に書く。上げ方は `.claude/skills/probes-evidence/` にある。

組み立てには Pillow が要る。無ければ入れ方を名乗って終了コード 2 で止まる。
"""

from __future__ import annotations

import argparse
import importlib
import json
import pathlib
import sys
from typing import List, Optional, Sequence, Tuple

ROOT = pathlib.Path(__file__).resolve().parent.parent
PILLOW = "PIL"
FONTS = {
    "regular": ["/System/Library/Fonts/ヒラギノ角ゴシック W3.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"],
    "bold": ["/System/Library/Fonts/ヒラギノ角ゴシック W6.ttc", "/System/Library/Fonts/Hiragino Sans GB.ttc"],
}
# 差分とみなす成分の差 (0–255)。表示の 1 段を越えたものだけを塗る
TOLERANCE = 1
MARK = (255, 0, 200)
BACKGROUND = (250, 250, 250)
INK = (30, 30, 30)
SUBTLE = (110, 110, 110)
FRAME_INK = (200, 0, 120)
BOX = (255, 200, 0)
MARGIN = 20
GAP = 20

Pixel = Tuple[int, ...]


# MARK: - Pillow の要らない部分


def parse_frames(text: str) -> List[int]:
    """`2`・`1-6`・`1,3,5` を、1 始まりのフレーム番号の並びにする。"""
    frames: List[int] = []
    for part in text.split(","):
        part = part.strip()
        if "-" in part:
            first, last = (int(p) for p in part.split("-", 1))
            if first > last:
                raise ValueError(f"フレームの範囲が逆: {part}")
            frames.extend(range(first, last + 1))
        else:
            frames.append(int(part))
    if not frames or min(frames) < 1:
        raise ValueError(f"フレームは 1 始まり: {text}")
    return frames


def parse_crop(text: str) -> Tuple[int, int, int, int]:
    """`x0,y0,x1,y1` (右端・下端は含まない) を読む。"""
    values = [int(v) for v in text.split(",")]
    if len(values) != 4:
        raise ValueError(f"crop は x0,y0,x1,y1 の 4 つ: {text}")
    x0, y0, x1, y1 = values
    if x0 >= x1 or y0 >= y1 or x0 < 0 or y0 < 0:
        raise ValueError(f"crop の範囲が空か負: {text}")
    return x0, y0, x1, y1


def pair_names(key: str, left: Optional[str] = None, right: Optional[str] = None) -> Tuple[str, str]:
    """対にする 2 つの名前。既定は比べる物差しの経路の名前 (`<key>-suspect` / `<key>-reference`)。"""
    if (left is None) != (right is None):
        raise ValueError("--left と --right は両方渡す")
    return (left, right) if left is not None else (f"{key}-suspect", f"{key}-reference")


def shot_path(directory: pathlib.Path, name: str, frame: int) -> pathlib.Path:
    """`shoot` が書いた絵の在処。名前の書き換えは `Stage.swift` の `shoot` と揃える。"""
    safe = "".join(c if c.isalnum() or c == "-" else "_" for c in name)
    return directory / f"{safe}-{frame}.png"


def diff_mask(left: Sequence[Pixel], right: Sequence[Pixel], tolerance: int = TOLERANCE) -> Tuple[List[Pixel], int]:
    """画素ごとの差分の絵と、違う画素の数。違う画素は桃色、同じ画素は右の絵を暗くした灰色で塗る。"""
    if len(left) != len(right):
        raise ValueError(f"大きさが違う: {len(left)} と {len(right)} 画素")
    out: List[Pixel] = []
    count = 0
    for a, b in zip(left, right):
        if max(abs(a[i] - b[i]) for i in range(3)) > tolerance:
            out.append(MARK)
            count += 1
        else:
            g = (b[0] + b[1] + b[2]) // 3 // 4 + 20
            out.append((g, g, g))
    return out, count


def version_stamp(ruler: str) -> str:
    """`<物差し>/Package.resolved` が固定している mokume の版 (`v0.12.0 (bab3b4a)`)。読めなければ空。"""
    path = ROOT / ruler / "Package.resolved"
    try:
        pins = json.loads(path.read_text())["pins"]
    except (OSError, ValueError, KeyError):
        return ""
    for pin in pins:
        if pin.get("identity") == "mokume":
            state = pin.get("state", {})
            return f"mokume v{state.get('version', '?')} ({state.get('revision', '')[:7]})"
    return ""


def load_pillow(module: str = PILLOW):
    """Pillow を読む。無ければ入れ方を名乗って終了コード 2 で止まる。"""
    try:
        return importlib.import_module(module)
    except ImportError:
        sys.stderr.write(
            "shots.py は Pillow で絵を組む。入っていない。例えば次のように venv へ入れて、その python で回す:\n"
            "  python3 -m venv /tmp/shots-venv && /tmp/shots-venv/bin/pip install pillow\n"
            "  /tmp/shots-venv/bin/python scripts/shots.py …\n"
        )
        raise SystemExit(2)


# MARK: - 組み立て (Pillow)


class Composer:
    def __init__(self, zoom: int = 3, crop_zoom: int = 8):
        load_pillow()
        from PIL import Image, ImageDraw, ImageFont

        self.Image, self.ImageDraw = Image, ImageDraw
        self.zoom, self.crop_zoom = zoom, crop_zoom
        self.fonts = {
            "title": self._font(ImageFont, "bold", 20),
            "caption": self._font(ImageFont, "regular", 16),
            "small": self._font(ImageFont, "regular", 13),
        }

    @staticmethod
    def _font(ImageFont, weight: str, size: int):
        for path in FONTS[weight]:
            if pathlib.Path(path).exists():
                return ImageFont.truetype(path, size)
        return ImageFont.load_default()

    def load(self, path: pathlib.Path):
        if not path.exists():
            raise SystemExit(f"絵が無い: {path} (PROBES_SHOTS を付けて swift test を回したか・名前とフレームが合っているか)")
        return self.Image.open(path).convert("RGB")

    def diff(self, left, right):
        if left.size != right.size:
            raise SystemExit(f"大きさが違う: {left.size} と {right.size}")
        # Pillow 12 から getdata は非推奨 (14 で消える)。新しい口があればそちらを使う
        flat = (lambda im: list(im.get_flattened_data())) if hasattr(left, "get_flattened_data") else (
            lambda im: list(im.getdata()))
        pixels, count = diff_mask(flat(left), flat(right))
        image = self.Image.new("RGB", left.size)
        image.putdata(pixels)
        return image, count

    def row(self, canvas, draw, y, images, captions, zoom, crop=None, box=None):
        x = MARGIN
        for image, caption in zip(images, captions):
            if crop:
                image = image.crop(crop)
            big = image.resize((image.size[0] * zoom, image.size[1] * zoom), self.Image.NEAREST)
            draw.text((x, y), caption, font=self.fonts["caption"], fill=INK)
            canvas.paste(big, (x, y + 26))
            draw.rectangle([x - 1, y + 25, x + big.size[0], y + 26 + big.size[1]], outline=(180, 180, 180))
            if box:
                x0, y0, x1, y1 = box
                draw.rectangle(
                    [x + x0 * zoom, y + 26 + y0 * zoom, x + x1 * zoom - 1, y + 26 + y1 * zoom - 1], outline=BOX, width=2)
            x += big.size[0] + GAP
        return y + 26 + big.size[1]

    def compose(self, left, right, *, heading: str, note: str, footer: str, labels: Tuple[str, str],
                crop: Optional[Tuple[int, int, int, int]] = None, footer_ink=SUBTLE):
        """1 フレームぶんの 3 枚並び。返すのは (絵, 違う画素の数)。"""
        mask, count = self.diff(left, right)
        w, h = left.size
        z, cz = self.zoom, self.crop_zoom
        crop_h = (crop[3] - crop[1]) * cz + GAP + 26 if crop else 0
        width = MARGIN * 2 + w * z * 3 + GAP * 2
        height = MARGIN + 30 + 22 + 16 + 26 + h * z + crop_h + 16 + 20 + MARGIN
        canvas = self.Image.new("RGB", (width, height), BACKGROUND)
        draw = self.ImageDraw.Draw(canvas)
        draw.text((MARGIN, MARGIN), heading, font=self.fonts["title"], fill=INK)
        draw.text((MARGIN, MARGIN + 30), note, font=self.fonts["small"], fill=SUBTLE)
        y = MARGIN + 30 + 22 + 16
        captions = [labels[0], labels[1], f"差分 (桃色: {count} 画素)"]
        y = self.row(canvas, draw, y, [left, right, mask], captions, z, box=crop)
        if crop:
            self.row(canvas, draw, y + GAP, [left, right, mask], [f"{c.split(' (')[0]} の拡大 ×{cz}" for c in captions], cz,
                     crop=crop)
        draw.text((MARGIN, height - MARGIN - 16), footer, font=self.fonts["caption"], fill=footer_ink)
        return canvas, count


def main(argv: Optional[Sequence[str]] = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("directory", type=pathlib.Path, help="`<PROBES_SHOTS>/<物差し>`")
    parser.add_argument("key", help="候補の鍵 (対の名前の既定と、出力の名前に使う)")
    parser.add_argument("--left", help="左に置く絵の名前 (既定 `<key>-suspect`)")
    parser.add_argument("--right", help="右に置く絵の名前 (既定 `<key>-reference`)")
    parser.add_argument("--left-label", default="疑う経路 (suspect)")
    parser.add_argument("--right-label", default="参照 (reference)")
    parser.add_argument("--frames", default="1", help="`1`・`1-6`・`1,3`。2 枚以上なら GIF")
    parser.add_argument("--issue", type=int, help="見出しに出す mokume の Issue 番号")
    parser.add_argument("--title", default="", help="見出し")
    parser.add_argument("--note", default="", help="見出しの下に出す条件の説明")
    parser.add_argument("--crop", help="拡大する範囲 `x0,y0,x1,y1` (元の画素)")
    parser.add_argument("--zoom", type=int, default=3)
    parser.add_argument("--crop-zoom", type=int, default=8)
    parser.add_argument("--delay", type=int, default=900, help="GIF の 1 枚の長さ (ミリ秒)")
    parser.add_argument("--out", type=pathlib.Path)
    args = parser.parse_args(argv)

    try:
        frames = parse_frames(args.frames)
        crop = parse_crop(args.crop) if args.crop else None
        left_name, right_name = pair_names(args.key, args.left, args.right)
    except ValueError as error:
        parser.error(str(error))

    composer = Composer(zoom=args.zoom, crop_zoom=args.crop_zoom)
    ruler = args.directory.resolve().name
    heading = " ".join(p for p in [f"mokume#{args.issue}" if args.issue else "", args.title or args.key] if p)
    stamp = version_stamp(ruler)
    animated = len(frames) > 1
    out = args.out or args.directory.resolve().parent / "composed" / f"{ruler}-{args.key}.{'gif' if animated else 'png'}"
    out.parent.mkdir(parents=True, exist_ok=True)

    pictures = []
    for frame in frames:
        left = composer.load(shot_path(args.directory, left_name, frame))
        right = composer.load(shot_path(args.directory, right_name, frame))
        footer_parts = [f"{frame} 枚目" + (f" / {len(frames)}" if animated else ""), stamp,
                        f"{left.size[0]}×{left.size[1]} を ×{args.zoom} (最近傍)", f"probes {ruler} `{args.key}`"]
        picture, count = composer.compose(
            left, right, heading=heading, note=args.note, footer="  —  ".join(p for p in footer_parts if p),
            labels=(args.left_label, args.right_label), crop=crop, footer_ink=FRAME_INK if animated else SUBTLE)
        pictures.append(picture)
        print(f"{frame} 枚目: {count} 画素が違う")
    if animated:
        pictures[0].save(out, save_all=True, append_images=pictures[1:], duration=args.delay, loop=0, optimize=True)
    else:
        pictures[0].save(out)
    print(out)
    return 0


if __name__ == "__main__":
    sys.exit(main())
