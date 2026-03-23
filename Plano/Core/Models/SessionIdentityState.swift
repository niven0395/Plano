enum SessionIdentityState: Hashable {
    case initializing
    case anonymous
    case identified(name: String)
    case authenticated
}
