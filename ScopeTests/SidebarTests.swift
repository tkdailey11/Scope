import Testing
@testable import Scope

struct SidebarTests {
    @Test func everyItemAppearsInExactlyOneSection() {
        let listed = SidebarSection.allCases.flatMap(\.items)
        #expect(listed.count == SidebarItem.allCases.count)
        #expect(Set(listed) == Set(SidebarItem.allCases))
    }

    @Test func configurationSectionOrderMatchesInformationArchitecture() {
        #expect(SidebarSection.configuration.items == [.overview, .environment, .path, .aliases, .functions])
        #expect(SidebarSection.scopes.items == [.profiles, .machines])
        #expect(SidebarSection.utilities.items == [.diagnostics, .backups])
    }
}
