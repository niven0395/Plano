import SwiftUI

/// Shared pinned save bar for every section under the vendor profile edit flow.
/// Uses `AppFloatingActionBar` as the chrome; owns the store-driven save/dismiss
/// logic so sections can swap the old inline button for one `.safeAreaInset`.
///
/// Usage:
/// ```swift
/// .safeAreaInset(edge: .bottom) {
///     VendorProfileEditSaveBar(
///         store: store,
///         buttonLabel: "Save basic info",
///         successMessage: "Basic info saved",
///         isSaveEnabled: !store.draft.businessName.isEmpty
///     )
/// }
/// ```
///
/// Callers should also add `.padding(.bottom, 96)` to the ScrollView content
/// to keep the bar from covering the bottom of the scroll.
struct VendorProfileEditSaveBar: View {
    let store: VendorProfileEditStore
    let buttonLabel: String
    var isSaveEnabled: Bool = true
    /// Runs on the main actor just before `store.save()` is invoked. Use this to
    /// flush derived state (e.g. normalizing preparedServiceItems) right before
    /// the network call. Defaults to a no-op.
    var beforeSave: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    private var isLoading: Bool { store.loadingState.isLoading }

    var body: some View {
        AppFloatingActionBar {
            statusLabel
        } trailing: {
            Button {
                beforeSave()
                Task {
                    await store.save()
                    if store.lastSaveOutcome == .saved {
                        dismiss()
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .controlSize(.small)
                            .tint(AppTheme.Palette.accentForeground)
                    }
                    Text(isLoading ? "Saving…" : buttonLabel)
                }
            }
            .buttonStyle(AppFloatingActionBarButtonStyle())
            .disabled(isLoading || !isSaveEnabled)
            .accessibilityLabel(buttonLabel)
        }
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch store.lastSaveOutcome {
        case .saved:
            Label("Saved", systemImage: "checkmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(.sage))
                .symbolRenderingMode(.hierarchical)
                .transition(.opacity)
        case .failed:
            Label("Couldn't save", systemImage: "exclamationmark.circle.fill")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppTheme.toneColor(.coral))
                .symbolRenderingMode(.hierarchical)
                .transition(.opacity)
        case .idle:
            EmptyView()
        }
    }
}
