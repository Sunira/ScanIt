import Testing
@testable import ScanIt

struct StarterCategoriesTests {
    @Test func matchesTheAgreedStarterSet() {
        #expect(StarterCategories.all.map(\.name) ==
                ["Receipts", "Bills", "Medical", "Insurance", "Legal", "ID", "School", "Personal"])
    }

    @Test func idsAreUnique() {
        let ids = StarterCategories.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }
}
