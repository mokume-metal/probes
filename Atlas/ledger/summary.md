| 区分 | 例数 | |
| --- | ---: | --- |
| `clean` | 140 | そのまま届く |
| `write-only` | 7 | 書けば届く |
| `bend` | 34 | 書けるが歪む |
| `blocked` | 22 | 口が無くて止まる |
| `out-of-scope` | 51 | 測らないと決めた |
| **合計** | **254** | |

公式ページに載る 162 本を、**原典と並べられるか**で分けたもの。

| 並べられるか | 例数 | |
| --- | ---: | --- |
| `draws` | 150 | そのまま絵が出る |
| `bent` | 12 | 歪めれば絵は出る |
| **合計** | **162** | |

原典は 156 本が p5 (`liveSketch.js`)、6 本は site が置く静止画だけ。

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate |
| 12 | `colorMode` | `bend` | color(hue:saturation:brightness:) |
| 6 | `QUAD_STRIP` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 6 | `getChild` | `none` | — |
| 5 | `GROUP` | `none` | — |
| 5 | `addChild` | `bend` | Shape.group |
| 4 | `getChildCount` | `none` | — |
| 4 | `getVertexCount` | `bend` | — |
| 4 | `millis` | `none` | — |
| 4 | `setFill` | `none` | — |
| 3 | `getVertex` | `none` | — |
| 3 | `setMag` | `write` | — |
| 3 | `setStroke` | `none` | — |
| 3 | `setVertex` | `none` | — |
| 2 | `disableStyle` | `none` | — |
| 2 | `list` | `none` | — |
| 2 | `random2D` | `write` | — |
| 2 | `saveFrame` | `bend` | save(_:) |
| 2 | `second` | `none` | — |
| 1 | `angleBetween` | `write` | — |
