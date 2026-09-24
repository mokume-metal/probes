import Darwin
import Metal
import mokume

/// 資源の目盛り。窓もテストも同じものを読む。
///
/// **GPU の確保量は、mokume に渡したのと同じ `MTLDevice` から読む。** `currentAllocatedSize`
/// は装置ごとの値なので、別の装置を作って読んでも mokume の確保は見えない。テストは
/// `RenderDevice(device: Meter.device)` で組み、窓の舞台も同じ装置で組む。
enum Meter {
    static let device: any MTLDevice = MTLCreateSystemDefaultDevice()!

    /// プロセスの `phys_footprint` (バイト)。活動モニタの「メモリ」と同じ値で、
    /// jetsam が殺す判断に使うのもこれである。
    static func footprint() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    /// `device` の上で確保されている GPU の資源 (バイト)。
    static func gpu() -> Int { device.currentAllocatedSize }

    /// 目盛りを組んだ `RenderDevice`。
    static func renderDevice() throws -> RenderDevice { try RenderDevice(device: device) }
}
