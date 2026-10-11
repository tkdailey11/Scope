//
//  DiagnosticsView.swift
//  Scope
//

import SwiftUI

struct DiagnosticsView: View {
    @Environment(AppState.self) private var appState
    @State private var checks: [DiagnosticCheck]?
    @State private var runCount = 0

    private struct RunKey: Equatable {
        var configuration: StoredConfiguration
        var count: Int
    }

    var body: some View {
        Group {
            if let checks {
                List {
                    summary(of: checks)
                    ForEach(DiagnosticCheck.Section.allCases, id: \.self) { section in
                        let rows = checks.filter { $0.section == section }
                        if !rows.isEmpty {
                            Section(String(localized: section.title)) {
                                ForEach(rows) { DiagnosticRow(check: $0) }
                            }
                        }
                    }
                }
            } else {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Run Again", systemImage: "arrow.clockwise") { runCount += 1 }
            }
        }
        .task(id: RunKey(configuration: appState.configuration, count: runCount)) {
            checks = await appState.runDiagnostics()
        }
    }

    private func summary(of checks: [DiagnosticCheck]) -> some View {
        let errors = checks.filter { $0.severity == .error }.count
        let warnings = checks.filter { $0.severity == .warning }.count
        return Group {
            if errors > 0 {
                Label("\(errors) problems found", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
            } else if warnings > 0 {
                Label("\(warnings) warnings", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
            } else {
                Label("Everything looks good", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
            }
        }
        .font(.headline)
    }
}

private struct DiagnosticRow: View {
    let check: DiagnosticCheck

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
                .accessibilityLabel(severityName)
            VStack(alignment: .leading, spacing: 3) {
                Text(check.title)
                if let detail = check.detail {
                    Text(detail)
                        .font(.callout.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if let suggestion = check.suggestion {
                    Text(suggestion)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var symbol: String {
        switch check.severity {
        case .ok: "checkmark.circle.fill"
        case .info: "info.circle"
        case .warning: "exclamationmark.triangle.fill"
        case .error: "xmark.octagon.fill"
        }
    }

    private var color: Color {
        switch check.severity {
        case .ok: .green
        case .info: .secondary
        case .warning: .orange
        case .error: .red
        }
    }

    private var severityName: String {
        switch check.severity {
        case .ok: String(localized: "OK")
        case .info: String(localized: "Note")
        case .warning: String(localized: "Warning")
        case .error: String(localized: "Error")
        }
    }
}

#Preview {
    DiagnosticsView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 720, height: 520)
}
