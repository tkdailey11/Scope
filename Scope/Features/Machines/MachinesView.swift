//
//  MachinesView.swift
//  Scope
//
//  Machine scope holds overrides that apply to a single Mac. Other Macs appear here
//  once sync exists; items scoped to them never affect this Mac.
//

import SwiftUI

struct MachinesView: View {
    @Environment(AppState.self) private var appState
    @State private var machinePendingRemoval: Machine?

    private var otherMachines: [Machine] {
        appState.configuration.machines
            .filter { $0.id != appState.currentMachineID }
            .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }

    var body: some View {
        List {
            if let machine = appState.currentMachine {
                Section {
                    MachineRow(machine: machine, counts: appState.itemCounts(in: .machine(machine.id)), isCurrent: true)
                } header: {
                    Text("This Mac")
                } footer: {
                    Text("Choose “This Mac” under Applies to when adding an item to override Global and Profile values here only.")
                }
            }
            if !otherMachines.isEmpty {
                Section("Other Macs") {
                    ForEach(otherMachines) { machine in
                        MachineRow(machine: machine, counts: appState.itemCounts(in: .machine(machine.id)), isCurrent: false)
                            .contextMenu {
                                Button("Forget…", role: .destructive) { machinePendingRemoval = machine }
                            }
                    }
                }
            }
        }
        .confirmationDialog(
            "Forget “\(machinePendingRemoval?.displayName ?? "")”?",
            isPresented: Binding(get: { machinePendingRemoval != nil }, set: { if !$0 { machinePendingRemoval = nil } }),
            titleVisibility: .visible,
            presenting: machinePendingRemoval
        ) { machine in
            Button("Forget Mac and Its Items", role: .destructive) { appState.forgetMachine(machine.id) }
        } message: { _ in
            Text("This deletes the configuration scoped to that Mac.")
        }
    }
}

private struct MachineRow: View {
    let machine: Machine
    let counts: (environment: Int, path: Int, aliases: Int, functions: Int)
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "laptopcomputer")
                .frame(width: 24)
                .foregroundStyle(isCurrent ? Theme.accent : .secondary)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(machine.displayName)
                Text(String(localized: "\(counts.environment) variables · \(counts.path) PATH entries · \(counts.aliases) aliases · \(counts.functions) functions"))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !isCurrent {
                Text(machine.lastSeenAt, format: .relative(presentation: .named))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let state = AppState(
        store: InMemoryConfigurationStore(),
        deviceIdentity: DeviceIdentity(identifier: "preview", displayName: "Tyler’s MacBook Pro")
    )
    return MachinesView()
        .environment(state)
        .task { await state.load() }
        .frame(width: 720, height: 420)
}
