import SwiftUI

/// Pinned bottom dock for the vendor profile.
///
/// Always a messaging composer (text field + send). Booking requests are
/// initiated from the inline action card in the booking section, not the dock,
/// so the message composer stays available even after a date is selected.
struct VendorProfileComposerDock: View {
    let vendor: VendorProfile
    let isSending: Bool
    let onSendMessage: (_ message: String) -> Void

    @State private var messageText = ""
    @FocusState private var isTextFieldFocused: Bool

    private var trimmedMessage: String {
        messageText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message \(vendor.businessName)…", text: $messageText, axis: .vertical)
                .lineLimit(1...5)
                .font(.body)
                .foregroundStyle(AppTheme.Palette.textPrimary)
                .focused($isTextFieldFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.Palette.chrome.opacity(0.6), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .frame(minHeight: 44)

            Button {
                let outgoing = trimmedMessage
                guard !outgoing.isEmpty, !isSending else { return }
                onSendMessage(outgoing)
                messageText = ""
                isTextFieldFocused = false
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(ComposerCircleButtonStyle())
            .disabled(trimmedMessage.isEmpty || isSending)
            .accessibilityLabel("Send message")
        }
        .padding(.horizontal, AppTheme.screenPadding)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppTheme.Palette.border)
                .frame(height: 1)
        }
    }
}

// MARK: - Circle send button

private struct ComposerCircleButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(AppTheme.Palette.accentForeground)
            .background(
                Circle()
                    .fill(AppTheme.Palette.accent.opacity(configuration.isPressed ? 0.88 : 1))
            )
            .opacity(isEnabled ? 1 : 0.35)
            .scaleEffect(configuration.isPressed ? 0.95 : 1)
            .animation(.snappy, value: configuration.isPressed)
            .hapticFeedback(.impact(weight: .medium), trigger: configuration.isPressed) { old, new in
                !old && new
            }
    }
}
