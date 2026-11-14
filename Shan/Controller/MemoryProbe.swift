//
//  MemoryProbe.swift
//  ShanKeyboard
//
//  Created by NorHsangPha BoonHse on 12/11/2569 BE.
//

import Darwin
import os

enum MemoryProbe {
    private static let logger = Logger(subsystem: "com.noernova.ShanKeyboard.shan", category: "memory")

    /// Current phys_footprint in bytes, or nil if the kernel call fails.
    static func footprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }

    /// Bytes left before Jetsam's per-process limit.
    static func available() -> Int {
        #if os(iOS)
        return Int(os_proc_available_memory())
        #else
        return 0
        #endif
    }

    static func log(_ event: String) {
        let used = footprint().map { Double($0) / 1_048_576 } ?? -1
        let left = Double(available()) / 1_048_576
        logger.info("\(event, privacy: .public) footprint=\(used, format: .fixed(precision: 1), privacy: .public)MB available=\(left, format: .fixed(precision: 1), privacy: .public)MB")
    }
}
