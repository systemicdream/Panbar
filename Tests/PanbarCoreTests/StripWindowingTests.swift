import Testing
@testable import PanbarCore

@Test func showsEverythingWhenItFits() {
    #expect(StripWindowing.range(count: 4, anchor: 2, capacity: 4) == 0..<4)
    #expect(StripWindowing.range(count: 4, anchor: 2, capacity: 10) == 0..<4)
}

@Test func centersOnAnchor() {
    #expect(StripWindowing.range(count: 10, anchor: 5, capacity: 3) == 4..<7)
    #expect(StripWindowing.range(count: 10, anchor: 5, capacity: 4) == 4..<8)
}

@Test func clampsAtStripEnds() {
    #expect(StripWindowing.range(count: 10, anchor: 0, capacity: 3) == 0..<3)
    #expect(StripWindowing.range(count: 10, anchor: 9, capacity: 3) == 7..<10)
    #expect(StripWindowing.range(count: 10, anchor: 8, capacity: 4) == 6..<10)
}

@Test func zeroCapacityIsEmpty() {
    #expect(StripWindowing.range(count: 5, anchor: 2, capacity: 0).isEmpty)
}
