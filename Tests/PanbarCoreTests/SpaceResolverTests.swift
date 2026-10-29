import Foundation
import Testing
@testable import PanbarCore

@Test func numbersDesktopsPerDisplaySkippingFullScreen() {
    let displays: [[String: Any]] = [
        ["Spaces": [
            ["ManagedSpaceID": 3, "type": 0],
            ["ManagedSpaceID": 9, "type": 4],
            ["ManagedSpaceID": 6, "type": 0],
        ]],
        ["Spaces": [
            ["ManagedSpaceID": 12, "type": 0],
        ]],
    ]
    let desktops = SpaceResolver.desktops(fromManagedDisplaySpaces: displays)
    #expect(desktops[3] == .desktop(1))
    #expect(desktops[9] == .fullScreen)
    #expect(desktops[6] == .desktop(2))
    #expect(desktops[12] == .desktop(1))
    #expect(desktops[99] == nil)
}
