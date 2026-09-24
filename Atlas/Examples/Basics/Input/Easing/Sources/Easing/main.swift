// **生成物** — `python3 scripts/examples.py` が書く。手で編集しない。
//
// **`@main` を移植の側に付けない。** 付けると移植が生成物と混ざるうえ、
// 同じモジュールにトップレベルコードがあると衝突する。`Sketch.main()` は
// `@MainActor static func main()` で、ここ (トップレベルコードも main actor)
// からなら具体型に対して呼べる。

Easing.main()
