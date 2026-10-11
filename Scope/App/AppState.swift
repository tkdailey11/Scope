//
//  AppState.swift
//  Scope
//
//  Observable source of truth for the UI. Mutations apply immediately and are
//  persisted in order, so a slow save can never overwrite a newer one.
//

import Foundation
import OSLog
import SwiftUI

@Observable
final class AppState {
    private(set) var configuration = StoredConfiguration()
    /// This Mac's entry in `configuration.machines`; set once the configuration has loaded.
    private(set) var currentMachineID: UUID?
    /// Set when something the user should know about fails (load or save).
    var errorMessage: String?
    /// Shown on the Preview screen after Apply finishes.
    private(set) var applyResult: ApplyResultMessage?
    private(set) var isApplying = false

    private let store: any ConfigurationStore
    private let now: () -> Date
    private let deviceIdentity: DeviceIdentity
    let pathInspector: PathInspector
    private let syntaxValidator: ShellSyntaxValidator
    private let applyService: ApplyService
    private let diagnosticsService: DiagnosticsService
    private var saveTask: Task<Void, Never>?
    /// True after a failed load, so a bad file is never overwritten by an empty config.
    private var isReadOnly = false

    private static let logger = Logger(subsystem: "com.scope.Scope", category: "AppState")

    init(
        store: any ConfigurationStore,
        pathInspector: PathInspector = PathInspector(),
        syntaxValidator: ShellSyntaxValidator = ShellSyntaxValidator(fileSystem: LocalFileSystem(), processRunner: SystemProcessRunner()),
        applyService: ApplyService = ApplyService(fileSystem: LocalFileSystem(), paths: ScopePaths(), processRunner: SystemProcessRunner()),
        diagnosticsService: DiagnosticsService = DiagnosticsService(fileSystem: LocalFileSystem(), paths: ScopePaths(), processRunner: SystemProcessRunner()),
        deviceIdentity: DeviceIdentity = .current,
        now: @escaping () -> Date = { .now }
    ) {
        self.store = store
        self.applyService = applyService
        self.diagnosticsService = diagnosticsService
        self.deviceIdentity = deviceIdentity
        self.pathInspector = pathInspector
        self.syntaxValidator = syntaxValidator
        self.now = now
    }

    // MARK: - Loading and saving

