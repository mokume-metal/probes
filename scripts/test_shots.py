"""shots.py の読み取りと組み立てを確かめる (GPU も swift も要らない)。

    python3 -m unittest discover -s scripts -p 'test_*.py'

絵の組み立ては Pillow があるときだけ確かめる。それ以外 (名前の対・フレームと範囲の読み方・
差分の数え方・Pillow が無いときの終わり方) は、いつでも回る。
"""

import contextlib
import importlib.util
import io
import pathlib
import sys
import tempfile
import unittest

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import shots  # noqa: E402

HAS_PILLOW = importlib.util.find_spec("PIL") is not None


class ParseFrames(unittest.TestCase):
    def test_single_range_and_list(self):
        self.assertEqual(shots.parse_frames("2"), [2])
        self.assertEqual(shots.parse_frames("1-4"), [1, 2, 3, 4])
        self.assertEqual(shots.parse_frames("1,3, 5-6"), [1, 3, 5, 6])

    def test_rejects_zero_and_reversed(self):
        for text in ["0", "3-1", "0-2"]:
            with self.assertRaises(ValueError, msg=text):
                shots.parse_frames(text)


class ParseCrop(unittest.TestCase):
    def test_reads_four_values(self):
        self.assertEqual(shots.parse_crop("60,60,100,100"), (60, 60, 100, 100))

    def test_rejects_empty_or_wrong_count(self):
        for text in ["10,10,10,20", "10,10,20", "20,10,10,20", "-1,0,4,4"]:
            with self.assertRaises(ValueError, msg=text):
                shots.parse_crop(text)


class PairNames(unittest.TestCase):
    def test_default_is_the_two_routes(self):
        self.assertEqual(shots.pair_names("addSky"), ("addSky-suspect", "addSky-reference"))

    def test_explicit_pair(self):
        self.assertEqual(shots.pair_names("x", "mirror-a", "mirror-b"), ("mirror-a", "mirror-b"))

    def test_half_a_pair_is_an_error(self):
        with self.assertRaises(ValueError):
            shots.pair_names("x", left="mirror-a")

    def test_path_matches_what_shoot_writes(self):
        # Stage.swift の shoot は、文字・数字・`-` 以外を `_` に替えて `<name>-<frame>.png` に書く
        base = pathlib.Path("/tmp/shots/Reach")
        self.assertEqual(shots.shot_path(base, "addSky-suspect", 2), base / "addSky-suspect-2.png")
        self.assertEqual(shots.shot_path(base, "rect(x, y)", 1), base / "rect_x__y_-1.png")


class DiffMask(unittest.TestCase):
    def test_counts_only_differences_beyond_one_step(self):
        left = [(0, 0, 0), (10, 10, 10), (200, 0, 0), (5, 5, 5)]
        right = [(0, 0, 0), (11, 10, 10), (0, 0, 200), (5, 7, 5)]
        mask, count = shots.diff_mask(left, right)
        # 1 段の差 (10 → 11) は同じとみなし、2 段 (5 → 7) からは違うとみなす
        self.assertEqual(count, 2)
        self.assertEqual(mask[2], shots.MARK)
        self.assertEqual(mask[3], shots.MARK)
        self.assertNotEqual(mask[1], shots.MARK)

    def test_size_mismatch_is_an_error(self):
        with self.assertRaises(ValueError):
            shots.diff_mask([(0, 0, 0)], [(0, 0, 0), (0, 0, 0)])


class MissingPillow(unittest.TestCase):
    def test_names_how_to_install_and_exits_2(self):
        stderr = io.StringIO()
        with contextlib.redirect_stderr(stderr), self.assertRaises(SystemExit) as caught:
            shots.load_pillow("no_such_pillow_module_for_test")
        self.assertEqual(caught.exception.code, 2)
        self.assertIn("pip install pillow", stderr.getvalue())


class VersionStamp(unittest.TestCase):
    def test_reads_the_pinned_mokume(self):
        # Weave は測り始めた版を Package.resolved に持つ
        self.assertRegex(shots.version_stamp("Weave"), r"^mokume v\d+\.\d+\.\d+ \([0-9a-f]{7}\)$")

    def test_unknown_ruler_is_empty(self):
        self.assertEqual(shots.version_stamp("NoSuchRuler"), "")


@unittest.skipUnless(HAS_PILLOW, "Pillow が無い")
class Compose(unittest.TestCase):
    def setUp(self):
        from PIL import Image

        self.Image = Image
        self.temp = tempfile.TemporaryDirectory()
        self.dir = pathlib.Path(self.temp.name) / "Weave"
        self.dir.mkdir()
        # 1 枚目は同じ絵、2 枚目は右上の 3 × 2 画素だけ違う絵
        for frame in (1, 2):
            left = Image.new("RGB", (8, 8), (0, 0, 0))
            right = Image.new("RGB", (8, 8), (0, 0, 0))
            if frame == 2:
                for x in range(5, 8):
                    for y in range(0, 2):
                        left.putpixel((x, y), (255, 255, 255))
            left.save(shots.shot_path(self.dir, "k-suspect", frame))
            right.save(shots.shot_path(self.dir, "k-reference", frame))

    def tearDown(self):
        self.temp.cleanup()

    def run_main(self, *args):
        stdout = io.StringIO()
        with contextlib.redirect_stdout(stdout):
            self.assertEqual(shots.main([str(self.dir), "k", *args]), 0)
        return stdout.getvalue()

    def test_still_counts_the_differing_pixels(self):
        output = self.run_main("--frames", "2", "--crop", "4,0,8,4")
        self.assertIn("2 枚目: 6 画素が違う", output)
        out = self.dir.parent / "composed" / "Weave-k.png"
        self.assertTrue(out.exists())
        # 3 枚並び (8 × 3 倍) と拡大の段が入る大きさ
        with self.Image.open(out) as image:
            width, height = image.size
        self.assertEqual(width, shots.MARGIN * 2 + 8 * 3 * 3 + shots.GAP * 2)
        self.assertGreater(height, 8 * 3 + 4 * 8)

    def test_several_frames_make_a_gif(self):
        output = self.run_main("--frames", "1-2")
        self.assertIn("1 枚目: 0 画素が違う", output)
        with self.Image.open(self.dir.parent / "composed" / "Weave-k.gif") as gif:
            self.assertEqual(getattr(gif, "n_frames", 1), 2)

    def test_missing_shot_names_the_path(self):
        with self.assertRaises(SystemExit) as caught, contextlib.redirect_stdout(io.StringIO()):
            shots.main([str(self.dir), "k", "--frames", "3"])
        self.assertIn("k-suspect-3.png", str(caught.exception.code))


if __name__ == "__main__":
    unittest.main()
