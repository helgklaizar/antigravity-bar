import Foundation
import Darwin
import IOKit

final class SystemStats: @unchecked Sendable {
    static let shared = SystemStats()

    private let lock = NSLock()
    private var previousCPU: (user: Int32, system: Int32, idle: Int32, nice: Int32) = (0, 0, 0, 0)

    private(set) var cpuHistory: [Int] = Array(repeating: 0, count: 20)
    private(set) var ramHistory: [Int] = Array(repeating: 0, count: 20)
    private(set) var gpuHistory: [Int] = Array(repeating: 0, count: 20)

    func getCPUUsage() -> Int {
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
                totalUser += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_USER)]
                totalSystem += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_SYSTEM)]
                totalIdle += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_IDLE)]
                totalNice += cpuInfo[Int(CPU_STATE_MAX) * i + Int(CPU_STATE_NICE)]
            }
            let vm_deallocate_size = vm_size_t(numCpuInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_deallocate_size)

            // [M-3] Compute diffs and update previousCPU atomically under lock
            var userDiff: Int32 = 0
            var systemDiff: Int32 = 0
            var idleDiff: Int32 = 0
            var niceDiff: Int32 = 0
            lock.withLock {
                userDiff = totalUser - previousCPU.user
                systemDiff = totalSystem - previousCPU.system
                idleDiff = totalIdle - previousCPU.idle
                niceDiff = totalNice - previousCPU.nice
                previousCPU = (totalUser, totalSystem, totalIdle, totalNice)
            }

            let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
            if totalDiff > 0 {
                let usage = Int(Double(userDiff + systemDiff + niceDiff) / Double(totalDiff) * 100.0)
                lock.withLock {
                    cpuHistory.append(usage)
                    if cpuHistory.count > 20 { cpuHistory.removeFirst() }
                }
                return usage
            }
        }
        lock.withLock {
            cpuHistory.append(0)
            if cpuHistory.count > 20 { cpuHistory.removeFirst() }
        }
        return 0
    }

    func getRAMUsage() -> Int {
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        var vmStat = vm_statistics64_data_t()
        let result = withUnsafeMutablePointer(to: &vmStat) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let physicalMemory = ProcessInfo.processInfo.physicalMemory
            let pageSize = UInt64(getpagesize())
            let usedMemory = UInt64(vmStat.active_count + vmStat.wire_count + vmStat.compressor_page_count) * pageSize
            let usage = Int(Double(usedMemory) / Double(physicalMemory) * 100.0)
            lock.withLock {
                ramHistory.append(usage)
                if ramHistory.count > 20 { ramHistory.removeFirst() }
            }
            return usage
        }
        lock.withLock {
            ramHistory.append(0)
            if ramHistory.count > 20 { ramHistory.removeFirst() }
        }
        return 0
    }

    func getGPUUsage() -> Int {
        let matching = IOServiceMatching("IOAccelerator")
        var iterator: io_iterator_t = 0
        var usage = 0
        if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
            var service = IOIteratorNext(iterator)
            while service != 0 {
                var unmanagedProps: Unmanaged<CFMutableDictionary>?
                if IORegistryEntryCreateCFProperties(service, &unmanagedProps, kCFAllocatorDefault, 0) == kIOReturnSuccess {
                    if let props = unmanagedProps?.takeRetainedValue() as? [String: Any] {
                        if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
                            if let util = perfStats["Device Utilization %"] as? Int {
                                usage = max(usage, util)
                            } else if let util = perfStats["GPU Activity"] as? Int {
                                usage = max(usage, util)
                            }
                        }
                    }
                }
                IOObjectRelease(service)
                service = IOIteratorNext(iterator)
            }
            IOObjectRelease(iterator)
        }
        lock.withLock {
            gpuHistory.append(usage)
            if gpuHistory.count > 20 { gpuHistory.removeFirst() }
        }
        return usage
    }
}
