//
//  Card.swift
//  Scope
//
//  Bordered card container used by the settings-style screens (iCloud, Machines,
//  Profiles, Import, Diagnostics). Replaces grouped Form/List sections so the card
//  fill and border are ours instead of the system's.
//

import SwiftUI

/// A scrolling page of `CardSection`s.
struct CardPage<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                content
            }
            .frame(maxWidth: 760)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.contentBackground)
    }
}

/// A titled group of rows drawn as one rounded, bordered card. Rows are separated by dividers.
struct CardSection<Content: View>: View {
    private let title: Text?
    private let footer: Text?
    private let content: Content

    init(title: Text? = nil, footer: Text? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    init(_ title: LocalizedStringKey, footer: LocalizedStringKey? = nil, @ViewBuilder content: () -> Content) {
        self.init(title: Text(title), footer: footer.map { Text($0) }, content: content)
    }

    init(footer: LocalizedStringKey, @ViewBuilder content: () -> Content) {
        self.init(title: nil, footer: Text(footer), content: content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                title
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
            VStack(alignment: .leading, spacing: 0) {
                Group(subviews: content) { subviews in
                    ForEach(subviews) { subview in
                        subview
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        if subview.id != subviews.last?.id {
                            Divider().padding(.leading, 16)
                        }
                    }
                }
            }
            .background(Theme.cardBackground, in: .rect(cornerRadius: Theme.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            }
            if let footer {
                footer
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            }
        }
    }
}

/// A labelled single- or multi-line text field row for use inside a `CardSection`.
struct CardField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    var prompt: String = ""
    var monospaced = false
    var multiline = false
    var issue: String?
    var trailing: AnyView?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(label)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .leading)
                TextField(label, text: $text, prompt: Text(prompt), axis: multiline ? .vertical : .horizontal)
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(monospaced ? .body.monospaced() : .body)
                    .lineLimit(multiline ? 1...6 : 1...1)
                    .autocorrectionDisabled()
                trailing
            }
            IssueText(message: issue)
        }
    }
}

/// A label with a trailing switch, for use inside a `CardSection`.
struct CardToggle: View {
    let label: LocalizedStringKey
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Toggle(label, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}
