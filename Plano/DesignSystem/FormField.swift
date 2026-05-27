import SwiftUI

/// Unified styling for text inputs across the app. Applies `inputFill` background,
/// a hairline border that becomes accent-colored on focus, rounded-corner shape,
/// and consistent padding.
///
/// Use on `TextField`, `TextEditor`, or any input-like view:
/// ```swift
/// TextField("Business name", text: $name)
///     .planoFormField()
///
/// TextField("Email", text: $email)
///     .planoFormField(systemImage: "envelope.fill")
/// ```
///
/// Intentionally a single modifier rather than a wrapper view so callers can
/// keep using native `TextField` / `TextEditor` without layout surprises.
struct PlanoFormFieldModifier: ViewModifier {
    var systemImage: String? = nil

    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        HStack(spacing: 10) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isFocused ? AppTheme.Palette.accent : AppTheme.Palette.subdued)
                    .frame(width: 20)
                    .accessibilityHidden(true)
                    .animation(.snappy, value: isFocused)
            }

            content
                .focused($isFocused)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(AppTheme.Palette.inputFill, in: .rect(cornerRadius: AppTheme.smallCornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AppTheme.smallCornerRadius)
                .stroke(
                    isFocused ? AppTheme.Palette.accent : AppTheme.Palette.border,
                    lineWidth: isFocused ? 1.5 : 1
                )
        }
        .animation(.snappy, value: isFocused)
    }
}

extension View {
    /// Adds Plano's unified form-field styling: inputFill background, hairline
    /// border (accent on focus), rounded corners, and consistent padding.
    /// Optionally prefixes a leading SF Symbol glyph.
    func planoFormField(systemImage: String? = nil) -> some View {
        modifier(PlanoFormFieldModifier(systemImage: systemImage))
    }
}
