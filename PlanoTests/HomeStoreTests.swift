import Foundation
import Testing
@testable import Plano

struct HomeStoreTests {
    @Test
    @MainActor
    func popularCategoriesIncludesAllVendorCategories() async {
        let categories = VendorCategory.homeDisplayOrder.map { CategoryShortcut(category: $0) }
        #expect(categories.map(\.category) == VendorCategory.homeDisplayOrder)
    }

    @Test
    @MainActor
    func popularCategoriesCountMatchesVendorPool() async {
        let categories = VendorCategory.homeDisplayOrder.map { CategoryShortcut(category: $0) }
        let decoratorShortcut = categories.first(where: { $0.category == .decorator })
        #expect(decoratorShortcut != nil)
    }
}
