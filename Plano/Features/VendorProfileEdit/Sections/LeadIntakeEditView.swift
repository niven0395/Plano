import SwiftUI

struct LeadIntakeEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Lead intake")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Pick the questions hosts answer before sending a booking request.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                AppSurface {
                    VStack(spacing: 0) {
                        ForEach(store.draft.leadIntakeQuestions.indices, id: \.self) { index in
                            LeadIntakeQuestionRow(
                                question: Binding(
                                    get: { store.draft.leadIntakeQuestions[index] },
                                    set: { store.draft.leadIntakeQuestions[index] = $0 }
                                )
                            )

                            if index < store.draft.leadIntakeQuestions.count - 1 {
                                Divider()
                                    .padding(.leading, 44)
                            }
                        }
                    }
                }

                Button("Reset to template") {
                    store.resetLeadIntakeQuestionsToTemplate()
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppTheme.Palette.accent)
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity)

                Button(store.loadingState.isLoading ? "Saving..." : "Save intake form") {
                    Task {
                        await store.save()
                        if store.lastSaveOutcome == .saved {
                            dismiss()
                        }
                    }
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(store.loadingState.isLoading)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Lead Intake")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Intake form saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            store.ensureLeadIntakeQuestions()
        }
    }
}

private struct LeadIntakeQuestionRow: View {
    @Binding var question: LeadIntakeQuestion

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

            VStack(alignment: .leading, spacing: 2) {
                Text(question.trimmedPrompt)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(question.isEnabled ? AppTheme.Palette.textPrimary : AppTheme.Palette.subdued)

                if !question.trimmedOptions.isEmpty {
                    Text(question.trimmedOptions.joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(AppTheme.Palette.subdued)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

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
        }
        .padding(.vertical, 12)
        .contentShape(.rect)
        .animation(.easeInOut(duration: 0.15), value: question.isEnabled)
        .animation(.easeInOut(duration: 0.15), value: question.isRequired)
    }
}
