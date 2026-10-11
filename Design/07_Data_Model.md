# 07 — Data Model

## Shared concepts

```swift
enum ConfigurationScope: Codable, Hashable {
    case global
    case profile(UUID)
    case machine(UUID)
}
```

Each managed item should have stable identity, timestamps, enabled state, and scope.

## EnvironmentVariable

```swift
struct EnvironmentVariable: Identifiable, Codable {
    let id: UUID
    var name: String
    var value: String?
    var secretReference: String?
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date
}
```

Invariant: exactly one of `value` or `secretReference` should represent the active value source.

## PathEntry

```swift
struct PathEntry: Identifiable, Codable {
    let id: UUID
    var rawPath: String
    var order: Int
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date
}
```

Store the user's authored form (`~/go/bin`) and compute expanded path separately for validation.

## Alias

```swift
struct ShellAlias: Identifiable, Codable {
    let id: UUID
    var name: String
    var command: String
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date
}
```

## ShellFunction

```swift
struct ShellFunction: Identifiable, Codable {
    let id: UUID
    var name: String
    var body: String
    var scope: ConfigurationScope
    var isEnabled: Bool
    var createdAt: Date
    var modifiedAt: Date
}
```

## Profile

```swift
struct Profile: Identifiable, Codable {
    let id: UUID
    var name: String
    var iconName: String?
    var isActive: Bool
    var createdAt: Date
    var modifiedAt: Date
}
```

MVP recommendation: allow one active named profile at a time, plus Global and Machine scopes.

## Machine

```swift
struct Machine: Identifiable, Codable {
    let id: UUID
    var displayName: String
    var stableDeviceIdentifier: String
    var lastSeenAt: Date
}
```

Do not rely only on the current computer name as identity because users can rename Macs.

## EffectiveConfiguration

This should be computed rather than persisted as source of truth.

```swift
struct EffectiveConfiguration {
    var environment: [ResolvedEnvironmentVariable]
    var path: [ResolvedPathEntry]
    var aliases: [ResolvedAlias]
    var functions: [ResolvedFunction]
    var issues: [ValidationIssue]
}
```

Composition order recommendation:

1. Global
2. Active Profile
3. Machine

For name-based entities such as variables and aliases, later scopes override earlier scopes. For PATH, later scopes contribute entries according to explicit list ordering rules.
