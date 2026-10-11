//
//  InMemorySyncTransport.swift
//  Scope
//
//  A fake iCloud for tests and previews. Share one instance between "Macs".
//

import Foundation

actor InMemorySyncTransport: SyncTransport {
    private(set) var log: [RemoteChange] = []
    var status: SyncAccountStatus = .available
    var failNextPush = false

    func setStatus(_ status: SyncAccountStatus) { self.status = status }
    func setFailNextPush(_ value: Bool) { failNextPush = value }

    /// Latest version of every record, as another device would see after a full fetch.
    var records: [UUID: RemoteChange] {
        Dictionary(log.map { ($0.id, $0) }, uniquingKeysWith: { $1 })
    }

    func accountStatus() async -> SyncAccountStatus { status }

    func fetchChanges(since token: Data?) async throws -> (changes: [RemoteChange], token: Data?) {
        let start = token.flatMap { String(data: $0, encoding: .utf8) }.flatMap(Int.init) ?? 0
        return (Array(log[start...]), Data(String(log.count).utf8))
    }

    func push(_ changes: [RemoteChange]) async throws {
        if failNextPush {
            failNextPush = false
            throw URLError(.networkConnectionLost)
        }
        log.append(contentsOf: changes)
    }
}
