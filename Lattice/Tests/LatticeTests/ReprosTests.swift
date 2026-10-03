import Testing

/// 起票した再現 (`Repros/`) を、そのまま走らせる (docs/filing.md)。
///
/// **本文に貼ったコードが、いまも破れを出すこと**を押さえる。mokume が直ると、本来の検査と
/// 同じく「既知の問題が起きなかった」で赤くなって知らせる。再現が投げたとき (描けない) は
/// 既知の問題に数えず、そのまま落とす。
///
/// **直った再現は包みを外して残す。** 戻れば赤くなって知らせる。起票の番号は `"mokume#N` の字面で
/// 名指しする (`filing.py check` が、`Repros/` の再現ごとに検査が名指ししているかを見る)。
@MainActor
@Suite struct ReprosTests {
    @Test("再現: 細かさ 0.5 の quad の太さ 1 の輪郭 = 細かさ 1 と同じ光の量 (上辺 y = 10・11)")
    func thinOutline() throws {
        let broken = try ThinOutline.reproduce()
        #expect(broken == nil, "mokume#1637 で直った: \(broken ?? "")")
    }

    @Test("再現: 細かさ 0.5 の拡大を通しても、透明の下地で α ≤ 1・色 ≤ α")
    func upscaleKeepsPremultiplied() throws {
        let broken = try UpscaleKeepsPremultiplied.reproduce()
        #expect(broken == nil, "mokume#1638 で直った: \(broken ?? "")")
    }

    @Test("再現: 利用者の効果の in.position で刻んだ市松が、細かさ 1 と 0.5 で同じ")
    func effectPositionIsOutputPixels() throws {
        let broken = try EffectPositionIsOutputPixels.reproduce()
        #expect(broken == nil, "mokume#1639 で直った: \(broken ?? "")")
    }

    @Test("再現: fps 50 で毎秒 50 個の粒は、1 枚目に 1 個・50 枚で 50 個")
    func emitPerSecond() throws {
        let broken = try EmitPerSecond.reproduce()
        #expect(broken == nil, "mokume#1640 で直った: \(broken ?? "")")
    }

    @Test("再現: clip(10.9, 0, 10, 40) で切り抜いた塗り = 同じ矩形の rect")
    func clipStaysInside() throws {
        let broken = try ClipStaysInside.reproduce()
        #expect(broken == nil, "mokume#1641 で直った: \(broken ?? "")")
    }

    @Test("再現: frameRate 0 のランタイムは組み立てで断る")
    func badFrameRate() throws {
        let broken = try BadFrameRate.reproduce()
        #expect(broken == nil, "mokume#1642 で直った: \(broken ?? "")")
    }
}