    func load() async {
        do {
            configuration = try await store.load()
            registerCurrentMachine()
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

    // MARK: - Profiles and machines

    var activeProfile: Profile? {
        configuration.profiles.first(where: \.isActive)
    }

    var currentMachine: Machine? {
        configuration.machines.first { $0.id == currentMachineID }
    }

    /// Profiles sorted by name.
    var profilesByName: [Profile] {
        configuration.profiles.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Global, every profile, then this Mac. What an item can be scoped to.
    var availableScopes: [ConfigurationScope] {
        [.global] + profilesByName.map { .profile($0.id) } + (currentMachineID.map { [.machine($0)] } ?? [])
    }

    /// The result of composing Global -> active Profile -> this Mac.
    var effectiveConfiguration: EffectiveConfiguration {
        ConfigurationComposer.compose(configuration.snapshot, activeProfileID: activeProfile?.id, machineID: currentMachineID)
    }

    func name(of scope: ConfigurationScope) -> String {
        switch scope {
        case .global:
            String(localized: "Global")
        case .profile(let id):
            configuration.profiles.first { $0.id == id }?.name ?? String(localized: "Deleted Profile")
        case .machine(let id):
            id == currentMachineID
                ? String(localized: "This Mac")
                : configuration.machines.first { $0.id == id }?.displayName ?? String(localized: "Unknown Mac")
        }
    }

    /// Adds this Mac on first launch and keeps its display name current after renames.
    private func registerCurrentMachine() {
        if let index = configuration.machines.firstIndex(where: { $0.stableDeviceIdentifier == deviceIdentity.identifier }) {
            currentMachineID = configuration.machines[index].id
            guard configuration.machines[index].displayName != deviceIdentity.displayName else { return }
            configuration.machines[index].displayName = deviceIdentity.displayName
            configuration.machines[index].lastSeenAt = now()
        } else {
            let machine = Machine(displayName: deviceIdentity.displayName, stableDeviceIdentifier: deviceIdentity.identifier, lastSeenAt: now())
            configuration.machines.append(machine)
            currentMachineID = machine.id
        }
        persist()
    }

    func profileNames(excluding id: UUID? = nil) -> Set<String> {
        Set(configuration.profiles.filter { $0.id != id }.map { $0.name.lowercased() })
    }

    /// Creates a profile, or renames/re-icons the one with `id`. Returns the profile's id,
    /// or nil (changing nothing) if the name is empty or already used.
    @discardableResult
    func saveProfile(name: String, iconName: String? = nil, replacing id: UUID? = nil) -> UUID? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !profileNames(excluding: id).contains(trimmed.lowercased()) else { return nil }

        let savedID: UUID
        if let id, let index = configuration.profiles.firstIndex(where: { $0.id == id }) {
            configuration.profiles[index].name = trimmed
            configuration.profiles[index].iconName = iconName
            configuration.profiles[index].modifiedAt = now()
            savedID = id
        } else {
            let profile = Profile(name: trimmed, iconName: iconName, createdAt: now(), modifiedAt: now())
            configuration.profiles.append(profile)
            savedID = profile.id
        }
        persist()
        return savedID
    }

    /// Makes `id` the single active profile, or deactivates all when nil.
    func setActiveProfile(_ id: UUID?) {
        var changed = false
        for index in configuration.profiles.indices {
            let shouldBeActive = configuration.profiles[index].id == id
            guard configuration.profiles[index].isActive != shouldBeActive else { continue }
            configuration.profiles[index].isActive = shouldBeActive
            configuration.profiles[index].modifiedAt = now()
            changed = true
        }
        if changed { persist() }
    }

    /// Removes the profile and every item scoped to it.
    func deleteProfile(_ id: UUID) {
        guard configuration.profiles.contains(where: { $0.id == id }) else { return }
        configuration.profiles.removeAll { $0.id == id }
        removeItems(in: .profile(id))
        persist()
    }

    /// Removes a machine's overrides. Only other Macs can be forgotten; this Mac re-registers on launch.
    func forgetMachine(_ id: UUID) {
        guard id != currentMachineID, configuration.machines.contains(where: { $0.id == id }) else { return }
        configuration.machines.removeAll { $0.id == id }
        removeItems(in: .machine(id))
        persist()
    }

    /// Number of items scoped to `scope`, by kind.
    func itemCounts(in scope: ConfigurationScope) -> (environment: Int, path: Int, aliases: Int, functions: Int) {
        (
            configuration.environment.filter { $0.scope == scope }.count,
            configuration.path.filter { $0.scope == scope }.count,
            configuration.aliases.filter { $0.scope == scope }.count,
            configuration.functions.filter { $0.scope == scope }.count
        )
    }

    private func removeItems(in scope: ConfigurationScope) {
        configuration.environment.removeAll { $0.scope == scope }
        configuration.path.removeAll { $0.scope == scope }
        configuration.aliases.removeAll { $0.scope == scope }
        configuration.functions.removeAll { $0.scope == scope }
    }

    // MARK: - Preview and Apply

    func preview() async -> ConfigurationPreview {
        await applyService.preview(effectiveConfiguration)
    }

    /// Writes the generated file and ensures the startup hook. Returns true on success.
    @discardableResult
    func apply() async -> Bool {
        guard !isApplying else { return false }
        isApplying = true
        defer { isApplying = false }
        do {
            let outcome = try await applyService.apply(effectiveConfiguration)
            applyResult = .success(outcome)
            return true
        } catch let error as ApplyError {
            applyResult = .failure(error)
        } catch {
            applyResult = .failure(.hookFailed(error.localizedDescription))
        }
        return false
    }

    func runDiagnostics() async -> [DiagnosticCheck] {
        await diagnosticsService.run(effectiveConfiguration)
    }

    func dismissApplyResult() {
        applyResult = nil
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

    // MARK: - PATH

    /// Entries in `scope`, highest priority (first in $PATH) first.
    func pathEntries(in scope: ConfigurationScope = .global) -> [PathEntry] {
        configuration.path
            .filter { $0.scope == scope }
            .sorted { ($0.order, $0.createdAt) < ($1.order, $1.createdAt) }
    }

    /// Authored paths already used in `scope`, for duplicate detection. Pass the edited entry's id to exclude it.
    func pathStrings(in scope: ConfigurationScope, excluding id: UUID? = nil) -> Set<String> {
        Set(configuration.path.filter { $0.scope == scope && $0.id != id }.map(\.rawPath))
    }

    /// Creates an entry (lowest priority in its scope), or updates the one with `id`.
    /// Returns false (changing nothing) if the draft is invalid.
    @discardableResult
    func savePathEntry(
        _ draft: PathEntryDraft,
        replacing id: UUID? = nil,
        scope: ConfigurationScope = .global
    ) -> Bool {
        let existingIndex = id.flatMap { id in configuration.path.firstIndex { $0.id == id } }
        let effectiveScope = existingIndex.map { configuration.path[$0].scope } ?? scope
        guard draft.isValid(existingPaths: pathStrings(in: effectiveScope, excluding: id)) else { return false }

        if let existingIndex {
            configuration.path[existingIndex].rawPath = draft.trimmedPath
            configuration.path[existingIndex].isEnabled = draft.isEnabled
            configuration.path[existingIndex].modifiedAt = now()
        } else {
            let nextOrder = (configuration.path.filter { $0.scope == effectiveScope }.map(\.order).max() ?? -1) + 1
            configuration.path.append(PathEntry(
                rawPath: draft.trimmedPath,
                order: nextOrder,
                scope: effectiveScope,
                isEnabled: draft.isEnabled,
                createdAt: now(),
                modifiedAt: now()
            ))
        }
        persist()
        return true
    }

    func setPathEntry(_ id: UUID, enabled: Bool) {
        guard let index = configuration.path.firstIndex(where: { $0.id == id }),
              configuration.path[index].isEnabled != enabled else { return }
        configuration.path[index].isEnabled = enabled
        configuration.path[index].modifiedAt = now()
        persist()
    }

    /// Drag-reorder within one scope. Offsets refer to `pathEntries(in:)`; orders are renumbered 0…n.
    func movePathEntries(in scope: ConfigurationScope = .global, fromOffsets source: IndexSet, toOffset destination: Int) {
        var ordered = pathEntries(in: scope)
        ordered.move(fromOffsets: source, toOffset: destination)
        var changed = false
        for (order, entry) in ordered.enumerated() {
            guard let index = configuration.path.firstIndex(where: { $0.id == entry.id }),
                  configuration.path[index].order != order else { continue }
            configuration.path[index].order = order
            configuration.path[index].modifiedAt = now()
            changed = true
        }
        if changed { persist() }
    }

    func deletePathEntries(ids: Set<UUID>) {
        let before = configuration.path.count
        configuration.path.removeAll { ids.contains($0.id) }
        if configuration.path.count != before { persist() }
    }

    // MARK: - Aliases

    func aliases(matching search: String) -> [ShellAlias] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return configuration.aliases
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.command.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Names already used in `scope`, for duplicate detection. Pass the edited alias's id to exclude it.
    func aliasNames(in scope: ConfigurationScope, excluding id: UUID? = nil) -> Set<String> {
        Set(configuration.aliases.filter { $0.scope == scope && $0.id != id }.map(\.name))
    }

    /// Creates an alias, or updates the one with `id`. Returns false (changing nothing) if the draft is invalid.
    @discardableResult
    func saveAlias(
        _ draft: AliasDraft,
        replacing id: UUID? = nil,
        scope: ConfigurationScope = .global
    ) -> Bool {
        let existingIndex = id.flatMap { id in configuration.aliases.firstIndex { $0.id == id } }
        let effectiveScope = existingIndex.map { configuration.aliases[$0].scope } ?? scope
        guard draft.isValid(existingNames: aliasNames(in: effectiveScope, excluding: id)) else { return false }

        if let existingIndex {
            configuration.aliases[existingIndex].name = draft.trimmedName
            configuration.aliases[existingIndex].command = draft.command
            configuration.aliases[existingIndex].isEnabled = draft.isEnabled
            configuration.aliases[existingIndex].modifiedAt = now()
        } else {
            configuration.aliases.append(ShellAlias(
                name: draft.trimmedName,
                command: draft.command,
                scope: effectiveScope,
                isEnabled: draft.isEnabled,
                createdAt: now(),
                modifiedAt: now()
            ))
        }
        persist()
        return true
    }

    func setAlias(_ id: UUID, enabled: Bool) {
        guard let index = configuration.aliases.firstIndex(where: { $0.id == id }),
              configuration.aliases[index].isEnabled != enabled else { return }
        configuration.aliases[index].isEnabled = enabled
        configuration.aliases[index].modifiedAt = now()
        persist()
    }

    func deleteAliases(ids: Set<UUID>) {
        let before = configuration.aliases.count
        configuration.aliases.removeAll { ids.contains($0.id) }
        if configuration.aliases.count != before { persist() }
    }

    // MARK: - Functions

    func functions(matching search: String) -> [ShellFunction] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return configuration.functions
            .filter { query.isEmpty || $0.name.localizedStandardContains(query) || $0.body.localizedStandardContains(query) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Names already used in `scope`, for duplicate detection. Pass the edited function's id to exclude it.
    func functionNames(in scope: ConfigurationScope, excluding id: UUID? = nil) -> Set<String> {
        Set(configuration.functions.filter { $0.scope == scope && $0.id != id }.map(\.name))
    }

    /// Enabled alias names in any scope. zsh refuses to define a function whose name is an alias.
    func enabledAliasNames() -> Set<String> {
        Set(configuration.aliases.filter(\.isEnabled).map(\.name))
    }

    /// Creates a function, or updates the one with `id`. Returns the saved function's id,
    /// or nil (changing nothing) if the draft is invalid.
    @discardableResult
    func saveFunction(
        _ draft: FunctionDraft,
        replacing id: UUID? = nil,
        scope: ConfigurationScope = .global
    ) -> UUID? {
        let existingIndex = id.flatMap { id in configuration.functions.firstIndex { $0.id == id } }
        let effectiveScope = existingIndex.map { configuration.functions[$0].scope } ?? scope
        guard draft.isValid(existingNames: functionNames(in: effectiveScope, excluding: id)) else { return nil }

        let savedID: UUID
        if let existingIndex {
            configuration.functions[existingIndex].name = draft.trimmedName
            configuration.functions[existingIndex].body = draft.body
            configuration.functions[existingIndex].isEnabled = draft.isEnabled
            configuration.functions[existingIndex].modifiedAt = now()
            savedID = configuration.functions[existingIndex].id
        } else {
            let function = ShellFunction(
                name: draft.trimmedName,
                body: draft.body,
                scope: effectiveScope,
                isEnabled: draft.isEnabled,
                createdAt: now(),
                modifiedAt: now()
            )
            configuration.functions.append(function)
            savedID = function.id
        }
        persist()
        return savedID
    }

    func setFunction(_ id: UUID, enabled: Bool) {
        guard let index = configuration.functions.firstIndex(where: { $0.id == id }),
              configuration.functions[index].isEnabled != enabled else { return }
        configuration.functions[index].isEnabled = enabled
        configuration.functions[index].modifiedAt = now()
        persist()
    }

    func deleteFunctions(ids: Set<UUID>) {
        let before = configuration.functions.count
        configuration.functions.removeAll { ids.contains($0.id) }
        if configuration.functions.count != before { persist() }
    }

    /// Parse-only check (`zsh -n`) of the draft as it would be generated. Nil when the draft
    /// can't be generated yet or zsh couldn't be run. Nothing in the body is executed or logged.
    func checkSyntax(of draft: FunctionDraft) async -> SyntaxCheckResult? {
        guard let text = draft.generatedText else { return nil }
        do {
            return try await syntaxValidator.validate(text)
        } catch {
            Self.logger.error("Syntax check could not run: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

enum ApplyResultMessage: Equatable {
    case success(ApplyOutcome)
    case failure(ApplyError)
}
