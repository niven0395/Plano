import SwiftUI

struct ServicesEditView: View {
    let store: VendorProfileEditStore
    @Environment(\.dismiss) private var dismiss

    @State private var newServiceText = ""

    private static let maxServices = 6

    var body: some View {
        @Bindable var store = store

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                KeyServicesSection(
                    services: $store.draft.services,
                    newServiceText: $newServiceText
                )

                Button(store.loadingState.isLoading ? "Saving..." : "Save services") {
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
        .scrollDismissesKeyboard(.interactively)
        .background(AppBackdrop())
        .navigationTitle("Services")
        .navigationBarTitleDisplayMode(.inline)
        .saveFeedback(outcome: store.lastSaveOutcome, successMessage: "Services saved") {
            store.lastSaveOutcome = .idle
        }
    }
}

// MARK: - Key Services Section

struct KeyServicesSection: View {
    @Binding var services: [String]
    @Binding var newServiceText: String

    private static let maxServices = 6

    private var leftColumn: ArraySlice<String> {
        services.prefix(3)
    }

    private var rightColumn: ArraySlice<String> {
        services.count > 3 ? services[3...] : []
    }

    private var isFull: Bool {
        services.count >= Self.maxServices
    }

    var body: some View {
        AppSurface {
            VStack(alignment: .leading, spacing: 18) {
                headerSection
                if !services.isEmpty { columnsSection }
                if !isFull { addServiceRow }
            }
        }
    }

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Key services")
                    .font(.headline)
                    .foregroundStyle(AppTheme.Palette.textPrimary)

                Spacer()

                Text("\(services.count)/\(Self.maxServices)")
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.Palette.textSecondary)
            }

            Text("Add the services you offer so hosts can find you.")
                .font(.footnote.weight(.medium))
                .foregroundStyle(AppTheme.Palette.textSecondary)
        }
    }

    private var columnsSection: some View {
        HStack(alignment: .top, spacing: 16) {
            serviceColumn(items: leftColumn, startIndex: 0)

            if !rightColumn.isEmpty {
                serviceColumn(items: rightColumn, startIndex: 3)
            }
        }
    }

    private func serviceColumn(items: ArraySlice<String>, startIndex: Int) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { offset, service in
                let index = startIndex + offset

                HStack(spacing: 8) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 5))
                        .foregroundStyle(AppTheme.Palette.textSecondary)

                    Text(service)
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.Palette.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    Button {
                        withAnimation(.snappy) {
                            removeService(at: index)
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(AppTheme.Palette.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 8)

                if offset < items.count - 1 {
                    Divider()
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var addServiceRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.subheadline)
                .foregroundStyle(AppTheme.Palette.accent)

            TextField("e.g. Floral installations", text: $newServiceText)
                .textInputAutocapitalization(.words)
                .onSubmit { addService() }

            if !newServiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Add") { addService() }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.Palette.accent)
            }
        }
    }

    private func removeService(at index: Int) {
        guard services.indices.contains(index) else { return }
        services.remove(at: index)
    }

    private func addService() {
        let trimmed = newServiceText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isFull else { return }
        withAnimation(.snappy) {
            services.append(trimmed)
        }
        newServiceText = ""
    }
}
