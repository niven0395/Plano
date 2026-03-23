import SwiftUI

// MARK: - Environment Key

private struct HapticsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    var hapticsEnabled: Bool {
        get { self[HapticsEnabledKey.self] }
        set { self[HapticsEnabledKey.self] = newValue }
    }
}

// MARK: - Convenience Modifier

extension View {
    func hapticFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T
    ) -> some View {
        modifier(ConditionalHapticModifier(feedback: feedback, trigger: trigger, condition: { _, _ in true }))
    }

    func hapticFeedback<T: Equatable>(
        _ feedback: SensoryFeedback,
        trigger: T,
        condition: @escaping (_ oldValue: T, _ newValue: T) -> Bool
    ) -> some View {
        modifier(ConditionalHapticModifier(feedback: feedback, trigger: trigger, condition: condition))
    }
}

private struct ConditionalHapticModifier<T: Equatable>: ViewModifier {
    @Environment(\.hapticsEnabled) private var hapticsEnabled
    let feedback: SensoryFeedback
    let trigger: T
    let condition: (T, T) -> Bool

    func body(content: Content) -> some View {
        content
            .sensoryFeedback(feedback, trigger: trigger) { old, new in
                hapticsEnabled && condition(old, new)
            }
    }
}
