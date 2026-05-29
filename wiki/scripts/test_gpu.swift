import Foundation
import IOKit

let matching = IOServiceMatching("IOAccelerator")
var iterator: io_iterator_t = 0
if IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator) == kIOReturnSuccess {
    var service = IOIteratorNext(iterator)
    while service != 0 {
        var unmanagedProps: Unmanaged<CFMutableDictionary>? = nil
        if IORegistryEntryCreateCFProperties(service, &unmanagedProps, kCFAllocatorDefault, 0) == kIOReturnSuccess {
            if let props = unmanagedProps?.takeRetainedValue() as? [String: Any] {
                if let perfStats = props["PerformanceStatistics"] as? [String: Any] {
                    if let util = perfStats["Device Utilization %"] as? Int {
                        print("GPU Utilization: \(util)%")
                    } else if let util = perfStats["GPU Activity"] as? Int {
                        print("GPU Activity: \(util)%")
                    }
                }
            }
        }
        IOObjectRelease(service)
        service = IOIteratorNext(iterator)
    }
    IOObjectRelease(iterator)
}
