import SwiftUI
#if canImport(TipKit)
import TipKit

struct SearchRankingTip: Tip {
    var title: Text {
        Text("Save strong candidates")
    }

    var message: Text? {
        Text("Saved vendors get boosted in ranking, making it easier to compare your shortlist without losing momentum.")
    }

    var image: Image? {
        Image(systemName: "heart.fill")
    }
}

struct QuoteComposerTip: Tip {
    var title: Text {
        Text("Quote directly in-thread")
    }

    var message: Text? {
        Text("Use a suggested package, then tighten the deposit and expiry so hosts can approve without context switching.")
    }

    var image: Image? {
        Image(systemName: "doc.text.fill")
    }
}

struct ApplePayDepositTip: Tip {
    var title: Text {
        Text("Keep payment in the flow")
    }

    var message: Text? {
        Text("Apple Pay confirmation posts the receipt back into chat and updates the event workspace at the same time.")
    }

    var image: Image? {
        Image(systemName: "apple.logo")
    }
}
#endif
