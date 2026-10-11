//
//  SyncTransport.swift
//  Scope
//
//  The wire to iCloud, behind a protocol so reconciliation is testable without CloudKit.
//

import Foundation

nonisolated enum SyncAccountStatus: Equatable, Sendable {
    case available
    case noAccount
    case restricted
    case temporarilyUnavailable
    /// This build isn't signed with the iCloud capability.
    case notConfigured

    var message: String? {
        switch self {
        case .available: nil
        case .noAccount: String(localized: "Sign in to iCloud in System Settings to sync.")
        case .restricted: String(localized: "iCloud is restricted on this Mac.")
        case .temporarilyUnavailable: String(localized: "iCloud is temporarily unavailable. Try again shortly.")
        case .notConfigured: String(localized: "This build of Scope isn't set up for iCloud. Enable the iCloud (CloudKit) capability for the app in Xcode.")
        }
    }
}

nonisolated protocol SyncTransport: Sendable {
    func accountStatus() async -> SyncAccountStatus
    /// Changes since `token` (nil for everything), and the token to resume from.
    func fetchChanges(since token: Data?) async throws -> (changes: [RemoteChange], token: Data?)
    func push(_ changes: [RemoteChange]) async throws
}
