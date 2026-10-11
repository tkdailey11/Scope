//
//  SyncCoordinator.swift
//  Scope
//
//  Runs sync cycles: fetch, reconcile, apply, push. Local editing never waits on it,
//  and it never touches the shell files; Apply still rebuilds them locally.
//

import Foundation
import OSLog

@MainActor
@Observable
final class SyncCoordinator {
    private(set) var state = SyncState()
    private(set) var accountStatus: SyncAccountStatus?
    private(set) var isSyncing = false
    private(set) var lastError: String?

    private let appState: AppState
    private let transport: any SyncTransport
    private let stateStore: any SyncStateStore
    private let now: () -> Date
    private var debounceTask: Task<Void, Never>?
    private var needsAnotherPass = false

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "SyncCoordinator")

    init(
        appState: AppState,
        transport: any SyncTransport,
        stateStore: any SyncStateStore,
        now: @escaping () -> Date = { .now }
    ) {
        self.appState = appState
        self.transport = transport
        self.stateStore = stateStore
        self.now = now
    }

    var isEnabled: Bool { state.isEnabled }
    var conflicts: [PendingConflict] { state.conflicts }

    func load() async {
        state = await stateStore.load()
        accountStatus = await transport.accountStatus()
        if state.isEnabled { await syncNow() }
    }

    func setEnabled(_ enabled: Bool) async {
        guard enabled != state.isEnabled else { return }
        if enabled {
            let status = await transport.accountStatus()
            accountStatus = status
            guard status == .available else {
                lastError = status.message
                return
            }
            state.isEnabled = true
            await persistState()
            await syncNow()
        } else {
            debounceTask?.cancel()
            // Start from scratch if sync is turned back on; iCloud data is left in place.
            state = SyncState()
            lastError = nil
            await persistState()
        }
    }

    /// Call after local edits. Syncs shortly after the user stops changing things.
    func localChangesDidOccur() {
        guard state.isEnabled else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await syncNow()
        }
    }

    func syncNow() async {
        guard state.isEnabled else { return }
        guard !isSyncing else {
            needsAnotherPass = true
            return
        }
        isSyncing = true
        defer { isSyncing = false }
        repeat {
            needsAnotherPass = false
            do {
                try await runCycle()
                lastError = nil
            } catch {
                Self.logger.error("Sync failed: \(error.localizedDescription, privacy: .public)")
                lastError = String(localized: "Sync failed: \(error.localizedDescription)")
                return
            }
        } while needsAnotherPass
    }

    private func runCycle() async throws {
        let status = await transport.accountStatus()
        accountStatus = status
        guard status == .available else {
            lastError = status.message
            return
        }

        let fetched = try await transport.fetchChanges(since: state.changeToken)

        // No suspension between reading local items and applying, so the merge sees a consistent snapshot.
        let outcome = SyncReconciler.reconcile(local: appState.syncItems(), incoming: fetched.changes, state: &state)
        appState.applySync(outcome)
        state.changeToken = fetched.token
        await persistState()

        let outgoing = SyncReconciler.outgoing(
            local: appState.syncItems(), state: state, device: appState.deviceIdentifier, now: now()
        )
        if !outgoing.isEmpty {
            try await transport.push(outgoing)
            SyncReconciler.markPushed(outgoing, state: &state)
        }
        state.lastSyncedAt = now()
        await persistState()
    }

    /// Settles a conflict by keeping this Mac's version or the one from iCloud.
    func resolve(_ id: UUID, keepLocal: Bool) async {
        let outcome = SyncReconciler.resolve(id, keepLocal: keepLocal, state: &state)
        appState.applySync(outcome)
        await persistState()
        await syncNow()
    }

    private func persistState() async {
        do {
            try await stateStore.save(state)
        } catch {
            Self.logger.error("Couldn't save sync state: \(error.localizedDescription, privacy: .public)")
            lastError = String(localized: "Scope couldn't save its sync state: \(error.localizedDescription)")
        }
    }
}
