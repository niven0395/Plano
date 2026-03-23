import Foundation
import Observation

@MainActor
@Observable
final class HostIdentityPromptStore {
    private let authStore: AuthStore
    @ObservationIgnored private var pendingAction: (() -> Void)?

    var firstName = ""
    var lastName = ""
    var phone = ""
    var email = ""
    var loadingState: LoadingState = .idle
    var isPresented = false

    init(authStore: AuthStore) {
        self.authStore = authStore
    }

    var isValid: Bool {
        !firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func present(afterSubmit action: @escaping () -> Void) {
        pendingAction = action
        isPresented = true
    }

    func dismiss() {
        isPresented = false
        loadingState = .idle
    }

    func submit() async {
        guard isValid else { return }
        loadingState = .loading

        do {
            try await authStore.setHostIdentity(
                firstName: firstName,
                lastName: lastName,
                phone: phone,
                email: email
            )

            let action = pendingAction
            pendingAction = nil
            loadingState = .loaded
            isPresented = false
            action?()
        } catch {
            loadingState = .failed(error.localizedDescription)
        }
    }
}
