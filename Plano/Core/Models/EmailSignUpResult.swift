enum EmailSignUpResult {
    case authenticated(AuthenticatedUserProfile)
    case pendingVerification(email: String)
}
