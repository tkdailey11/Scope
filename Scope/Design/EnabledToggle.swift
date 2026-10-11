//
//  EnabledToggle.swift
//  Scope
//

import SwiftUI

/// Enable/disable switch for a table row. Table rows are immutable values, so the
/// toggle reports changes through `onChange` rather than binding into the model.
struct EnabledToggle: View {
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Toggle("Enabled", isOn: Binding(get: { isOn }, set: onChange))
            .labelsHidden()
    }
}
