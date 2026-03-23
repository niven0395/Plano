enum SearchPresentationState: Hashable {
    case live
    case loading
    case error(message: String)
}
