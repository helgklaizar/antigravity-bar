import Foundation
import Darwin

func getCPULoad() -> Double {
    var cpuInfo: processor_info_array_t!
    var numCpuInfo: mach_msg_type_number_t = 0
    var numCPUs: natural_t = 0
    let err = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCpuInfo)
    if err == KERN_SUCCESS {
        var totalUser: Int32 = 0
        var totalSystem: Int32 = 0
        var totalIdle: Int32 = 0
        var totalNice: Int32 = 0
        for i in 0..<Int(numCPUs) {
            let user = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)]
            let system = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)]
            let idle = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)]
            let nice = cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)]
            totalUser += user
            totalSystem += system
            totalIdle += idle
            totalNice += nice
        }
        let vm_deallocate_size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_deallocate_size)
        
        let total = totalUser + totalSystem + totalIdle + totalNice
        if total > 0 {
            return Double(totalUser + totalSystem + totalNice) / Double(total) * 100.0
        }
    }
    return 0.0
}
print("CPU: \(getCPULoad())")
