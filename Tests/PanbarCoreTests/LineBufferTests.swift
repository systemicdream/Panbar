import Foundation
import Testing
@testable import PanbarCore

@Test func splitsLinesAcrossChunks() {
    var buffer = LineBuffer()
    #expect(buffer.append(Data("{\"a\":1}\n{\"b\"".utf8)) == ["{\"a\":1}"])
    #expect(buffer.append(Data(":2}\n\n{\"c\":3}\n".utf8)) == ["{\"b\":2}", "{\"c\":3}"])
    #expect(buffer.append(Data()) == [])
}
