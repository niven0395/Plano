import SwiftUI

struct OnboardingProgressDots: View {
    let totalSteps: Int
    let currentStep: Int

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Capsule()
                    .fill(index == currentStep ? AppTheme.Palette.accent : AppTheme.Palette.border)
                    .frame(width: index == currentStep ? 28 : 10, height: 10)
            }
        }
        .animation(.snappy, value: currentStep)
    }
}
