import SwiftUI

struct LeadIntakeFormView: View {
    let questions: [LeadIntakeQuestion]
    @Binding var answers: [LeadIntakeAnswer]

    var body: some View {
        ForEach(questions) { question in
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 4) {
                    Text(question.trimmedPrompt)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textPrimary)

                    if question.isRequired {
                        Text("*")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(AppTheme.toneColor(.coral))
                    }
                }

                if !question.helperText.isEmpty {
                    Text(question.helperText)
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                }

                inputField(for: question)
            }
        }
    }

    @ViewBuilder
    private func inputField(for question: LeadIntakeQuestion) -> some View {
        switch question.responseType {
        case .shortText:
            TextField(
                question.placeholder.isEmpty ? "Your answer" : question.placeholder,
                text: textBinding(for: question)
            )
            .textFieldStyle(.roundedBorder)

        case .longText:
            TextField(
                question.placeholder.isEmpty ? "Your answer" : question.placeholder,
                text: textBinding(for: question),
                axis: .vertical
            )
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)

        case .number:
            TextField(
                question.placeholder.isEmpty ? "0" : question.placeholder,
                text: textBinding(for: question)
            )
            .keyboardType(.numberPad)
            .textFieldStyle(.roundedBorder)

        case .singleChoice:
            SingleChoiceField(
                options: question.trimmedOptions,
                selection: singleChoiceBinding(for: question)
            )

        case .multiChoice:
            MultiChoiceField(
                options: question.trimmedOptions,
                selections: multiChoiceBinding(for: question)
            )
        }
    }

    // MARK: - Bindings

    private func textBinding(for question: LeadIntakeQuestion) -> Binding<String> {
        Binding(
            get: {
                answers.first(where: { $0.questionID == question.id })?.values.first ?? ""
            },
            set: { newValue in
                upsertAnswer(for: question, values: newValue.isEmpty ? [] : [newValue])
            }
        )
    }

    private func singleChoiceBinding(for question: LeadIntakeQuestion) -> Binding<String?> {
        Binding(
            get: {
                answers.first(where: { $0.questionID == question.id })?.values.first
            },
            set: { newValue in
                upsertAnswer(for: question, values: newValue.map { [$0] } ?? [])
            }
        )
    }

    private func multiChoiceBinding(for question: LeadIntakeQuestion) -> Binding<Set<String>> {
        Binding(
            get: {
                Set(answers.first(where: { $0.questionID == question.id })?.values ?? [])
            },
            set: { newValue in
                upsertAnswer(for: question, values: Array(newValue))
            }
        )
    }

    private func upsertAnswer(for question: LeadIntakeQuestion, values: [String]) {
        if let index = answers.firstIndex(where: { $0.questionID == question.id }) {
            answers[index] = LeadIntakeAnswer(question: question, values: values)
        } else {
            answers.append(LeadIntakeAnswer(question: question, values: values))
        }
    }
}

// MARK: - Choice fields

private struct SingleChoiceField: View {
    let options: [String]
    @Binding var selection: String?

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    selection = selection == option ? nil : option
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(selection == option ? .white : AppTheme.Palette.textPrimary)
                        .background(
                            selection == option ? AppTheme.Palette.accent : AppTheme.Palette.elevatedSurface,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct MultiChoiceField: View {
    let options: [String]
    @Binding var selections: Set<String>

    var body: some View {
        FlowLayout(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    if selections.contains(option) {
                        selections.remove(option)
                    } else {
                        selections.insert(option)
                    }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .foregroundStyle(selections.contains(option) ? .white : AppTheme.Palette.textPrimary)
                        .background(
                            selections.contains(option) ? AppTheme.Palette.accent : AppTheme.Palette.elevatedSurface,
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }
}
