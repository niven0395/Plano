import SwiftUI

struct LeadIntakeEditView: View {
    let store: VendorProfileEditStore
    @State private var editingQuestionIndex: Int?
    @State private var isAddingNewQuestion = false

    private var hasUnaddedSuggestions: Bool {
        let suggested = LeadIntakeTemplateLibrary.suggestedQuestions(for: store.draft.category)
        let existingIDs = Set(store.draft.leadIntakeQuestions.map(\.id))
        return suggested.contains { !existingIDs.contains($0.id) }
    }

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lead intake")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Choose what info hosts provide when sending a booking request.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Request fields")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Guest count")
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textPrimary)

                                Text("Ask hosts for expected guest count")
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }

                            Spacer(minLength: 16)

                            Toggle("", isOn: $store.draft.collectsGuestCount)
                                .labelsHidden()
                                .tint(AppTheme.Palette.accent)
                        }
                    }
                }

                if !store.draft.leadIntakeQuestions.isEmpty {
                    AppSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Custom questions")
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            VStack(spacing: 0) {
                                ForEach(store.draft.leadIntakeQuestions.indices, id: \.self) { index in
                                    LeadIntakeQuestionRow(
                                        question: Binding(
                                            get: { store.draft.leadIntakeQuestions[index] },
                                            set: { store.draft.leadIntakeQuestions[index] = $0 }
                                        ),
                                        canMoveUp: index > 0,
                                        canMoveDown: index < store.draft.leadIntakeQuestions.count - 1,
                                        onMoveUp: {
                                            withAnimation(.snappy) {
                                                store.moveQuestion(from: index, to: index - 1)
                                            }
                                        },
                                        onMoveDown: {
                                            withAnimation(.snappy) {
                                                store.moveQuestion(from: index, to: index + 1)
                                            }
                                        },
                                        onEdit: {
                                            isAddingNewQuestion = false
                                            editingQuestionIndex = index
                                        }
                                    )

                                    if index < store.draft.leadIntakeQuestions.count - 1 {
                                        Divider()
                                            .padding(.leading, 44)
                                    }
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        store.addCustomQuestion()
                        isAddingNewQuestion = true
                        editingQuestionIndex = store.draft.leadIntakeQuestions.count - 1
                    } label: {
                        Label("Add custom question", systemImage: "plus.circle")
                    }
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.accent)
                    .buttonStyle(.plain)

                    if hasUnaddedSuggestions {
                        Button {
                            store.addSuggestedQuestions()
                        } label: {
                            Label("Add suggested", systemImage: "sparkles")
                        }
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppTheme.Palette.textSecondary)
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity)

            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Lead Intake")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            VendorProfileEditSaveBar(store: store, buttonLabel: "Save intake form")
        }
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Intake form saved") {
            store.lastSaveOutcome = .idle
        }
        .sheet(isPresented: Binding(
            get: { editingQuestionIndex != nil },
            set: { if !$0 { editingQuestionIndex = nil; isAddingNewQuestion = false } }
        )) {
            if let index = editingQuestionIndex,
               store.draft.leadIntakeQuestions.indices.contains(index) {
                LeadIntakeQuestionEditorSheet(
                    question: Binding(
                        get: { store.draft.leadIntakeQuestions[index] },
                        set: { store.draft.leadIntakeQuestions[index] = $0 }
                    ),
                    isNew: isAddingNewQuestion,
                    onDelete: {
                        let id = store.draft.leadIntakeQuestions[index].id
                        editingQuestionIndex = nil
                        isAddingNewQuestion = false
                        store.deleteQuestion(id: id)
                    }
                )
            }
        }
    }
}

private struct LeadIntakeQuestionRow: View {
    @Binding var question: LeadIntakeQuestion
    let canMoveUp: Bool
    let canMoveDown: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button {
                question.isEnabled.toggle()
                if !question.isEnabled {
                    question.isRequired = false
                }
            } label: {
                Image(systemName: question.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(question.isEnabled ? AppTheme.Palette.accent : AppTheme.Palette.subdued)
            }
            .buttonStyle(.plain)

            Button {
                onEdit()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if question.trimmedPrompt.isEmpty {
                        Text("Untitled question")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.subdued)
                            .italic()
                    } else {
                        Text(question.trimmedPrompt)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(question.isEnabled ? AppTheme.Palette.textPrimary : AppTheme.Palette.subdued)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: question.responseType.symbolName)
                            .font(.caption2)

                        if !question.trimmedOptions.isEmpty {
                            Text(question.trimmedOptions.joined(separator: " · "))
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(AppTheme.Palette.subdued)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 8)

            HStack(spacing: 4) {
                if question.isEnabled {
                    Button {
                        question.isRequired.toggle()
                    } label: {
                        Text("Required")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .foregroundStyle(question.isRequired ? .white : AppTheme.Palette.textSecondary)
                            .background(
                                question.isRequired ? AppTheme.Palette.accent : AppTheme.Palette.elevatedSurface,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }

                VStack(spacing: 2) {
                    Button {
                        onMoveUp()
                    } label: {
                        Image(systemName: "chevron.up")
                            .font(.caption2.weight(.semibold))
                            .frame(width: 24, height: 20)
                    }
                    .disabled(!canMoveUp)

                    Button {
                        onMoveDown()
                    } label: {
                        Image(systemName: "chevron.down")
                            .font(.caption2.weight(.semibold))
                            .frame(width: 24, height: 20)
                    }
                    .disabled(!canMoveDown)
                }
                .foregroundStyle(AppTheme.Palette.subdued)
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .animation(.easeInOut(duration: 0.15), value: question.isEnabled)
        .animation(.easeInOut(duration: 0.15), value: question.isRequired)
    }
}
