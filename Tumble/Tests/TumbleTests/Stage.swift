import Foundation
import mokume

@testable import Tumble

/// 列を回して判定する。読んだ絵の指紋を `PROBES_FINGERPRINT` へ、絵を `PROBES_SHOTS` へ書く。
///
/// **指紋は `Examine` が取ったものをそのまま書く** (FNV-1a)。`scripts/stress.py` は同じ名前・同じ
/// フレームの指紋が実行をまたいで揃うかだけを見るので、他の物差しの SHA-256 と形が違ってよい
/// (ADR-0007)。
@MainActor
func examine(_ program: Program, name: String) throws -> Outcome {
    let shots = ProcessInfo.processInfo.environment["PROBES_SHOTS"].map {
        URL(fileURLWithPath: $0).appendingPathComponent("Tumble", isDirectory: true)
    }
    if let shots { try FileManager.default.createDirectory(at: shots, withIntermediateDirectories: true) }
    let outcome = try Examine.examine(program, shots: shots, key: name)
    for (index, hash) in outcome.hashes.enumerated() {
        try fingerprint(hash, name: name, frame: index + 1)
    }
    return outcome
}

/// 縮めて置いた列 (`Tumble/Findings/<鍵>.json`) を読む。
func finding(_ key: String) throws -> Program {
    let url = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("Findings/\(key).json")
    return try JSONDecoder().decode(Program.self, from: Data(contentsOf: url))
}

/// 指紋を、環境変数 `PROBES_FINGERPRINT` の置き場へ 1 行足す (`scripts/stress.py` が読む)。
/// 変数が無ければ何もしない。
func fingerprint(_ digest: String, name: String, frame: Int) throws {
    guard let directory = ProcessInfo.processInfo.environment["PROBES_FINGERPRINT"] else { return }
    let url = URL(fileURLWithPath: directory).appendingPathComponent("Tumble-\(getpid()).tsv")
    if !FileManager.default.fileExists(atPath: url.path) {
        try Data().write(to: url)
    }
    let handle = try FileHandle(forWritingTo: url)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data("\(name)\t\(frame)\t\(digest)\n".utf8))
}
