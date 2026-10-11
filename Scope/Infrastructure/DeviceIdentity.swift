//
//  DeviceIdentity.swift
//  Scope
//
//  Identifies this Mac independently of its (renamable) computer name.
//

import Foundation
import IOKit
import SystemConfiguration

nonisolated struct DeviceIdentity: Sendable, Equatable {
    var identifier: String
    var displayName: String

    /// The hardware UUID, which survives renames and reinstalls.
    static var current: DeviceIdentity {
        DeviceIdentity(
            identifier: hardwareUUID() ?? UserDefaultsFallback.identifier,
            displayName: Host.current().localizedName ?? "This Mac"
        )
    }

    private static func hardwareUUID() -> String? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }
        return IORegistryEntryCreateCFProperty(service, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0)?
            .takeRetainedValue() as? String
    }

    /// Only used if the hardware UUID is unavailable.
    private enum UserDefaultsFallback {
        static var identifier: String {
            let key = "ScopeFallbackDeviceIdentifier"
            if let existing = UserDefaults.standard.string(forKey: key) { return existing }
            let new = UUID().uuidString
            UserDefaults.standard.set(new, forKey: key)
            return new
        }
    }
}
