import Foundation
import Darwin

func getRAMLoad() -> Double {
    var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
    var vmStat = vm_statistics64_data_t()
    let result = withUnsafeMutablePointer(to: &vmStat) {
        $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
            host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
        }
    }
    
    if result == KERN_SUCCESS {
        let physicalMemory = ProcessInfo.processInfo.physicalMemory
        // Active + Wired + Compressed
        let usedMemory = UInt64(vmStat.active_count + vmStat.wire_count + vmStat.compressor_page_count) * UInt64(vm_page_size)
        return Double(usedMemory) / Double(physicalMemory) * 100.0
    }
    return 0.0
}
print("RAM: \(getRAMLoad())")
