import AVFoundation
import CoreMedia
import CryptoKit
import Foundation
import ImageIO
import VideoToolbox
import mokume

@testable import Imprint

// MARK: - 書き出させる

/// 窓を出さずに `frames` 枚回してから、差込口を閉じて書き切らせる。
///
/// **時計はフレーム番号から導く** (`SketchRuntime` の既定) ので、n 枚目の時刻は
/// (n − 1) / fps で、何度回しても同じになる。`closePlugins()` は撮る係まで閉じ終えて
/// から返る (書き出したものが確かにファイルになるのは、ここを通った後である)。
@MainActor
func produce(_ sketch: Ticker, frames: Int) throws {
    let runtime = try SketchRuntime(sketch: sketch, gpu: gpu)
    for _ in 0..<frames { try runtime.advance() }
    runtime.closePlugins()
}

@MainActor let gpu = try! RenderDevice()

/// 検査ごとの使い捨ての置き場。
func scratch(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("imprint-\(name)-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

/// この機械の符号化器が ProRes 4444 を書けるか。mokume の `MovieFile.isAvailable` と同じ
/// 問い方をする (あちらは internal)。
nonisolated let proResAvailable: Bool = {
    var properties: CFDictionary?
    let status = VTCopySupportedPropertyDictionaryForEncoder(
        width: 640, height: 360, codecType: kCMVideoCodecType_AppleProRes4444,
        encoderSpecification: nil, encoderIDOut: nil, supportedPropertiesOut: &properties)
    return status == noErr
}()

// MARK: - 動画を読む

/// 読み戻した動画。
struct Movie {
    /// 各フレームの並び (RGBA、1 画素 4 バイト、行の間隔は幅 × 4)。
    var frames: [[UInt8]] = []
    var width = 0
    var height = 0
    /// 各フレームの時刻を 1/90000 秒の刻みで表したもの (整数で比べるため)。
    var ticks: [Int64] = []
    /// トラックの長さ (秒)。
    var duration: Double = 0
    var codec: FourCharCode = 0
    var primaries: String?
    var transfer: String?
    var matrix: String?

    /// 各フレームに焼いた番号。
    var numbers: [Int] { frames.map { Stamp.read($0, stride: width * 4) } }
}

/// `.mov` を開いて、全フレームと時刻・形式の宣言を読む。開けなければ投げる。
func readMovie(_ url: URL) async throws -> Movie {
    let asset = AVURLAsset(url: url)
    guard let track = try await asset.loadTracks(withMediaType: .video).first else {
        throw ReadFailure.noVideoTrack(url.lastPathComponent)
    }
    var movie = Movie()
    movie.duration = CMTimeGetSeconds(try await track.load(.timeRange).duration)
    if let format = try await track.load(.formatDescriptions).first {
        movie.codec = CMFormatDescriptionGetMediaSubType(format)
        func ext(_ key: CFString) -> String? {
            CMFormatDescriptionGetExtension(format, extensionKey: key) as? String
        }
        movie.primaries = ext(kCMFormatDescriptionExtension_ColorPrimaries)
        movie.transfer = ext(kCMFormatDescriptionExtension_TransferFunction)
        movie.matrix = ext(kCMFormatDescriptionExtension_YCbCrMatrix)
    }
    let reader = try AVAssetReader(asset: asset)
    let output = AVAssetReaderTrackOutput(
        track: track, outputSettings: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA])
    reader.add(output)
    reader.startReading()
    while let sample = output.copyNextSampleBuffer() {
        guard let buffer = CMSampleBufferGetImageBuffer(sample) else { continue }
        let time = CMSampleBufferGetPresentationTimeStamp(sample)
        movie.ticks.append(time.value * 90000 / Int64(time.timescale))
        let (bytes, width, height) = rgba(buffer)
        movie.frames.append(bytes)
        (movie.width, movie.height) = (width, height)
    }
    if reader.status == .failed { throw reader.error ?? ReadFailure.unreadable(url.lastPathComponent) }
    return movie
}

/// 符号化器が返す並び (BGRA) を RGBA へ直す。
private func rgba(_ buffer: CVPixelBuffer) -> ([UInt8], Int, Int) {
    CVPixelBufferLockBaseAddress(buffer, .readOnly)
    defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    let stride = CVPixelBufferGetBytesPerRow(buffer)
    let base = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    for y in 0..<height {
        for x in 0..<width {
            let from = y * stride + x * 4
            let to = (y * width + x) * 4
            bytes[to] = base[from + 2]
            bytes[to + 1] = base[from + 1]
            bytes[to + 2] = base[from]
            bytes[to + 3] = base[from + 3]
        }
    }
    return (bytes, width, height)
}

enum ReadFailure: Error {
    case noVideoTrack(String)
    case unreadable(String)
}

// MARK: - PNG を読む

/// 読み戻した PNG。
struct PNG {
    /// **刻まれた色空間のまま**の並び (RGBA、8 ビット)。色の変換を通さない。
    var bytes: [UInt8]
    var width: Int
    var height: Int
    /// 刻まれた色空間の名前 (例: `kCGColorSpaceDisplayP3`)。
    var colorSpace: String?

    var number: Int { Stamp.read(bytes, stride: width * 4) }

    subscript(x: Int, y: Int) -> (Int, Int, Int) {
        let i = (y * width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }
}

/// PNG を開き、刻まれた色空間の中で 8 ビットの RGBA に広げる (変換はしない)。
func readPNG(_ url: URL) throws -> PNG {
    guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else { throw ReadFailure.unreadable(url.lastPathComponent) }
    let space = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB)!
    let (width, height) = (image.width, image.height)
    var bytes = [UInt8](repeating: 0, count: width * height * 4)
    let drawn = bytes.withUnsafeMutableBytes { raw -> Bool in
        guard
            let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return true
    }
    guard drawn else { throw ReadFailure.unreadable(url.lastPathComponent) }
    return PNG(bytes: bytes, width: width, height: height, colorSpace: space.name as String?)
}

/// ファイルの SHA-256。
func digest(_ url: URL) throws -> String {
    SHA256.hash(data: try Data(contentsOf: url)).map { String(format: "%02x", $0) }.joined()
}

/// 置き場の中の名前 (隠しファイルを含む)。
func names(in directory: URL) throws -> [String] {
    try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
}

// MARK: - 容れ物の時刻の刻印

extension Data {
    /// `.mov` の `mvhd`・`tkhd`・`mdhd` にある作成・更新時刻を 0 にした写し。
    ///
    /// 刻印は書き出した時刻 (秒) なので、2 本が違う秒に書かれると、ここだけが違う
    /// (mokume#1628)。刻印を除いたバイト (絵と時刻の表) の一致を比べるのに使う。
    func withoutContainerTimes() -> Data {
        var copy = self
        func walk(_ start: Int, _ end: Int) {
            var offset = start
            while offset + 8 <= end {
                var size = Int(copy[offset..<offset + 4].reduce(0) { $0 << 8 | UInt64($1) })
                let kind = String(decoding: copy[offset + 4..<offset + 8], as: UTF8.self)
                if size == 1 { size = Int(copy[offset + 8..<offset + 16].reduce(0) { $0 << 8 | UInt64($1) }) }
                if size == 0 { size = end - offset }
                guard size >= 8, offset + size <= end else { return }
                switch kind {
                case "moov", "trak", "mdia": walk(offset + 8, offset + size)
                case "mvhd", "tkhd", "mdhd":
                    // 版 0 は 32 ビットの時刻が 2 つ、版 1 は 64 ビットが 2 つ。版と旗の 4 バイトの後に並ぶ
                    let width = copy[offset + 8] == 1 ? 16 : 8
                    copy.replaceSubrange(offset + 12..<offset + 12 + width, with: Data(count: width))
                default: break
                }
                offset += size
            }
        }
        walk(0, copy.count)
        return copy
    }
}
