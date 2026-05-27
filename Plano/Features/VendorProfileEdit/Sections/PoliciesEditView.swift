import SwiftUI

struct PoliciesEditView: View {
    let store: VendorProfileEditStore
    @State private var policies: [VendorPolicy] = []
    @State private var cancellationDeadlineDays: Int?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                AppSurface {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Cancellation policy")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppTheme.Palette.subdued)

                        Picker("Free cancellation window", selection: $cancellationDeadlineDays) {
                            Text("No cancellation policy").tag(nil as Int?)
                            Text("7 days before event").tag(7 as Int?)
                            Text("14 days before event").tag(14 as Int?)
                            Text("30 days before event").tag(30 as Int?)
                            Text("60 days before event").tag(60 as Int?)
                        }
                    }
                }

                ForEach($policies) { $policy in
                    AppSurface {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Policy")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.Palette.subdued)
                                    .textCase(.uppercase)
                                    .tracking(0.4)

                                Spacer()

                                Button("Remove", role: .destructive) {
                                    policies.removeAll { $0.id == policy.id }
                                }
                                .font(.footnote.weight(.semibold))
                            }

                            TextField("Title", text: $policy.title)
                                .font(.subheadline.weight(.semibold))
                                .planoFormField()

                            TextField("Policy details", text: $policy.body, axis: .vertical)
                                .lineLimit(4, reservesSpace: true)
                                .font(.subheadline)
                                .planoFormField()
                        }
                    }
                }

                Button {
                    policies.append(VendorPolicy(title: "", body: ""))
                } label: {
                    Label("Add policy", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.Palette.textPrimary)
            }
            .padding(AppTheme.screenPadding)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .background(AppBackdrop())
        .navigationTitle("Policies")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Policies saved") {
            store.lastSaveOutcome = .idle
        }
        .onAppear {
            policies = store.draft.policies
            cancellationDeadlineDays = store.draft.cancellationDeadlineDays
        }
        .onDisappear {
            let cleaned = policies.filter {
                !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            store.draft.cancellationDeadlineDays = cancellationDeadlineDays
            store.draft.policies = cleaned
            Task {
                await store.save()
            }
        }
    }
}
