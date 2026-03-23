import SwiftUI

// MARK: - Save Outcome

enum SaveOutcome: Equatable {
    case idle
    case saved
    case failed(String)
}

// MARK: - Banner View

struct SaveFeedbackBanner: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))

            Text(message)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .foregroundStyle(isError ? .white : AppTheme.Palette.accentForeground)
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity)
        .background(
            isError
                ? AnyShapeStyle(AppTheme.toneColor(.coral))
                : AnyShapeStyle(AppTheme.Palette.accent),
            in: .rect(cornerRadius: AppTheme.compactCornerRadius)
        )
        .shadow(color: AppTheme.Palette.shadow, radius: 8, y: 4)
        .padding(.horizontal, AppTheme.screenPadding)
    }
}

// MARK: - Modifier

extension View {
    func saveFeedback(
        outcome: SaveOutcome,
        successMessage: String = "Saved",
        onReset: @escaping () -> Void
    ) -> some View {
        modifier(
            SaveFeedbackModifier(
                outcome: outcome,
                successMessage: successMessage,
                onReset: onReset
            )
        )
    }
}

private struct SaveFeedbackModifier: ViewModifier {
    let outcome: SaveOutcome
    let successMessage: String
    let onReset: () -> Void

    @State private var visibleBanner: BannerState?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let banner = visibleBanner {
                    SaveFeedbackBanner(message: banner.message, isError: banner.isError)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 8)
                }
            }
            .animation(.snappy(duration: 0.3), value: visibleBanner != nil)
            .sensoryFeedback(trigger: visibleBanner) { oldBanner, newBanner in
                guard oldBanner == nil, let newBanner else { return nil }
                return newBanner.isError ? .error : .success
            }
            .onChange(of: outcome) { _, newOutcome in
                switch newOutcome {
                case .saved:
                    showBanner(message: successMessage, isError: false, duration: 1.6)
                    onReset()
                case .failed(let message):
                    showBanner(message: message, isError: true, duration: 3.0)
                    onReset()
                case .idle:
                    break
                }
            }
    }

    private func showBanner(message: String, isError: Bool, duration: TimeInterval) {
        visibleBanner = BannerState(message: message, isError: isError)

        Task {
            try? await Task.sleep(for: .seconds(duration))
            visibleBanner = nil
        }
    }
}

private struct BannerState: Equatable {
    let message: String
    let isError: Bool
}
