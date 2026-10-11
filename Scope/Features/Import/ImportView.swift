//
//  ImportView.swift
//  Scope
//
//  Review-then-import for existing zsh configuration. Source files are only
//  read; imported lines stay where they are (Design/04, "Import existing config").
//

import SwiftUI

struct ImportView: View {
    @Environment(AppState.self) private var appState
    @State private var rows: [ImportRow] = []
    @State private var detected: [DetectedLine] = []
    @State private var scannedFiles: [String] = []
    @State private var unreadableFiles: [String] = []
    @State private var hasScanned = false
    @State private var isScanning = false
    @State private var scope = ConfigurationScope.global
    @State private var importedCount: Int?

    private var importableItems: [ImportedItem] {
        rows.filter { $0.isSelected && !appState.isAlreadyInScope($0.candidate.item, scope: scope) }
            .map(\.candidate.item)
    }

    var body: some View {
        Group {
            if !hasScanned {
                ProgressView("Reading your zsh files…")
            } else if rows.isEmpty && detected.isEmpty {
                ContentUnavailableView(
                    "Nothing to Import",
                    systemImage: "square.and.arrow.down",
                    description: Text(emptyDescription)
                )
            } else {
                list
            }
        }
        .toolbar {
            ToolbarItem {
                Button("Rescan", systemImage: "arrow.clockwise") { Task { await scan() } }
                    .disabled(isScanning)
            }
            ToolbarItem {
                Button("Import \(importableItems.count) Items", systemImage: "square.and.arrow.down", action: importSelection)
                    .disabled(importableItems.isEmpty)
            }
        }
        .task { await scan() }
        .onChange(of: scope) { selectNewRows() }
    }

    private var emptyDescription: String {
        scannedFiles.isEmpty
            ? String(localized: "No .zshenv, .zprofile, .zshrc or .zlogin was found in your home folder.")
            : String(localized: "Scope found no aliases, exports, PATH changes or functions it can import from \(scannedFiles.formatted()).")
    }

    private var list: some View {
        CardPage {
            CardSection {
                ScopePicker(scope: $scope)
                Text("Scope copies what you select. Your original files are not changed, so nothing is removed from your shell until you decide to clean it up.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                if let importedCount {
                    Label("Imported \(importedCount) items. Review them, then Apply from Generated Config.", systemImage: "checkmark.circle.fill")
                        .font(.callout)
                }
                if !unreadableFiles.isEmpty {
                    IssueText(message: String(localized: "Couldn't read \(unreadableFiles.formatted()) as text."))
                }
            }
            ForEach(groupTitles, id: \.self) { title in
                CardSection(LocalizedStringKey(title)) {
                    ForEach($rows) { $row in
                        if row.candidate.item.kindTitle == title {
                            ImportRowView(
                                row: $row,
                                isAlreadyInScope: appState.isAlreadyInScope(row.candidate.item, scope: scope)
                            )
                        }
                    }
                }
            }
            if !detected.isEmpty {
                CardSection {
                    DisclosureGroup("Not imported (\(detected.count))") {
                        ForEach(detected) { line in
                            VStack(alignment: .leading, spacing: 2) {
                                Text(line.text)
                                    .font(.callout.monospaced())
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Text("\(line.file):\(line.line) · \(line.reason)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private var groupTitles: [String] {
        var titles: [String] = []
        for row in rows where !titles.contains(row.candidate.item.kindTitle) {
            titles.append(row.candidate.item.kindTitle)
        }
        return titles
    }

    // MARK: - Actions

    private func scan() async {
        isScanning = true
        defer { isScanning = false }
        let result = await appState.scanForImport()
        rows = result.candidates.map { ImportRow(candidate: $0, isSelected: false) }
        detected = result.detected
        scannedFiles = result.scannedFiles
        unreadableFiles = result.unreadableFiles
        importedCount = nil
        hasScanned = true
        selectNewRows()
    }

    /// Preselects everything that isn't already in the chosen scope.
    private func selectNewRows() {
        for index in rows.indices {
            rows[index].isSelected = !appState.isAlreadyInScope(rows[index].candidate.item, scope: scope)
        }
    }

    private func importSelection() {
        let items = importableItems
        importedCount = appState.importItems(items, into: scope)
        let imported = Set(rows.filter { $0.isSelected }.map(\.id))
        for index in rows.indices where imported.contains(rows[index].id) { rows[index].isSelected = false }
    }
}

#Preview {
    ImportView()
        .environment(AppState(store: InMemoryConfigurationStore()))
        .frame(width: 720, height: 480)
}
