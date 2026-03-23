import SwiftUI

struct LeadIntakeEditView: View {
    let store: VendorProfileEditStore

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface(style: .highlighted) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Lead intake")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Hosts answer these questions before a booking request becomes a lead. Keep only the questions that help you quote or respond faster.")
                            .font(.subheadline)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }

                AppSurface {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Using the \(store.draft.category.singularTitle.lowercased()) template")
                            .font(.headline)
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("You can turn questions on or off and decide which ones are required before a host can submit.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)

                        Button("Reset to template") {
                            store.resetLeadIntakeQuestionsToTemplate()
                        }
                        .buttonStyle(SecondaryActionButtonStyle())
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(store.draft.leadIntakeQuestions.indices, id: \.self) { index in
                        LeadIntakeQuestionEditorCard(
                            question: Binding(
                                get: { store.draft.leadIntakeQuestions[index] },
                                set: { store.draft.leadIntakeQuestions[index] = $0 }
                            )
                        )
                    }
                }

                Button(store.loadingState.isLoading ? "Saving..." : "Save intake form") {
                    Task {
                        await store.save()
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

private struct LeadIntakeQuestionEditorCard: View {
    @Binding var question: LeadIntakeQuestion

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.trimmedPrompt)
                                .font(.headline)
                                .foregroundStyle(AppTheme.Palette.textPrimary)

                            if !question.helperText.isEmpty {
                                Text(question.helperText)
                                    .font(.footnote.weight(.medium))
                                    .foregroundStyle(AppTheme.Palette.textSecondary)
                            }
                        }

                        Spacer(minLength: 12)

                        Text(question.responseType.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.Palette.elevatedSurface, in: Capsule())
                    }

                    if !question.trimmedOptions.isEmpty {
                        Text(question.trimmedOptions.joined(separator: " · "))
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.subdued)
                    }

                    if !question.placeholder.isEmpty {
                        Text("Host hint: \(question.placeholder)")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.subdued)
                    }
                }

                Divider()

                Toggle(isOn: $question.isEnabled) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Show this question")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Disabled questions stay hidden from hosts.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .tint(AppTheme.Palette.accent)

                Toggle(isOn: Binding(
                    get: { question.isEnabled && question.isRequired },
                    set: { question.isRequired = question.isEnabled ? $0 : false }
                )) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Require an answer")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.textPrimary)

                        Text("Hosts must answer required questions before sending a request.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                }
                .disabled(!question.isEnabled)
                .tint(AppTheme.Palette.accent)
            }
        }
    }
}
