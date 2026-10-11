//
//  AppState.swift
//  Scope
//
//  Observable source of truth for the UI. Mutations apply immediately and are
//  persisted in order, so a slow save can never overwrite a newer one.
//

import Foundation
import OSLog

@Observable
final class AppState {
    private(set) var configuration = StoredConfiguration()
    /// Set when something the user should know about fails (load or save).
    var errorMessage: String?

    private let store: any ConfigurationStore
    private let now: () -> Date
    private var saveTask: Task<Void, Never>?
    /// True after a failed load, so a bad file is never overwritten by an empty config.
    private var isReadOnly = false

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "AppState")

    init(store: any ConfigurationStore, now: @escaping () -> Date = { .now }) {
        self.store = store
        self.now = now
    }

    // MARK: - Loading and saving

    func load() async {
        do {
            configuration = try await store.load()
        } catch ConfigurationStoreError.unreadable(let preservedAt) {
            isReadOnly = true
            errorMessage = String(localized: "Scope couldn't read its saved configuration. A copy was kept at \(preservedAt.path(percentEncoded: false)). Changes won't be saved until this is resolved.")
        } catch ConfigurationStoreError.newerSchema {
            isReadOnly = true
            errorMessage = String(localized: "This configuration was saved by a newer version of Scope. Update Scope to edit it. Changes won't be saved.")
        } catch {
            isReadOnly = true
            errorMessage = String(localized: "Scope couldn't load its saved configuration: \(error.localizedDescription)")
        }
    }

    /// Waits for in-flight saves. Used by tests and by quit handling.
    func waitForPendingSaves() async {
        await saveTask?.value
    }

    private func persist() {
        guard !isReadOnly else { return }
        let snapshot = configuration
        let previous = saveTask
        saveTask = Task {
            await previous?.value
            do {
                try await store.save(snapshot)
            } catch {
                Self.logger.error("Save failed: \(error.localizedDescription, privacy: .public)")
                errorMessage = String(localized: "Scope couldn't save your changes: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Environment variables

    func environmentVariables(matching search: String) -> [EnvironmentVariable] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return configuration.environment
            .filter { variable in
                query.isEmpty
                    || variable.name.localizedStandardContains(query)
                    // Secret-backed values are never searched.
                    || (variable.secretReference == nil && variable.value?.localizedStandardContains(query) == true)
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Names already used in `scope`, for duplicate detection. Pass the edited item's id to exclude it.
    func environmentNames(in scope: ConfigurationScope, excluding id: UUID? = nil) -> Set<String> {
        Set(configuration.environment.filter { $0.scope == scope && $0.id != id }.map(\.name))
    }

    /// Creates a variable, or updates the one with `id`. Returns false (changing nothing) if the draft is invalid.
    @discardableResult
    func saveEnvironmentVariable(
        _ draft: EnvironmentVariableDraft,
        replacing id: UUID? = nil,
        scope: ConfigurationScope = .global
    ) -> Bool {
        let existingIndex = id.flatMap { id in configuration.environment.firstIndex { $0.id == id } }
        let effectiveScope = existingIndex.map { configuration.environment[$0].scope } ?? scope
        guard draft.isValid(existingNames: environmentNames(in: effectiveScope, excluding: id)) else { return false }

        if let existingIndex {
            var variable = configuration.environment[existingIndex]
            variable.name = draft.trimmedName
            // Secret-backed variables keep their reference; their value is not editable here.
            if variable.secretReference == nil { variable.value = draft.value }
            variable.valueMode = draft.valueMode
            variable.isEnabled = draft.isEnabled
            variable.modifiedAt = now()
            configuration.environment[existingIndex] = variable
        } else {
            configuration.environment.append(EnvironmentVariable(
                name: draft.trimmedName,
                value: draft.value,
                valueMode: draft.valueMode,
                scope: scope,
                isEnabled: draft.isEnabled,
                createdAt: now(),
                modifiedAt: now()
            ))
        }
        persist()
        return true
    }

    func setEnvironmentVariable(_ id: UUID, enabled: Bool) {
        guard let index = configuration.environment.firstIndex(where: { $0.id == id }),
              configuration.environment[index].isEnabled != enabled else { return }
        configuration.environment[index].isEnabled = enabled
        configuration.environment[index].modifiedAt = now()
        persist()
    }

    func deleteEnvironmentVariables(ids: Set<UUID>) {
        let before = configuration.environment.count
        configuration.environment.removeAll { ids.contains($0.id) }
        if configuration.environment.count != before { persist() }
    }
}
