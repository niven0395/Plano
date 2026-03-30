import SwiftUI

struct EditableChipSection: View {
    let title: String
    var subtitle: String? = nil
    let options: [String]
    @Binding var selected: [String]

    @State private var customText = ""
    @FocusState private var isCustomFieldFocused: Bool

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                FlowLayout(spacing: 8) {
                    ForEach(allOptions, id: \.self) { option in
                        Button {
                            toggle(option)
                        } label: {
                            FilterChip(title: option, isSelected: selected.contains(option))
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Add your own...", text: $customText)
                        .font(.subheadline)
                        .focused($isCustomFieldFocused)
                        .onSubmit { addCustom() }

                    if !customText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button {
                            addCustom()
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(AppTheme.Palette.accent)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var customItems: [String] {
        selected.filter { !options.contains($0) }
    }

    private var allOptions: [String] {
        options + customItems
    }

    private func toggle(_ option: String) {
        if selected.contains(option) {
            selected.removeAll { $0 == option }
        } else {
            selected.append(option)
        }
    }

    private func addCustom() {
        let trimmed = customText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !allOptions.contains(trimmed) else { return }
        selected.append(trimmed)
        customText = ""
        isCustomFieldFocused = false
    }
}
