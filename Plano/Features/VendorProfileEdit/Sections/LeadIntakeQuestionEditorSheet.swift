import SwiftUI

struct LeadIntakeQuestionEditorSheet: View {
    @Binding var question: LeadIntakeQuestion
    let isNew: Bool
    let onDelete: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var draft: LeadIntakeQuestion

    init(question: Binding<LeadIntakeQuestion>, isNew: Bool, onDelete: @escaping () -> Void) {
        self._question = question
        self.isNew = isNew
        self.onDelete = onDelete
        self._draft = State(initialValue: question.wrappedValue)
    }

    private var canSave: Bool {
        guard !draft.trimmedPrompt.isEmpty else { return false }
        if draft.responseType == .singleChoice || draft.responseType == .multiChoice {
            return draft.trimmedOptions.count >= 2
        }
        return true
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    questionTextSection
                    answerTypeSection
                    if draft.responseType == .singleChoice || draft.responseType == .multiChoice {
                        optionsSection
                    }
                    settingsSection
                    if draft.isCustom {
                        deleteSection
                    }
                }
                .padding(AppTheme.screenPadding)
                .padding(.bottom, 32)
            }
            .scrollIndicators(.hidden)
            .background(AppBackdrop())
            .navigationTitle(isNew ? "New Question" : "Edit Question")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if isNew { onDelete() }
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        question = draft.normalized()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSave)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Sections

    private var questionTextSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Question")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                TextField("What do you want to ask?", text: $draft.prompt)
                    .textFieldStyle(.roundedBorder)

                TextField("Helper text (optional)", text: $draft.helperText)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)

                TextField("Placeholder (optional)", text: $draft.placeholder)
                    .textFieldStyle(.roundedBorder)
                    .font(.subheadline)
            }
        }
    }

    private var answerTypeSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                Text("Answer type")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                VStack(spacing: 0) {
                    ForEach(LeadIntakeFieldType.allCases) { type in
                        Button {
                            switchResponseType(to: type)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: type.symbolName)
                                    .font(.body)
                                    .foregroundStyle(
                                        draft.responseType == type
                                            ? AppTheme.Palette.accent
                                            : AppTheme.Palette.textSecondary
                                    )
                                    .frame(width: 24)

                                Text(type.title)
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Spacer()

                                if draft.responseType == type {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(AppTheme.Palette.accent)
                                }
                            }
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)

                        if type != LeadIntakeFieldType.allCases.last {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    private var optionsSection: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Options")
                        .font(.headline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Spacer()

                    if draft.trimmedOptions.count < 2 {
                        Text("At least 2 required")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                ForEach(draft.options.indices, id: \.self) { index in
                    HStack(spacing: 8) {
                        TextField("Option \(index + 1)", text: optionBinding(at: index))
                            .textFieldStyle(.roundedBorder)

                        Button {
                            draft.options.remove(at: index)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(AppTheme.Palette.subdued)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button {
                    draft.options.append("")
                } label: {
                    Label("Add option", systemImage: "plus.circle")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.accent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var settingsSection: some View {
        AppSurface {
            Toggle(isOn: $draft.isRequired) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Required")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    Text("Hosts must answer before submitting")
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }
            }
            .tint(AppTheme.Palette.accent)
        }
    }

    private var deleteSection: some View {
        Button(role: .destructive) {
            onDelete()
            dismiss()
        } label: {
            HStack {
                Spacer()
                Label("Delete question", systemImage: "trash")
                    .font(.subheadline.weight(.medium))
                Spacer()
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(.red)
    }

    // MARK: - Helpers

    private func optionBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { draft.options.indices.contains(index) ? draft.options[index] : "" },
            set: { if draft.options.indices.contains(index) { draft.options[index] = $0 } }
        )
    }

    private func switchResponseType(to newType: LeadIntakeFieldType) {
        let wasChoice = draft.responseType == .singleChoice || draft.responseType == .multiChoice
        let isChoice = newType == .singleChoice || newType == .multiChoice

        draft.responseType = newType

        if !wasChoice && isChoice && draft.options.isEmpty {
            draft.options = ["", ""]
        } else if wasChoice && !isChoice {
            draft.options = []
        }
    }
}
