//
//  SidebarHeader.swift
//  Scope
//
//  App icon and name at the top of the sidebar, like Relay.
//

import SwiftUI

struct SidebarHeader: View {
    var body: some View {
        HStack(spacing: 12) {
            Image("SidebarIcon")
                .resizable()
                .scaledToFit()
                .frame(width: 48, height: 48)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                }
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("Scope")
                    .font(.title2.bold())
                Text("Your shell configuration, in one place.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    SidebarHeader()
        .frame(width: 230)
}
