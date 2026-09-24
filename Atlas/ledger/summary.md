| 区分 | 例数 | |
| --- | ---: | --- |
| `clean` | 100 | そのまま届く |
| `write-only` | 10 | 書けば届く |
| `bend` | 54 | 書けるが歪む |
| `blocked` | 39 | 口が無くて止まる |
| `out-of-scope` | 51 | 測らないと決めた |
| **合計** | **254** | |

公式ページに載る 162 本を、**原典と並べられるか**で分けたもの。

| 並べられるか | 例数 | |
| --- | ---: | --- |
| `draws` | 135 | そのまま絵が出る |
| `bent` | 21 | 歪めれば絵は出る |
| `none` | 6 | 絵が出せない |
| **合計** | **162** | |

原典は 156 本が p5 (`liveSketch.js`)、6 本は site が置く静止画だけ。

| 何本の例を止めるか | 語彙 | 判定 | mokume では |
| ---: | --- | --- | --- |
| 25 | `PVector` | `bend` | SIMD2<Float> / SIMD3<Float> |
| 20 | `frameRate` | `bend` | SketchSettings.frameRate |
| 12 | `colorMode` | `bend` | color(hue:saturation:brightness:) |
| 10 | `dist` | `write` | — |
| 10 | `updatePixels` | `none` | — |
| 9 | `constrain` | `write` | — |
| 8 | `QUADS` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 7 | `mag` | `write` | — |
| 6 | `QUAD_STRIP` | `bend` ([#882](https://github.com/mokume-metal/mokume/issues/882)) | — |
| 6 | `createFont` | `none` | — |
| 6 | `getChild` | `none` | — |
| 6 | `loadShape` | `none` | — |
| 5 | `GROUP` | `none` | — |
| 5 | `addChild` | `bend` | Shape.group |
| 4 | `getChildCount` | `none` | — |
| 4 | `getVertexCount` | `bend` | — |
| 4 | `millis` | `none` | — |
| 4 | `setFill` | `none` | — |
| 3 | `fromAngle` | `write` | — |
| 3 | `getVertex` | `none` | — |
