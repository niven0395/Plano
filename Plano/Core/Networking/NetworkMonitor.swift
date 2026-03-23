import Foundation
import Network
import Observation
import OSLog

@MainActor
@Observable
final class NetworkMonitor {
    private(set) var isConnected = true
    private(set) var connectionType: NWInterface.InterfaceType?

    @ObservationIgnored private let monitor = NWPathMonitor()
    @ObservationIgnored private let queue = DispatchQueue(label: "plano.network-monitor", qos: .utility)
    @ObservationIgnored private var onConnectivityChange: ((Bool) -> Void)?

    func start(onConnectivityChange: ((Bool) -> Void)? = nil) {
        self.onConnectivityChange = onConnectivityChange

        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let wasConnected = isConnected
                isConnected = path.status == .satisfied

                if path.usesInterfaceType(.wifi) {
                    connectionType = .wifi
                } else if path.usesInterfaceType(.cellular) {
                    connectionType = .cellular
                } else if path.usesInterfaceType(.wiredEthernet) {
                    connectionType = .wiredEthernet
                } else {
                    connectionType = nil
                }

                if wasConnected != isConnected {
                    AppLogger.networking.notice(
                        "Network connectivity changed: \(self.isConnected ? "connected" : "disconnected", privacy: .public)"
                    )
                    self.onConnectivityChange?(isConnected)
                }
            }
        }

        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }
}
