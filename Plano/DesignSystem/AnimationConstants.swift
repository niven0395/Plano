import SwiftUI

enum AppAnimation {
    /// Quick press/toggle feedback (buttons, chips, switches)
    static let feedback: Animation = .snappy(duration: 0.2)

    /// Content state changes (loading → loaded, filter switches)
    static let transition: Animation = .easeOut(duration: 0.3)

    /// Content appearing on screen (cards, sections revealing)
    static let reveal: Animation = .smooth(duration: 0.35)

    /// Numeric text counting transitions
    static let counting: Animation = .snappy

    /// Spring for interactive press feedback (buttons, calendar cells)
    static let press: Animation = .spring(duration: 0.25, bounce: 0.3)

    /// Delay between staggered list items (seconds)
    static let staggerInterval: Double = 0.04
}
