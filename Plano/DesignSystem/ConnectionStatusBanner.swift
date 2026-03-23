import SwiftUI

struct ConnectionStatusBanner: View {
    let connectionState: RealtimeConnectionState
    let isNetworkConnected: Bool
    let hasEverConnected: Bool

    var body: some View {
        if shouldShow {
            HStack(spacing: 8) {
                if connectionState == .connecting {
                    ProgressView()
                        .controlSize(.small)
                        .tint(Color.white)
                } else {
                    Image(systemName: "wifi.slash")
                        .font(.footnote.weight(.bold))
                }

                Text(statusText)
                    .font(.footnote.weight(.semibold))
            }
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(backgroundColor)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private var shouldShow: Bool {
        if !isNetworkConnected { return true }
        if connectionState == .connecting { return true }
        // Only show "disconnected" if we were previously connected
        if connectionState == .disconnected && hasEverConnected { return true }
        return false
    }

    private var statusText: String {
        if !isNetworkConnected {
            return "No internet connection"
        }

        switch connectionState {
        case .connecting:
            return "Reconnecting..."
        case .disconnected:
            return "Connection lost. Messages may be delayed."
        case .connected:
            return ""
        }
    }

    private var backgroundColor: Color {
        if !isNetworkConnected {
            return Color.red.opacity(0.85)
        }

        switch connectionState {
        case .connecting:
            return Color.orange.opacity(0.85)
        case .disconnected:
            return Color.orange.opacity(0.85)
        case .connected:
            return Color.clear
        }
    }
}
